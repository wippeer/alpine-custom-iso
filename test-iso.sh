#!/usr/bin/env bash
set -euo pipefail

uefi_mode=false
if [[ "${1:-}" == "--uefi" ]]; then
  uefi_mode=true
  shift
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 [--uefi] <iso-file>" >&2
  exit 1
fi

iso_file="$1"

if [[ ! -f "$iso_file" ]]; then
  echo "Error: ISO file not found: $iso_file" >&2
  exit 1
fi

ovmf_vars_tmp=""
cleanup() {
  if [[ -f qemu.pid ]]; then
    pkill --pidfile qemu.pid 2>/dev/null || true
    rm -f qemu.pid
  fi
  if [[ -n "$ovmf_vars_tmp" && -f "$ovmf_vars_tmp" ]]; then
    rm -f "$ovmf_vars_tmp"
  fi
}
trap cleanup EXIT

# Initialize log file
: >qemu.log

if [[ "$uefi_mode" == true ]]; then
  # Locate OVMF firmware (common paths across distros)
  ovmf_code=""
  ovmf_vars=""
  for candidate in \
      "/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd" \
      "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
      "/usr/share/edk2/ovmf/OVMF_CODE.fd:/usr/share/edk2/ovmf/OVMF_VARS.fd" \
      "/usr/share/qemu/OVMF_CODE_4M.ms.fd:/usr/share/qemu/OVMF_VARS_4M.fd"; do
    code="${candidate%%:*}"
    vars="${candidate##*:}"
    if [[ -f "$code" && -f "$vars" ]]; then
      ovmf_code="$code"
      ovmf_vars="$vars"
      break
    fi
  done
  if [[ -z "$ovmf_code" ]]; then
    echo "Error: OVMF firmware not found. Install the 'ovmf' package." >&2
    exit 1
  fi
  ovmf_vars_tmp="$(mktemp --suffix=.fd)"
  cp "$ovmf_vars" "$ovmf_vars_tmp"

  echo "UEFI mode: using $ovmf_code"

  # Start QEMU with UEFI
  qemu-system-x86_64 \
    -m 512 \
    -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
    -drive if=pflash,format=raw,file="$ovmf_vars_tmp" \
    -cdrom "$iso_file" \
    -enable-kvm \
    -nographic \
    -display none \
    -serial file:qemu.log \
    -pidfile qemu.pid \
    </dev/null &>/dev/null &
else
  # Start QEMU (BIOS)
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
fi

echo "Waiting for Alpine to boot..."
timeout=$([[ "$uefi_mode" == true ]] && echo 120 || echo 90)
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

# Shutdown QEMU (cleanup trap handles this, but do it now so log is complete)
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

# In UEFI mode, also check boot-time test results
if [[ "$uefi_mode" == true ]]; then
  echo ""
  echo "=== Boot-time test results ==="
  grep 'RESULT:' qemu.log || true
  if grep -q 'RESULT:.*FAIL' qemu.log; then
    echo "Test KO :( - one or more boot-time checks failed" >&2
    exit 1
  fi
  if grep -q 'RESULT:.*OK' qemu.log; then
    echo "==> All boot-time tests passed!"
  fi
fi
