.PHONY: adapters-build adapters-smoke adapters-check

adapters-build:
	bash scripts/build-adapters.sh

adapters-smoke:
	bash scripts/smoke/all.sh

adapters-check: adapters-build adapters-smoke
