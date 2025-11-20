ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache \
    alpine-conf \
    alpine-sdk \
    dosfstools \
    grub \
    grub-efi \
    mtools \
    squashfs-tools \
    doas \
    syslinux \
    xorriso


# Create non-root builder user with doas access
RUN adduser -D builder \
    && echo 'permit nopass builder' >> /etc/doas.conf

USER builder
WORKDIR /home/builder

RUN git clone --depth=1 --filter=blob:none \
    https://gitlab.alpinelinux.org/alpine/aports.git

# Generate abuild keys
RUN abuild-keygen -i -a -n

WORKDIR /home/builder/aports/scripts
COPY --chown=builder:builder --chmod=0755 profile/ ./

CMD ["sh", "-c", "\
    sh mkimage.sh \
        --tag \"$ALPINE_VERSION\" \
        --outdir /iso \
        --arch x86_64 \
        --repository https://dl-cdn.alpinelinux.org/alpine/v\"$ALPINE_VERSION\"/main \
        --profile \"$PROFILENAME\" \
    "]
