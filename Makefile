.PHONY: build check check-guardrails build-skills check-skills build-agents check-agents build-harness check-harness build-pi check-pi

check-guardrails:
	./scripts/check-guardrails-drift.sh

build-harness:
	./scripts/build-harness-artifacts.sh

build-pi:
	bash scripts/build-pi-artifacts.sh

check-harness:
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

check: check-guardrails check-skills check-agents
