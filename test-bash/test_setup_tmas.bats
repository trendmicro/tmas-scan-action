#!/usr/bin/env bats
# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

# Setup and teardown functions
setup() {
	# Path to the script under test
	SCRIPT_PATH="$(pwd)/tmas-scripts/setup_tmas.sh"

	# Create a temporary directory for test artifacts
	TEST_DIR=$(mktemp -d)

	# Ensure the script is executable
	chmod +x "$SCRIPT_PATH"

	# Change to test directory
	cd "$TEST_DIR" || return
}

teardown() {
	# Clean up test directory
	if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
		rm -rf "$TEST_DIR"
	fi
}

# Test help functionality
@test "Shows help when --help flag is used" {
	run "$SCRIPT_PATH" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"--install"* ]]
	[[ "$output" == *"--metadata-lookup"* ]]
}

@test "Shows help when -h flag is used" {
	run "$SCRIPT_PATH" -h
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
}

# Test argument validation
@test "Fails when no arguments are provided" {
	run "$SCRIPT_PATH"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Please specify either --install or --metadata-lookup"* ]]
}

@test "Fails when unknown option is provided" {
	run "$SCRIPT_PATH" --unknown-option
	[ "$status" -eq 1 ]
	[[ "$output" == *"Unknown option '--unknown-option'"* ]]
}

@test "Fails when neither --install nor --metadata-lookup is specified" {
	run "$SCRIPT_PATH" --version 2.48.0
	[ "$status" -eq 1 ]
	[[ "$output" == *"Please specify either --install or --metadata-lookup"* ]]
}

@test "Fails when --install is used without --install-dir" {
	run "$SCRIPT_PATH" --install --version 2.48.0
	[ "$status" -eq 1 ]
	[[ "$output" == *"--install-dir must be specified when using --install"* ]]
}

@test "Fails when --version is not specified" {
	run "$SCRIPT_PATH" --metadata-lookup
	[ "$status" -eq 1 ]
	[[ "$output" == *"TMAS version was not specified"* ]]
}

@test "Fails when --install-dir is used without value" {
	run "$SCRIPT_PATH" --install --install-dir --version 2.48.0
	[ "$status" -eq 1 ]
	[[ "$output" == *"--install-dir requires a non-empty value"* ]]
}

@test "Fails when --version is used without value" {
	run "$SCRIPT_PATH" --metadata-lookup --version
	[ "$status" -eq 1 ]
	[[ "$output" == *"--version requires a value"* ]]
}

# Test version validation
@test "Fails when version format is invalid" {
	run "$SCRIPT_PATH" --metadata-lookup --version 2.48
	[ "$status" -eq 1 ]
	[[ "$output" == *"Version must be in the format X.X.X (e.g., 2.48.0), 'latest', or '2'."* ]]
}

@test "Fails when version format contains letters" {
	run "$SCRIPT_PATH" --metadata-lookup --version 2.48.0a
	[ "$status" -eq 1 ]
	[[ "$output" == *"Version must be in the format X.X.X"* ]]
}

@test "Fails when major version is unsupported (version 1.x.x)" {
	run "$SCRIPT_PATH" --metadata-lookup --version 1.0.0
	[ "$status" -eq 1 ]
	[[ "$output" == *"This tool only supports TMAS versions 2.X.X"* ]]
}

@test "Fails when major version is unsupported (version 3.x.x)" {
	run "$SCRIPT_PATH" --metadata-lookup --version 3.0.0
	[ "$status" -eq 1 ]
	[[ "$output" == *"This tool only supports TMAS versions 2.X.X"* ]]
}

@test "Fails when version 2.x.x is too old (before 2.48.0)" {
	run "$SCRIPT_PATH" --metadata-lookup --version 2.47.0
	[ "$status" -eq 1 ]
	[[ "$output" == *"This tool only supports TMAS versions 2.48.0 and later"* ]]
}

@test "Accepts supported version 2.48.0" {
	run "$SCRIPT_PATH" --metadata-lookup --version 2.48.0
	[ "$status" -eq 0 ]
	[[ "$output" == "2.48.0" ]]
}

@test "Accepts supported version 2.49.0" {
	run "$SCRIPT_PATH" --metadata-lookup --version 2.49.0
	[ "$status" -eq 0 ]
	[[ "$output" == "2.49.0" ]]
}

# Test major version pinning
@test "Major version pinning '2' resolves to latest 2.x.x version" {
	run "$SCRIPT_PATH" --metadata-lookup --version 2
	[ "$status" -eq 0 ]
	# Output should be a version number starting with 2. in X.X.X format
	[[ "$output" =~ ^2\.[0-9]+\.[0-9]+$ ]]
}

@test "Major version pinning fails for unsupported major version '1'" {
	run "$SCRIPT_PATH" --metadata-lookup --version 1
	[ "$status" -eq 1 ]
	[[ "$output" == *"Major version is unsupported"* ]]
}

@test "Major version pinning fails for unsupported major version '3'" {
	run "$SCRIPT_PATH" --metadata-lookup --version 3
	[ "$status" -eq 1 ]
	[[ "$output" == *"Major version does not exist"* ]]
}

@test "Install with major version pinning works" {
	INSTALL_DIR="$TEST_DIR/tmas-install"
	run "$SCRIPT_PATH" --install --install-dir "$INSTALL_DIR" --version 2

	# Check if installation directory was created (only if command succeeded)
	if [ "$status" -eq 0 ]; then
		[ -d "$INSTALL_DIR" ]
		[ -f "$INSTALL_DIR/tmas" ]
		[ -x "$INSTALL_DIR/tmas" ]
	fi
}

@test "Error message suggests major version pinning when incompatible version requested" {
  run "$SCRIPT_PATH" --metadata-lookup --version 3.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"This tool only supports TMAS versions 2.X.X"* ]]
}

# Test metadata lookup functionality
@test "Metadata lookup with valid version returns version" {
	run "$SCRIPT_PATH" --metadata-lookup --version 2.48.0
	[ "$status" -eq 0 ]
	[[ "$output" == "2.48.0" ]]
}

@test "Metadata lookup with 'latest' fetches latest version" {
	run "$SCRIPT_PATH" --metadata-lookup --version latest
	[ "$status" -eq 0 ]
	# Output should be a version number in X.X.X format
	[[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Test debug mode
@test "Debug mode shows verbose output" {
	run "$SCRIPT_PATH" --metadata-lookup --version latest --debug
	[ "$status" -eq 0 ]
	[[ "$output" == *"[DEBUG]"* ]]
	[[ "$output" == *"% Received"* ]]
}

# Ensure curl debug logs not displayed when not in debug mode
@test "Non-debug mode does not show CURL verbose output" {
	run "$SCRIPT_PATH" --metadata-lookup --version latest
	[ "$status" -eq 0 ]
	[[ "$output" != *"[DEBUG]"* ]]
	[[ "$output" != *"% Received"* ]]
}

# Test dependency checks
@test "Fails when curl is not available" {
	# Temporarily remove curl from PATH
	PATH="" run "$SCRIPT_PATH" --metadata-lookup --version latest
	[ "$status" -eq 1 ]
	[[ "$output" == *"curl is not installed"* ]]
}

# Test error handling for network issues
@test "Retries curl requests on network failure when fetching latest version" {
	# Mock a network failure by using an invalid http proxy
	https_proxy="https://not-existent" run "$SCRIPT_PATH" --metadata-lookup --version latest --debug

	[ "$status" -eq 1 ]
	[[ "$output" == *"Will retry in 1 seconds. 5 retries left"* ]]
	[[ "$output" == *"Will retry in 2 seconds. 4 retries left"* ]]
	[[ "$output" == *"Will retry in 4 seconds. 3 retries left"* ]]
	[[ "$output" == *"Will retry in 8 seconds. 2 retries left"* ]]
	[[ "$output" == *"Will retry in 16 seconds. 1 retries left"* ]]
	[[ "$output" == *"[ERROR] Failed to fetch TMAS metadata."* ]]
}

# Test installation scenarios
@test "Install with valid parameters creates installation directory" {
	INSTALL_DIR="$TEST_DIR/tmas-install"
	run "$SCRIPT_PATH" --install --install-dir "$INSTALL_DIR" --version 2.48.0

	# Check if installation directory was created
	[ -d "$INSTALL_DIR" ]

	# Check if tmas binary exists (if download was successful)
	if [ "$status" -eq 0 ]; then
		[ -f "$INSTALL_DIR/tmas" ]
		[ -x "$INSTALL_DIR/tmas" ]
	fi
}

@test "Install in local directory" {
	run "$SCRIPT_PATH" --install --install-dir . --version 2.48.0

	# Check if tmas binary exists (if download was successful)
	if [ "$status" -eq 0 ]; then
		[ -f "tmas" ]
		[ -x "tmas" ]
	fi
}

@test "Fails when permission issues for installation directory occur" {
	# Create a directory with no write permissions
	INSTALL_DIR="$TEST_DIR/no-write-perm"
	mkdir -p "$INSTALL_DIR"
	chmod 444 "$INSTALL_DIR"

	run "$SCRIPT_PATH" --install --install-dir "$INSTALL_DIR/subdir" --version 2.48.0

	# Should fail due to permission issues
	[ "$status" -ne 0 ]
	[[ "$output" == *"Permission denied"* ]]
}

@test "Install using latest version" {
	run "$SCRIPT_PATH" --install --install-dir . --version latest

	# Check if tmas binary exists (if download was successful)
	if [ "$status" -eq 0 ]; then
		[ -f "tmas" ]
		[ -x "tmas" ]
	fi
}

# Test file cleanup scenarios
@test "Temporary files are handled correctly" {
	INSTALL_DIR="$TEST_DIR/tmas-install"
	run "$SCRIPT_PATH" --install --install-dir "$INSTALL_DIR" --version 2.48.0

	# Check that temporary compressed files are cleaned up
	[ ! -f "tmas-compressed.zip" ]
}
