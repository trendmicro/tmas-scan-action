# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

test: test-setup-tmas-script test-run-tmas-scan-cli-script test-github-script

test-setup-tmas-script:
	docker build -t test-tmas-scripts -f test-bash/Dockerfile .
	docker run --rm test-tmas-scripts ./test-bash/test_setup_tmas.bats

test-run-tmas-scan-cli-script:
	docker build -t test-tmas-scripts -f test-bash/Dockerfile .
	docker run --rm -e TMAS_API_KEY test-tmas-scripts ./test-bash/test_run_tmas_scan_cli.bats

test-github-script:
	docker build -t test-github-scripts -f test-js/Dockerfile .
	docker run --rm test-github-scripts

# Run all lint checks
lint:
	docker run --rm -v "$$PWD:/mnt" aws.registry.trendmicro.com/etscache/koalaman/shellcheck:latest tmas-scripts/*.sh
	docker run --rm -v "$$PWD:/mnt" aws.registry.trendmicro.com/etscache/koalaman/shellcheck:latest test-bash/*.bats
	npx cspell --dot ".github/**/*.{yml,yaml}" "**/*.{md,sh,bats,yml,yaml,js}" "**/Makefile" "**/Dockerfile" --no-progress --show-context

lint-fix:
	@echo "Applying formatting fixes..."
	docker run --rm -v "$$(PWD):/mnt" -w /mnt mvdan/shfmt:latest -w .

.PHONY: lint lint-fix
