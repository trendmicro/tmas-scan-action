#!/bin/bash
# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

# exit the script on any error
set -euo pipefail

# Inputs (from env vars or arguments)
TMAS_VULNERABILITY_SCAN="${TMAS_VULNERABILITY_SCAN:-false}"
TMAS_MALWARE_SCAN="${TMAS_MALWARE_SCAN:-false}"
TMAS_SECRETS_SCAN="${TMAS_SECRETS_SCAN:-false}"
TMAS_ARTIFACT="${TMAS_ARTIFACT:-}"
TMAS_ADDITIONAL_ARGS="${TMAS_ADDITIONAL_ARGS:-}"
TMAS_DEFAULT_ARGS="${TMAS_DEFAULT_ARGS:-}"
TMAS_API_KEY="${TMAS_API_KEY:-}"
REPORT_FILE="${REPORT_FILE:-tmas_scan_report.json}"

# Build TMAS CLI command
TMAS_CMD="tmas scan"
TMAS_ARGS=()

# Map flags to TMAS CLI arguments
if [ "$TMAS_VULNERABILITY_SCAN" = "true" ]; then
	TMAS_ARGS+=("-V")
fi
if [ "$TMAS_MALWARE_SCAN" = "true" ]; then
	TMAS_ARGS+=("-M")
fi
if [ "$TMAS_SECRETS_SCAN" = "true" ]; then
	TMAS_ARGS+=("-S")
fi
if [ -n "$TMAS_ARTIFACT" ]; then
	TMAS_ARGS+=("$TMAS_ARTIFACT")
fi
if [ -n "$TMAS_ADDITIONAL_ARGS" ]; then
	read -ra ADDITIONAL_ARGS_ARRAY <<<"$TMAS_ADDITIONAL_ARGS"
	TMAS_ARGS+=("${ADDITIONAL_ARGS_ARRAY[@]}")
fi
if [ -n "$TMAS_DEFAULT_ARGS" ]; then
	read -ra DEFAULT_ARGS_ARRAY <<<"$TMAS_DEFAULT_ARGS"
	TMAS_ARGS+=("${DEFAULT_ARGS_ARRAY[@]}")
fi

echo "Executing: $TMAS_CMD ${TMAS_ARGS[*]}"

# disable error handling temporarily to capture output
set +e
TMAS_OUTPUT="$($TMAS_CMD "${TMAS_ARGS[@]}" 2> >(cat >&2))"
TMAS_EXIT_CODE=$?
set -e

echo "$TMAS_OUTPUT" >"$REPORT_FILE"

exit $TMAS_EXIT_CODE
