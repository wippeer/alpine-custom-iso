#!/bin/sh

VERSION=${ALPINE_VERSION}
PROFILENAME=${PROFILENAME}

cat <<EOF >mkimg.${PROFILENAME}.sh
profile_${PROFILENAME}() {
        profile_standard
        kernel_cmdline="\$kernel_cmdline console=ttyS0,115200"
        syslinux_serial="0 115200"
        local _k _a
        for _k in \$kernel_flavors; do
                apks="\$apks linux-\$_k"
                for _a in \$kernel_addons; do
                        apks="\$apks \$_a-\$_k"
                done
        done
        apks="\$apks linux-firmware"
}
EOF

sh mkimage.sh --tag "$VERSION" \
  --outdir /iso \
  --arch x86_64 \
  --repository https://dl-cdn.alpinelinux.org/alpine/v"$VERSION"/main \
  --profile "$PROFILENAME"
