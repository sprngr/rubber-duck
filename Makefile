.PHONY: build check check-guardrails build-skills check-skills build-agents check-agents build-harness check-harness build-pi check-pi

check-guardrails:
	bash scripts/check-guardrails-drift.sh

build-harness:
	bash scripts/build-harness-artifacts.sh

build-pi:
	bash scripts/build-pi-artifacts.sh

check-harness: check-guardrails
	./scripts/build-harness-artifacts.sh --check

check-pi:
	bash scripts/build-pi-artifacts.sh --check

build-skills:
	bash scripts/assemble-skills.sh

check-skills:
	bash scripts/assemble-skills.sh --check

build-agents: build-harness build-pi

check-agents: check-harness check-pi

build: build-skills build-agents

check: check-skills check-agents
