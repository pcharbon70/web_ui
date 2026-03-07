.PHONY: conformance conformance-report conformance-ci

conformance:
	./scripts/run_conformance.sh

conformance-report:
	./scripts/run_conformance.sh --report-only

conformance-ci:
	./scripts/run_conformance.sh
