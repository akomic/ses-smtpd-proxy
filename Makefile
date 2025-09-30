BINARY ?= ses-smtpd-proxy
DOCKER_REGISTRY ?= ak78
DOCKER_IMAGE_NAME ?= ses-smtpd-proxy
DOCKER_TAG ?= latest
DOCKER_IMAGE ?= ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}
VERSION ?= $(shell git describe --long --tags --dirty --always)

$(BINARY): main.go vault/vault.go go.sum smtpd/smtpd.go
	CGO_ENABLED=0 go build \
		-ldflags "-X main.version=$(VERSION)"  \
		-o $@ $<

go.sum: go.mod
	go mod tidy

.PHONY: docker
docker:
	docker build --build-arg VERSION=$(VERSION) -t $(DOCKER_IMAGE) .

.PHONY: docker-amd64
docker-amd64:
	docker build --platform linux/amd64 --build-arg VERSION=$(VERSION) -t $(DOCKER_IMAGE) .

.PHONY: publish
publish: docker
	docker push $(DOCKER_IMAGE)

.PHONY: clean
clean:
	rm $(BINARY) || true
