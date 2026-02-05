ARG GO_IMAGE=rancher/hardened-build-base:v1.24.13b1

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld patch
ARG TARGETPLATFORM
RUN set -x && \
    xx-apk --no-cache add musl-dev gcc lld 

# Build the two snapshot binaries
FROM base-builder AS builder
ARG PKG
ARG TAG
RUN git clone --depth=1 https://${PKG}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN go mod download
# cross-compilation setup
ARG TARGETARCH
ENV GO_LDFLAGS="-X ${PKG}/version.Version=${TAG}"
RUN xx-go --wrap && \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o "/csi-snapshotter" ./cmd/csi-snapshotter &&\
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o "/snapshot-controller" ./cmd/snapshot-controller

RUN xx-verify --static /csi-snapshotter /snapshot-controller
RUN if [ "$(xx-info arch)" = "amd64" ]; then \
        go-assert-boring.sh /csi-snapshotter /snapshot-controller; \
    fi

# Labels copied from upstream images
FROM scratch AS snapshot-controller
LABEL description="Snapshot Controller"
COPY --from=builder /snapshot-controller /snapshot-controller
ENTRYPOINT ["/snapshot-controller"]

FROM scratch AS csi-snapshotter
LABEL description="CSI External Snapshotter Sidecar"
COPY --from=builder /csi-snapshotter /csi-snapshotter
ENTRYPOINT ["/csi-snapshotter"]
