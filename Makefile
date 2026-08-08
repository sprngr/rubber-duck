.PHONY: build check check-guardrails build-skills check-skills build-agents check-agents build-harness check-harness build-site check-site validation

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

build-site:
	node site/scripts/sync-docs.mjs
	node site/scripts/build-catalogue.mjs
	cd site && npm install && npm run build

check-site:
	node site/scripts/sync-docs.mjs
	@echo "TODO(site): 2026-08-06 add real drift check (--check flag) once sync stabilizes"

build: build-skills build-agents

check: check-skills check-agents
