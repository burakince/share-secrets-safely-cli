EXE=target/debug/s3
MUSL_IMAGE=clux/muslrust:stable
MY_MUSL_IMAGE=s3_muslrust:stable

help:
	$(info Available Targets)
	$(info ---------------------------------------------------------------------------------------------------------------)
	$(info journey-tests    | Run journey tests using a pre-built linux binary)
	$(info - Development -------------------------------------------------------------------------------------------------)
	$(info build-image      | Build our build image)
	$(info lint-scripts     | Run journey tests using a pre-built linux binary)
	$(info build-linux-musl | Build the binary via a docker based musl container)
	$(info interactice-linux-musl | The interactive version of the above)
	$(info ---------------------------------------------------------------------------------------------------------------)

always:

$(EXE): always
	cargo build --all-features

journey-tests: $(EXE)
	tests/stateless-journey-test.sh $(EXE)

build-image:
	docker build -t $(MY_MUSL_IMAGE) - < etc/docker/Dockerfile.musl-build

build-linux-musl:
	docker run -v $$PWD/.docker-cargo-cache:/root/.cargo -v "$$PWD:/volume" --rm -it $(MY_MUSL_IMAGE) cargo build

interactive-linux-musl:
	docker run -v $$PWD/.docker-cargo-cache:/root/.cargo -v "$$PWD:/volume" --rm -it $(MY_MUSL_IMAGE)

lint-scripts:
	find . -not -path '*target/*' -name '*.sh' -type f | while read -r sf; do shellcheck -x "$$sf"; done