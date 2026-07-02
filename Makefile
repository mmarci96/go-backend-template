# =========================================================================
# Configuration — override any of these on the command line:
#   make docker-build REGISTRY=myregistry.io TAG=v1.2.3
# =========================================================================

APP_NAME := go-backend-template
MODULE   := github.com/your-org/$(APP_NAME)

# Docker
REGISTRY ?= ghcr.io/your-org
IMAGE    := $(REGISTRY)/$(APP_NAME)
VERSION  ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
TAG      ?= $(VERSION)

# Test
COVERAGE_OUT       := coverage.out
COVERAGE_HTML      := coverage.html
COVERAGE_THRESHOLD ?= 80

# Build output
BUILD_DIR := bin

# =========================================================================
# Targets
# =========================================================================

.PHONY: all help \
        fmt vet tidy generate \
        test cover cover-check \
        lint security \
        sonar \
        build run \
        docker-build docker-push docker-run \
        check ci \
        clean

all: check build ## Default: run all quality gates then build the binary

## ---------------------------------------------------------------------------
## Help
## ---------------------------------------------------------------------------

help: ## Show this help message
	@printf "\nUsage: make <target>\n\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
	    {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf "\n"

## ---------------------------------------------------------------------------
## Code quality — formatting, vetting, tidying
## ---------------------------------------------------------------------------

fmt: ## Format all Go source files (gofmt + goimports)
	go fmt ./...
	@which goimports > /dev/null 2>&1 && goimports -w . || \
	    echo "goimports not found — install with: go install golang.org/x/tools/cmd/goimports@latest"

vet: ## Run go vet
	go vet ./...

tidy: ## Tidy and verify go.mod / go.sum
	go mod tidy
	go mod verify

generate: ## Run go generate (protobuf, mocks, embed, etc.)
	go generate ./...

## ---------------------------------------------------------------------------
## Testing and coverage
## ---------------------------------------------------------------------------

test: ## Run all tests with race detector; write coverage to $(COVERAGE_OUT)
	go test -v -race -count=1 \
	    -coverprofile=$(COVERAGE_OUT) \
	    -covermode=atomic \
	    ./...

cover: test ## Generate and open an HTML coverage report
	go tool cover -html=$(COVERAGE_OUT) -o $(COVERAGE_HTML)
	xdg-open $(COVERAGE_HTML) 2>/dev/null || open $(COVERAGE_HTML) 2>/dev/null || true

cover-check: test ## Fail if total coverage is below $(COVERAGE_THRESHOLD)%
	@COVERAGE=$$(go tool cover -func=$(COVERAGE_OUT) | grep '^total' | awk '{print $$3}' | tr -d '%'); \
	echo "Total coverage: $${COVERAGE}%  (threshold: $(COVERAGE_THRESHOLD)%)"; \
	awk "BEGIN { if ($${COVERAGE}+0 < $(COVERAGE_THRESHOLD)) \
	    { print \"FAIL: coverage below threshold\"; exit 1 } \
	    else { print \"PASS\" } }"

## ---------------------------------------------------------------------------
## Static analysis
## ---------------------------------------------------------------------------

lint: ## Run golangci-lint (install: https://golangci-lint.run/usage/install)
	golangci-lint run ./...

security: ## Run gosec security scanner (install: go install github.com/securego/gosec/v2/cmd/gosec@latest)
	@which gosec > /dev/null 2>&1 || (echo "gosec not found — install with: go install github.com/securego/gosec/v2/cmd/gosec@latest" && exit 1)
	gosec -fmt=sarif -out=gosec.sarif ./... 2>/dev/null; gosec ./...

## ---------------------------------------------------------------------------
## SonarQube
## ---------------------------------------------------------------------------

sonar: test ## Run SonarQube analysis (requires sonar-scanner CLI and SONAR_TOKEN env var)
	@[ -n "$(SONAR_TOKEN)" ] || (echo "ERROR: SONAR_TOKEN is not set"; exit 1)
	@which sonar-scanner > /dev/null 2>&1 || (echo "sonar-scanner not found — https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/scanners/sonarscanner/"; exit 1)
	sonar-scanner \
	    -Dsonar.projectKey=$(APP_NAME) \
	    -Dsonar.sources=. \
	    -Dsonar.go.coverage.reportPaths=$(COVERAGE_OUT) \
	    -Dsonar.token=$(SONAR_TOKEN)

## ---------------------------------------------------------------------------
## Build
## ---------------------------------------------------------------------------

build: ## Compile the server binary into $(BUILD_DIR)/
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 go build \
	    -ldflags="-s -w -X main.version=$(VERSION)" \
	    -o $(BUILD_DIR)/$(APP_NAME) \
	    ./cmd/server

run: ## Run the server locally (hot-path, no Docker)
	go run ./cmd/server

## ---------------------------------------------------------------------------
## Docker
## ---------------------------------------------------------------------------

docker-build: ## Build the Docker image (tags: $(TAG) and latest)
	docker build \
	    --build-arg VERSION=$(VERSION) \
	    -t $(IMAGE):$(TAG) \
	    -t $(IMAGE):latest \
	    .

docker-push: ## Push both tags to $(REGISTRY)
	docker push $(IMAGE):$(TAG)
	docker push $(IMAGE):latest

docker-run: ## Run the image locally on port 8080
	docker run --rm -p 8080:8080 --name $(APP_NAME) $(IMAGE):$(TAG)

## ---------------------------------------------------------------------------
## Pipeline compositions
## ---------------------------------------------------------------------------

# Pre-merge gate: everything except publishing.
# Blocks a bad commit from ever reaching the registry.
check: fmt vet tidy cover-check lint security ## All local quality gates (no publish)

# Full CI/CD pipeline: quality gates → Sonar → build image → push image.
ci: check sonar docker-build docker-push ## Complete CI/CD pipeline

## ---------------------------------------------------------------------------
## Housekeeping
## ---------------------------------------------------------------------------

clean: ## Remove generated artefacts
	rm -rf $(BUILD_DIR) $(COVERAGE_OUT) $(COVERAGE_HTML) gosec.sarif
