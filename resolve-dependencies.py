#!/usr/bin/env python3
"""
Dependency resolution script to avoid conflicts with NVIDIA-provided packages.
Usage: 
    python .devcontainer/filter-dependencies.py requirements.txt
    python .devcontainer/filter-dependencies.py pyproject.toml
"""
import sys
import re
import tomllib
import argparse
from pathlib import Path


def load_nvidia_packages(nvidia_file="nvidia-provided.txt"):
    """Load NVIDIA-provided packages and versions."""
    nvidia_file = Path(nvidia_file)
    if not nvidia_file.exists():
        print(f"Warning: {nvidia_file} not found")
        return {}

    nvidia_packages = {}
    with open(nvidia_file) as f:
        for line in f:
            line = line.strip()
            if '==' in line:
                name, version = line.split('==', 1)
                nvidia_packages[name.lower()] = version
    return nvidia_packages


def extract_package_name(requirement):
    """Extract package name from requirement string."""
    match = re.match(r'^([a-zA-Z0-9_-]+)', requirement)
    return match.group(1).lower() if match else None


def filter_requirements(requirements_file, nvidia_packages):
    """Filter requirements.txt to avoid NVIDIA package conflicts."""
    requirements_file = Path(requirements_file)
    if not requirements_file.exists():
        print(f"{requirements_file} not found")
        return

    with open(requirements_file) as f:
        lines = f.readlines()

    filtered_lines = []
    skipped_packages = []

    for line in lines:
        original_line = line.rstrip()
        line = line.strip()
        if not line or line.startswith('#'):
            filtered_lines.append(original_line)
            continue

        package_name = extract_package_name(line)
        if package_name and package_name in nvidia_packages:
            skipped_packages.append(f"{line} (NVIDIA provides {package_name}=={nvidia_packages[package_name]})")
            filtered_lines.append(
                f"# {original_line}  # Skipped: NVIDIA provides {package_name}=={nvidia_packages[package_name]}")
            continue

        filtered_lines.append(original_line)

    # Create filtered version
    filtered_file = requirements_file.with_name('requirements-filtered.txt')

    # Backup original if this is the first time
    backup_file = requirements_file.with_name('requirements-original.txt')
    if not backup_file.exists():
        requirements_file.rename(backup_file)
        print(f"Created backup: {backup_file}")

    with open(filtered_file, 'w') as f:
        f.write('\n'.join(filtered_lines))

    print(f"Created filtered requirements: {filtered_file}")
    if skipped_packages:
        print("Skipped packages (already provided by NVIDIA):")
        for pkg in skipped_packages:
            print(f"  - {pkg}")


def filter_pyproject_toml(pyproject_file, nvidia_packages):
    """Filter pyproject.toml dependencies to avoid NVIDIA package conflicts."""
    pyproject_file = Path(pyproject_file)
    if not pyproject_file.exists():
        print(f"{pyproject_file} not found")
        return

    with open(pyproject_file, 'rb') as f:
        data = tomllib.load(f)

    skipped_packages = []

    # Filter project dependencies
    if 'project' in data and 'dependencies' in data['project']:
        filtered_deps = []
        for dep in data['project']['dependencies']:
            package_name = extract_package_name(dep)
            if package_name and package_name in nvidia_packages:
                skipped_packages.append(f"{dep} (NVIDIA provides {package_name}=={nvidia_packages[package_name]})")
                continue
            filtered_deps.append(dep)
        data['project']['dependencies'] = filtered_deps

    # Filter optional dependencies
    if 'project' in data and 'optional-dependencies' in data['project']:
        for group_name, deps in data['project']['optional-dependencies'].items():
            filtered_deps = []
            for dep in deps:
                package_name = extract_package_name(dep)
                if package_name and package_name in nvidia_packages:
                    skipped_packages.append(
                        f"{dep} (NVIDIA provides {package_name}=={nvidia_packages[package_name]}) [from {group_name}]")
                    continue
                filtered_deps.append(dep)
            data['project']['optional-dependencies'][group_name] = filtered_deps

    # Create backup if first time
    backup_file = pyproject_file.with_name('pyproject-original.toml')
    if not backup_file.exists():
        pyproject_file.rename(backup_file)
        print(f"Created backup: {backup_file}")

    # Write filtered version - simplified TOML writing
    with open(pyproject_file, 'w') as f:
        if 'project' in data:
            f.write('[project]\n')
            for key, value in data['project'].items():
                if key == 'dependencies':
                    f.write('dependencies = [\n')
                    for dep in value:
                        f.write(f'    "{dep}",\n')
                    f.write(']\n')
                elif key == 'optional-dependencies':
                    f.write('\n[project.optional-dependencies]\n')
                    for group_name, deps in value.items():
                        f.write(f'{group_name} = [\n')
                        for dep in deps:
                            f.write(f'    "{dep}",\n')
                        f.write(']\n')
                elif isinstance(value, str):
                    f.write(f'{key} = "{value}"\n')
                else:
                    f.write(f'{key} = {value}\n')

        # Write other sections if they exist
        for section, content in data.items():
            if section != 'project':
                f.write(f'\n[{section}]\n')
                # Simple handling for other sections
                f.write(f'# Section {section} preserved but not filtered\n')

    print(f"Updated {pyproject_file} (filtered)")
    if skipped_packages:
        print("Skipped packages (already provided by NVIDIA):")
        for pkg in skipped_packages:
            print(f"  - {pkg}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Filter dependencies to avoid conflicts with NVIDIA-provided packages"
    )
    parser.add_argument(
        "file",
        help="Path to requirements.txt or pyproject.toml file to filter"
    )
    parser.add_argument(
        "--nvidia-file",
        default="nvidia-provided.txt",
        help="Path to nvidia-provided.txt file (default: nvidia-provided.txt)"
    )

    args = parser.parse_args()

    input_file = Path(args.file)
    nvidia_packages = load_nvidia_packages(args.nvidia_file)

    if input_file.suffix == '.toml':
        filter_pyproject_toml(input_file, nvidia_packages)
    elif input_file.suffix == '.txt':
        filter_requirements(input_file, nvidia_packages)
    else:
        print(f"Unsupported file type: {input_file.suffix}")
        print("Supported: .txt (requirements.txt) or .toml (pyproject.toml)")
        sys.exit(1)
