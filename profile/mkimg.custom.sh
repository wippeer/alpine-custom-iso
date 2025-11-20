profile_custom() {
	profile_standard
	kernel_cmdline="$kernel_cmdline console=ttyS0,115200"
	syslinux_serial="0 115200"
	local _k _a
	for _k in $kernel_flavors; do
		apks="$apks linux-$_k"
		for _a in $kernel_addons; do
			apks="$apks $_a-$_k"
		done
	done
	apks="$apks linux-firmware"
	hostname="alpine"
	apkovl="genapkovl-custom.sh"
}

# Override grub_gen_config to add serial console support for EFI boot
grub_gen_config() {
	local _f _p _initrd
	echo "serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1"
	echo "terminal_input serial console"
	echo "terminal_output serial console"
	echo "set timeout=1"
	for _f in $kernel_flavors; do
		if [ -z "${xen_params+set}" ]; then
			_initrd="/boot/initramfs-$_f"
			for _p in $initrd_ucode; do
				_initrd="$_p $_initrd"
			done

			cat <<- EOF

			menuentry "Linux $_f" {
				linux	/boot/vmlinuz-$_f $initfs_cmdline $kernel_cmdline
				initrd	$_initrd
			}
			EOF
		else
			cat <<- EOF

			menuentry "Xen/Linux $_f" {
				multiboot2	/boot/xen.gz ${xen_params}
				module2		/boot/vmlinuz-$_f $initfs_cmdline $kernel_cmdline
				module2		/boot/initramfs-$_f
			}
			EOF
		fi
	done
}
