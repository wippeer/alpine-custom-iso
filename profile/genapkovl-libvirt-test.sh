#!/bin/sh -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname"
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
echo "$HOSTNAME" > "$tmp"/etc/hostname

mkdir -p "$tmp"/etc/network
cat > "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    post-up ip link set dev eth0 alias "provisioning"

auto eth1
iface eth1 inet dhcp
    post-up ip link set dev eth1 alias "management"
EOF

mkdir -p "$tmp"/etc/local.d
cat > "$tmp"/etc/local.d/libvirt-test.start <<'TESTSCRIPT'
#!/bin/sh

echo "=== libvirt-test: UEFI check ==="
if [ -d /sys/firmware/efi ]; then
	echo "RESULT: UEFI boot OK - /sys/firmware/efi present"
else
	echo "RESULT: UEFI boot FAIL - /sys/firmware/efi not present (BIOS boot?)"
fi

echo "=== libvirt-test: trustGuestRxFilters check ==="
if ! ip link show eth0 > /dev/null 2>&1; then
	echo "RESULT: MAC change FAIL - eth0 not found"
	echo "RESULT: macvlan FAIL - eth0 not found"
	exit 0
fi

ORIG_MAC=$(cat /sys/class/net/eth0/address)
TEST_MAC="52:54:00:99:99:01"

ip link set eth0 down
ip link set eth0 address "$TEST_MAC"
ip link set eth0 up

NEW_MAC=$(cat /sys/class/net/eth0/address)
if [ "$NEW_MAC" = "$TEST_MAC" ]; then
	echo "RESULT: MAC change OK - changed from $ORIG_MAC to $NEW_MAC"
else
	echo "RESULT: MAC change FAIL - expected $TEST_MAC got $NEW_MAC"
fi

# Restore original MAC
ip link set eth0 down
ip link set eth0 address "$ORIG_MAC"
ip link set eth0 up

echo "=== libvirt-test: macvlan check ==="
ip link add link eth0 name eth0.macvlan type macvlan mode private
if ip link show eth0.macvlan > /dev/null 2>&1; then
	echo "RESULT: macvlan OK"
	ip link del eth0.macvlan
else
	echo "RESULT: macvlan FAIL - could not create macvlan on eth0"
fi
TESTSCRIPT
chmod 755 "$tmp"/etc/local.d/libvirt-test.start

# sysinit
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

# boot
rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add networking boot

# default
rc_add local default

# shutdown
rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > "$HOSTNAME".apkovl.tar.gz
