FROM nvcr.io/nvidia/pytorch:25.10-py3

# Workaround for Ubuntu 24.04 having pre-existing ubuntu user at UID 1000
# This prevents common-utils from falling back to UID 1001
# Reference: https://github.com/devcontainers/features/issues/1265
RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu
