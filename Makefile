.PHONY: build check check-guardrails build-skills check-skills build-agents check-agents build-harness check-harness check-installer check-installer-sh check-installer-ps validation

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

check-installer: check-installer-sh check-installer-ps

check-installer-sh:
	bash tests/run-installer.sh

check-installer-ps:
	@if command -v pwsh >/dev/null 2>&1; then \
		pwsh -NoProfile -File tests/run-installer.ps1; \
	else \
		echo "skip check-installer-ps: pwsh not found"; \
	fi
