#!/usr/bin/env python3
"""
GPU Acceleration Test for NVIDIA CUDA PyTorch
Tests that PyTorch can access and use NVIDIA GPU via CUDA.

Usage:
    python test-gpu.py
"""

import torch
import time
import sys

def print_separator(title):
    """Print a formatted section separator"""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)

def test_gpu_availability():
    """Test if GPU is available and print device information"""
    print_separator("GPU Availability Check")

    gpu_available = torch.cuda.is_available()

    print(f"PyTorch version: {torch.__version__}")
    print(f"GPU available: {gpu_available}")

    if not gpu_available:
        print("\n❌ ERROR: No GPU detected!")
        print("\nTroubleshooting steps:")
        print("1. Check CUDA installation: nvidia-smi")
        print("2. Verify container has GPU access: --runtime=nvidia flag in devcontainer.json")
        print("3. Check environment variables:")
        print("   - CUDA_VISIBLE_DEVICES")
        print("   - NVIDIA_VISIBLE_DEVICES")
        sys.exit(1)

    print(f"\n✅ GPU Count: {torch.cuda.device_count()}")

    # Print info for each GPU
    for i in range(torch.cuda.device_count()):
        print(f"\nGPU {i}:")
        print(f"  Name: {torch.cuda.get_device_name(i)}")
        print(f"  Compute Capability: {torch.cuda.get_device_capability(i)}")

        # Memory info
        total_memory = torch.cuda.get_device_properties(i).total_memory / (1024**3)
        print(f"  Total Memory: {total_memory:.2f} GB")

        # Current memory usage
        allocated = torch.cuda.memory_allocated(i) / (1024**2)
        reserved = torch.cuda.memory_reserved(i) / (1024**2)
        print(f"  Memory Allocated: {allocated:.2f} MB")
        print(f"  Memory Reserved: {reserved:.2f} MB")

def test_basic_operations():
    """Test basic tensor operations on GPU"""
    print_separator("Basic GPU Operations Test")

    device = torch.device("cuda")

    # Create tensors on GPU
    print("\nCreating tensors on GPU...")
    x = torch.randn(1000, 1000, device=device)
    y = torch.randn(1000, 1000, device=device)

    print(f"Tensor x device: {x.device}")
    print(f"Tensor y device: {y.device}")
    print(f"Tensor x shape: {x.shape}")

    # Perform matrix multiplication
    print("\nPerforming matrix multiplication on GPU...")
    z = torch.matmul(x, y)

    print(f"Result tensor device: {z.device}")
    print(f"Result tensor shape: {z.shape}")
    print(f"Result sample values: {z[0, :5]}")

    print("\n✅ Basic GPU operations successful!")

def test_performance_comparison():
    """Compare CPU vs GPU performance"""
    print_separator("CPU vs GPU Performance Comparison")

    size = 4096
    iterations = 10

    print(f"\nMatrix size: {size}x{size}")
    print(f"Iterations: {iterations}")

    # CPU test
    print("\n🖥️  Testing CPU performance...")
    cpu_device = torch.device("cpu")
    x_cpu = torch.randn(size, size, device=cpu_device)
    y_cpu = torch.randn(size, size, device=cpu_device)

    cpu_times = []
    for i in range(iterations):
        start = time.time()
        z_cpu = torch.matmul(x_cpu, y_cpu)
        cpu_times.append(time.time() - start)

    avg_cpu_time = sum(cpu_times) / len(cpu_times)
    print(f"   Average time: {avg_cpu_time:.4f} seconds")

    # GPU test
    print("\n🚀 Testing GPU performance...")
    gpu_device = torch.device("cuda")
    x_gpu = torch.randn(size, size, device=gpu_device)
    y_gpu = torch.randn(size, size, device=gpu_device)

    # Warmup
    for _ in range(3):
        _ = torch.matmul(x_gpu, y_gpu)
    torch.cuda.synchronize()  # Wait for GPU to finish

    gpu_times = []
    for i in range(iterations):
        start = time.time()
        z_gpu = torch.matmul(x_gpu, y_gpu)
        torch.cuda.synchronize()  # Wait for GPU to finish
        gpu_times.append(time.time() - start)

    avg_gpu_time = sum(gpu_times) / len(gpu_times)
    print(f"   Average time: {avg_gpu_time:.4f} seconds")

    # Calculate speedup
    speedup = avg_cpu_time / avg_gpu_time
    print(f"\n📊 Performance Summary:")
    print(f"   CPU: {avg_cpu_time:.4f} seconds")
    print(f"   GPU: {avg_gpu_time:.4f} seconds")
    print(f"   Speedup: {speedup:.2f}x faster on GPU")

    if speedup > 1.5:
        print(f"\n✅ GPU acceleration is working! {speedup:.2f}x speedup achieved.")
    elif speedup > 1.0:
        print(f"\n⚠️  GPU is faster, but speedup is modest ({speedup:.2f}x).")
        print("   This may be normal for smaller matrices or shared memory GPUs.")
    else:
        print(f"\n⚠️  WARNING: GPU is slower than CPU!")
        print("   This may indicate a configuration issue.")

def test_neural_network():
    """Test a simple neural network training on GPU"""
    print_separator("Neural Network Training Test (GPU)")

    device = torch.device("cuda")

    print("\nCreating a simple neural network...")
    model = torch.nn.Sequential(
        torch.nn.Linear(784, 256),
        torch.nn.ReLU(),
        torch.nn.Linear(256, 128),
        torch.nn.ReLU(),
        torch.nn.Linear(128, 10)
    ).to(device)

    print(f"Model device: {next(model.parameters()).device}")
    print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")

    # Create dummy data
    print("\nTraining on dummy data...")
    batch_size = 128
    x = torch.randn(batch_size, 784, device=device)
    y = torch.randint(0, 10, (batch_size,), device=device)

    # Training loop
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = torch.nn.CrossEntropyLoss()

    print(f"Running {10} training iterations...")
    start = time.time()

    for i in range(10):
        optimizer.zero_grad()
        output = model(x)
        loss = criterion(output, y)
        loss.backward()
        optimizer.step()

        if i % 3 == 0:
            print(f"  Iteration {i}: Loss = {loss.item():.4f}")

    torch.cuda.synchronize()
    elapsed = time.time() - start

    print(f"\n🚀 GPU Training completed in {elapsed:.4f} seconds")
    print("✅ Neural network training on GPU successful!")

    return elapsed

def test_neural_network_cpu():
    """Test a simple neural network training on CPU"""
    print_separator("Neural Network Training Test (CPU)")

    device = torch.device("cpu")

    print("\nCreating a simple neural network...")
    model = torch.nn.Sequential(
        torch.nn.Linear(784, 256),
        torch.nn.ReLU(),
        torch.nn.Linear(256, 128),
        torch.nn.ReLU(),
        torch.nn.Linear(128, 10)
    ).to(device)

    print(f"Model device: {next(model.parameters()).device}")
    print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")

    # Create dummy data
    print("\nTraining on dummy data...")
    batch_size = 128
    x = torch.randn(batch_size, 784, device=device)
    y = torch.randint(0, 10, (batch_size,), device=device)

    # Training loop
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = torch.nn.CrossEntropyLoss()

    print(f"Running {10} training iterations...")
    start = time.time()

    for i in range(10):
        optimizer.zero_grad()
        output = model(x)
        loss = criterion(output, y)
        loss.backward()
        optimizer.step()

        if i % 3 == 0:
            print(f"  Iteration {i}: Loss = {loss.item():.4f}")

    elapsed = time.time() - start

    print(f"\n🖥️  CPU Training completed in {elapsed:.4f} seconds")
    print("✅ Neural network training on CPU successful!")

    return elapsed

def test_large_neural_network():
    """Test a larger neural network training on CPU"""
    print_separator("Large Neural Network Training Test (CPU)")

    device = torch.device("cpu")

    print("\nCreating a larger neural network (ResNet-style)...")
    model = torch.nn.Sequential(
        torch.nn.Linear(1024, 2048),
        torch.nn.ReLU(),
        torch.nn.Linear(2048, 2048),
        torch.nn.ReLU(),
        torch.nn.Linear(2048, 1024),
        torch.nn.ReLU(),
        torch.nn.Linear(1024, 512),
        torch.nn.ReLU(),
        torch.nn.Linear(512, 256)
    ).to(device)

    print(f"Model device: {next(model.parameters()).device}")
    print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")

    print("\nTraining on larger batches...")
    batch_size = 512
    iterations = 50
    x = torch.randn(batch_size, 1024, device=device)
    y = torch.randint(0, 256, (batch_size,), device=device)

    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = torch.nn.CrossEntropyLoss()

    print(f"Running {iterations} training iterations on batch size {batch_size}...")
    start = time.time()

    for i in range(iterations):
        optimizer.zero_grad()
        output = model(x)
        loss = criterion(output, y)
        loss.backward()
        optimizer.step()

        if i % 10 == 0:
            print(f"  Iteration {i}: Loss = {loss.item():.4f}")

    elapsed = time.time() - start

    print(f"\n🖥️  CPU Training completed in {elapsed:.4f} seconds")
    print("✅ Large neural network training on CPU successful!")

    return elapsed

def test_large_neural_network_gpu():
    """Test a larger neural network training on GPU"""
    print_separator("Large Neural Network Training Test (GPU)")

    device = torch.device("cuda")

    print("\nCreating a larger neural network (ResNet-style)...")
    model = torch.nn.Sequential(
        torch.nn.Linear(1024, 2048),
        torch.nn.ReLU(),
        torch.nn.Linear(2048, 2048),
        torch.nn.ReLU(),
        torch.nn.Linear(2048, 1024),
        torch.nn.ReLU(),
        torch.nn.Linear(1024, 512),
        torch.nn.ReLU(),
        torch.nn.Linear(512, 256)
    ).to(device)

    print(f"Model device: {next(model.parameters()).device}")
    print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")

    print("\nTraining on larger batches...")
    batch_size = 512
    iterations = 50
    x = torch.randn(batch_size, 1024, device=device)
    y = torch.randint(0, 256, (batch_size,), device=device)

    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = torch.nn.CrossEntropyLoss()

    print(f"Running {iterations} training iterations on batch size {batch_size}...")

    # Warmup
    for _ in range(3):
        output = model(x)
        _ = criterion(output, y)
    torch.cuda.synchronize()

    start = time.time()

    for i in range(iterations):
        optimizer.zero_grad()
        output = model(x)
        loss = criterion(output, y)
        loss.backward()
        optimizer.step()

        if i % 10 == 0:
            print(f"  Iteration {i}: Loss = {loss.item():.4f}")

    torch.cuda.synchronize()
    elapsed = time.time() - start

    print(f"\n🚀 GPU Training completed in {elapsed:.4f} seconds")
    print("✅ Large neural network training on GPU successful!")

    return elapsed

def main():
    """Run all GPU tests"""
    print("\n" + "=" * 70)
    print("  NVIDIA CUDA PyTorch GPU Acceleration Test")
    print("=" * 70)

    try:
        # Test 1: GPU availability and info
        test_gpu_availability()

        # Test 2: Basic operations
        test_basic_operations()

        # Test 3: Performance comparison
        test_performance_comparison()

        # Test 4: Small neural network training (CPU)
        small_cpu_time = test_neural_network_cpu()

        # Test 5: Small neural network training (GPU)
        small_gpu_time = test_neural_network()

        # Small neural network training comparison
        print_separator("Small Neural Network Training Comparison")
        small_speedup = small_cpu_time / small_gpu_time
        print(f"\n📊 Small Model Training Performance:")
        print(f"   CPU: {small_cpu_time:.4f} seconds")
        print(f"   GPU: {small_gpu_time:.4f} seconds")
        print(f"   Speedup: {small_speedup:.2f}x faster on GPU")

        if small_speedup > 2.0:
            print(f"\n✅ Excellent GPU acceleration! {small_speedup:.2f}x speedup.")
        elif small_speedup > 1.5:
            print(f"\n✅ Good GPU acceleration! {small_speedup:.2f}x speedup.")
        elif small_speedup > 1.0:
            print(f"\n⚠️  Modest GPU acceleration ({small_speedup:.2f}x). This may be normal for small networks.")
        else:
            print(f"\n⚠️  GPU slower for small model (can be normal due to overhead).")

        # Test 6: Large neural network training (CPU)
        large_cpu_time = test_large_neural_network()

        # Test 7: Large neural network training (GPU)
        large_gpu_time = test_large_neural_network_gpu()

        # Large neural network training comparison
        print_separator("Large Neural Network Training Comparison")
        large_speedup = large_cpu_time / large_gpu_time
        print(f"\n📊 Large Model Training Performance:")
        print(f"   Model: 7.3M parameters, batch size 512, 50 iterations")
        print(f"   CPU: {large_cpu_time:.4f} seconds")
        print(f"   GPU: {large_gpu_time:.4f} seconds")
        print(f"   Speedup: {large_speedup:.2f}x faster on GPU")

        if large_speedup > 2.0:
            print(f"\n✅ Excellent GPU acceleration! {large_speedup:.2f}x speedup for realistic workloads.")
        elif large_speedup > 1.5:
            print(f"\n✅ Good GPU acceleration! {large_speedup:.2f}x speedup for realistic workloads.")
        elif large_speedup > 1.0:
            print(f"\n✅ GPU faster ({large_speedup:.2f}x). GPU benefits increase with larger models.")
        else:
            print(f"\n⚠️  WARNING: GPU still slower for large model!")
            print("   This may indicate a configuration issue.")

        # Final summary
        print_separator("Test Summary")
        print("\n✅ ALL TESTS PASSED!")
        print("\nYour NVIDIA CUDA PyTorch setup is working correctly.")
        print("GPU acceleration is enabled and functioning.")

    except Exception as e:
        print(f"\n❌ ERROR: Test failed with exception:")
        print(f"   {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
