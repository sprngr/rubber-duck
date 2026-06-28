.PHONY: adapters-build adapters-smoke adapters-check governance-guard full-check install-harness

adapters-build:
	bash scripts/build-adapters.sh

adapters-smoke:
	bash scripts/smoke/all.sh

adapters-check: adapters-build adapters-smoke

governance-guard:
	bash scripts/governance-guard.sh

full-check: adapters-check governance-guard

install-harness:
	bash scripts/install-harness.sh
