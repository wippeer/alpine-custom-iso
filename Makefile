VERSION ?= 3.23
PROFILE ?= custom
ISO := ./output/alpine-$(PROFILE)-$(VERSION)-x86_64.iso

build-container-image:
	@docker build --build-arg ALPINE_VERSION=$(VERSION) . -t alpine-iso-build

create-iso:
	@mkdir -p output
	@docker container run -it --rm -e ALPINE_VERSION=$(VERSION) -e PROFILE=$(PROFILE) --mount type=bind,source=./output,target=/iso --name="alpineiso" alpine-iso-build

test-iso:
	@bash ./test-iso.sh "$(ISO)"
	@sha256sum -b "$(ISO)" >"$(ISO).sha256"

test-iso-uefi:
	@bash ./test-iso.sh --uefi "$(ISO)"
	@sha256sum -b "$(ISO)" >"$(ISO).sha256"

clean:
	rm -rf ./output
	rm -f qemu.log qemu.pid

.PHONY: build-container-image create-iso test-iso test-iso-uefi clean
