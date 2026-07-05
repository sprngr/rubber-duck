.PHONY: build check check-guardrails build-skills check-skills build-agents check-agents build-harness check-harness

check-guardrails:
	./scripts/check-guardrails-drift.sh

build-harness:
	./scripts/build-harness-artifacts.sh

check-harness:
	./scripts/build-harness-artifacts.sh --check

build-skills:
	bash scripts/assemble-skills.sh

check-skills:
	bash scripts/assemble-skills.sh --check

build-agents: build-harness

check-agents: check-harness

build: build-skills build-agents

check: check-guardrails check-skills check-agents
