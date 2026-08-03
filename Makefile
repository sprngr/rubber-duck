.PHONY: build check check-guardrails build-skills check-skills build-agents check-agents build-harness check-harness validation

validation:
	python3 validation/run-validation-tests.py

check-guardrails:
	bash scripts/check-guardrails-drift.sh

build-harness:
	bash scripts/build-harness-artifacts.sh

check-harness: check-guardrails
	./scripts/build-harness-artifacts.sh --check

build-skills:
	bash scripts/assemble-skills.sh

check-skills:
	bash scripts/assemble-skills.sh --check

build-agents: build-harness

check-agents: check-harness

build: build-skills build-agents

check: check-skills check-agents
