#syntax=docker/dockerfile:1.6.0

FROM --platform=${BUILDPLATFORM} golang:1.20.6@sha256:cfc9d1b07b1ef4f7a4571f0b60a99646a92ef76adb7d9943f4cb7b606c6554e2 AS base
WORKDIR /src
ENV CGO_ENABLED=0
COPY go.* .
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

FROM base AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /go/src/github.com/nicholasdille/clusterctlctl
ARG version=main
ENV CGO_ENABLED=0
RUN --mount=target=. \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build <<EOF
mkdir -p /out
GOOS=${TARGETOS} \
GOARCH=${TARGETARCH} \
    go build \
        -buildvcs=false \
        -ldflags "-w -s -X main.version=${version}" \
        -o /out/clusterctlctl \
        ./cmd/clusterctlctl
EOF

FROM base AS publish
WORKDIR /go/src/github.com/nicholasdille/clusterctlctl
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build <<EOF
go install github.com/goreleaser/goreleaser@latest
EOF
COPY . .
ARG GITHUB_TOKEN
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build <<EOF
goreleaser --skip-sbom
EOF

FROM base AS unit-test
RUN --mount=target=. \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build <<EOF
mkdir -p /out
go test \
    -v \
    -coverprofile=/out/cover.out \
    ./...
EOF

FROM golangci/golangci-lint:v1.53.3 AS lint-base

FROM base AS lint
RUN --mount=target=. \
    --mount=from=lint-base,src=/usr/bin/golangci-lint,target=/usr/bin/golangci-lint \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/root/.cache/golangci-lint <<EOF
golangci-lint run --timeout 10m0s ./...
EOF

FROM scratch AS unit-test-coverage
COPY --from=unit-test /out/cover.out /cover.out

FROM scratch AS bin-unix
COPY --from=build /out/clusterctlctl /

FROM bin-unix AS bin-linux
FROM bin-unix AS bin-darwin

FROM scratch AS bin-windows
COPY --from=build /out/clusterctlctl /clusterctlctl.exe

FROM bin-${TARGETOS} as bin