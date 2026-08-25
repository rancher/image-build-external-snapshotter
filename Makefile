SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

REPO ?= rancher
BUILD_META=-build$(shell date +%Y%m%d)
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := $(shell cat TAG)$(BUILD_META)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif




.PHONY: build-image-csi-snapshotter
build-image-csi-snapshotter: IMAGE = $(REPO)/hardened-csi-snapshotter:$(TAG)
build-image-csi-snapshotter:
	docker buildx build \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target csi-snapshotter \
		--tag $(IMAGE) \
		--load \
	.

.PHONY: build-image-snapshot-controller
build-image-snapshot-controller: IMAGE = $(REPO)/hardened-snapshot-controller:$(TAG)
build-image-snapshot-controller:
	docker buildx build \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target snapshot-controller \
		--tag $(IMAGE) \
		--load \
	.

.PHONY: build-image-all
build-image-all: build-image-csi-snapshotter build-image-snapshot-controller

# $(IID_FILE_FLAG) is provided in GHA by ecm-distro-tools/action/publish-image
.PHONY: push-image-csi-snapshotter
push-image-csi-snapshotter: IMAGE = $(REPO)/hardened-csi-snapshotter:$(TAG)
push-image-csi-snapshotter:
	docker buildx build \
		$(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target csi-snapshotter \
		--tag $(IMAGE) \
		--push \
		.
	.

.PHONY: push-image-snapshot-controller
push-image-snapshot-controller: IMAGE = $(REPO)/hardened-snapshot-controller:$(TAG)
push-image-snapshot-controller:
	docker buildx build \
		$(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--platform=$(TARGET_PLATFORMS) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--target snapshot-controller \
		--tag $(IMAGE) \
		--push \
		.
	.

.PHONY: image-scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(REPO)/hardened-snapshot-controller:$(TAG)
	trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(REPO)/hardened-csi-snapshotter:$(TAG)

.PHONY: log
log:
	@echo "TARGET_PLATFORMS=$(TARGET_PLATFORMS)"
	@echo "REPO=$(REPO)"
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"