#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <iso-file>" >&2
  exit 1
fi

iso_file="$1"

if [[ ! -f "$iso_file" ]]; then
  echo "Error: ISO file not found: $iso_file" >&2
  exit 1
fi

# Initialize log file
: >qemu.log

# Start QEMU
qemu-system-x86_64 \
  -m 512 \
  -boot d \
  -cdrom "$iso_file" \
  -enable-kvm \
  -nographic \
  -display none \
  -serial file:qemu.log \
  -pidfile qemu.pid \
  </dev/null &>/dev/null &

echo "Waiting for Alpine to boot..."
timeout=90
while ((timeout > 0)); do
  if grep -q 'login:' qemu.log 2>/dev/null; then
    echo "Boot completed!"
    break
  fi
  sleep 1
  ((timeout--))
done

if ((timeout == 0)); then
  echo "Timeout waiting for boot" >&2
fi

# Shutdown QEMU
if [[ -f qemu.pid ]]; then
  pkill --pidfile qemu.pid 2>/dev/null || true
  rm -f qemu.pid
fi

# Check for serial console in log
if grep -q 'ttyS0' qemu.log; then
  echo "==> Test OK, Serial enabled!"
else
  echo "Test KO :( - Serial not enabled" >&2
  exit 1
fi
