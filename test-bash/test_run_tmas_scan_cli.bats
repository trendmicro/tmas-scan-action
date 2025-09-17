#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

# Setup and teardown functions
setup() {
	# Path to the script under test
	SCRIPT_PATH="$(pwd)/tmas-scripts/run_tmas_scan_cli.sh"

	# Create a temporary directory for test artifacts
	TEST_DIR=$(mktemp -d)

	# Ensure the script is executable
	chmod +x "$SCRIPT_PATH"

	# Change to test directory
	cd "$TEST_DIR" || return

	# Install tmas
	"/src/tmas-scripts/setup_tmas.sh" --install --install-dir . --version latest
	local current_dir
	current_dir=$(pwd)
	export PATH="$PATH:$current_dir"
}

teardown() {
	# Clean up test directory
	if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
		rm -rf "$TEST_DIR"
	fi
}

@test "script exists and is executable" {
	[ -f "$SCRIPT_PATH" ]
	[ -x "$SCRIPT_PATH" ]
}

@test "script can be executed without crashing" {
	export TMAS_ADDITIONAL_ARGS="--help"
	run timeout 5s "$SCRIPT_PATH"
	[ "$status" -eq 0 ]
	unset TMAS_ADDITIONAL_ARGS
}

@test "fails when no scanners are enabled" {
	run "$SCRIPT_PATH"
	[ "$status" -eq 1 ]
	[[ "$output" == *"at least one of the security scanners must be enabled."* ]]
}

@test "fails when artifact is not specified" {
	export TMAS_VULNERABILITY_SCAN="true"

	run "$SCRIPT_PATH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"missing artifact input to be scanned"* ]]

	unset TMAS_VULNERABILITY_SCAN
}

@test "script returns error for invalid arguments" {
	export TMAS_ADDITIONAL_ARGS="--invalid-flag"
	run "$SCRIPT_PATH"
	[ "$status" -eq 1 ]
	unset TMAS_ADDITIONAL_ARGS
}

@test "can run a full scan on a container image" {
	export TMAS_VULNERABILITY_SCAN="true"
	export TMAS_MALWARE_SCAN="true"
	export TMAS_SECRETS_SCAN="true"
	export TMAS_ARTIFACT="registry:aws.registry.trendmicro.com/etscache/library/busybox:latest"

	run "$SCRIPT_PATH"

	[ "$status" -eq 0 ]
	# Read JSON report from file
	[ -f "tmas_scan_report.json" ]
	report="$(cat tmas_scan_report.json)"
	[[ "$report" == *'"vulnerabilities":'* ]]
	[[ "$report" == *'"malware":'* ]]
	[[ "$report" == *'"secrets":'* ]]

	unset TMAS_VULNERABILITY_SCAN
	unset TMAS_MALWARE_SCAN
	unset TMAS_SECRETS_SCAN
	unset TMAS_ARTIFACT
}

@test "fails with exit status 2 when policy evaluation is blocking" {
	# The policy associated with this account specifies that secrets must be scanned.
	# Skip the secrets scan to trigger the blocking policy evaluation.
	export TMAS_VULNERABILITY_SCAN="true"
	export TMAS_ADDITIONAL_ARGS="--evaluatePolicy"
	export TMAS_ARTIFACT="registry:aws.registry.trendmicro.com/etscache/library/busybox:latest"

	run "$SCRIPT_PATH"

	[ "$status" -eq 2 ]
	# Message is printed to stderr
	[[ "$output" == *"The scanned artifact is in violation of the policy"* ]]
	# report file should still exist
	[ -f "tmas_scan_report.json" ]

	unset TMAS_VULNERABILITY_SCAN
	unset TMAS_ADDITIONAL_ARGS
	unset TMAS_ARTIFACT
}
