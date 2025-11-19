VERSION ?= 3.22
PROFILENAME ?= custom
ISO := ./iso/alpine-$(PROFILENAME)-$(VERSION)-x86_64.iso

build-container-image:
	@docker build --build-arg ALPINE_VERSION=$(VERSION) . -t alpine-$(PROFILENAME)-iso

create-iso:
	@mkdir -p iso
	@docker container run -it --rm -e ALPINE_VERSION=$(VERSION) -e PROFILENAME=$(PROFILENAME) --mount type=bind,source=./iso,target=/iso --name="alpineiso" alpine-$(PROFILENAME)-iso

test-iso:
	@bash ./test-iso.sh "$(ISO)"
	@sha256sum -b "$(ISO)" >"$(ISO).sha256"

clean:
	rm -rf ./iso
	rm -f qemu.log qemu.pid

.PHONY: build-container-image create-iso test-iso clean
