.PHONY: build check sync-guardrails check-guardrails build-harness check-harness

sync-guardrails:
	./scripts/sync-guardrails.sh

check-guardrails:
	./scripts/check-guardrails-drift.sh

build-harness:
	./scripts/build-harness-artifacts.sh

check-harness:
	./scripts/build-harness-artifacts.sh --check

build: sync-guardrails build-harness

check: check-guardrails check-harness
