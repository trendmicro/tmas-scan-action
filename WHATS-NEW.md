# Trend Micro Artifact Scanner (TMAS) GitHub Action Release Notes

## [v3.0.0] - 2025-09-17

This release ...

### Added
- The `tmas-scan-action` now automatically posts a comment on an opened GitHub pull request with the TMAS scan results.
- You can now specify a major version number (e.g., `version: '2'`) to automatically get the latest version within that major version. This is the recommended practice to prevent automatic updates to major versions incompatible with your pinned version of this Github action.
- The `tmas-scan-action` action has new inputs:
  - `path`: Path in runner to install TMAS. TMAS will be installed in `<path>/tmas-bin` directory (`$GITHUB_WORKSPACE/.local/bin/tmas-bin` by default), and added to $GITHUB_PATH.
  - `cache`: Specify whether to cache the downloaded TMAS binary. Default is `true`.
  - `skipInstall`: Skip all steps related to installing, caching, and adding the TMAS CLI to the runner's path. This is useful if you are invoking TMAS multiple times in the same workflow, or want to use a pre-installed TMAS CLI or manage installation outside of the action.
  - `githubToken`: Provide a permission token to the action which allows it to access the Github API on the repo and post a summary of results to relevant PRs.
- The `tmas-scan-action` action now requires some tools to be installed on the runner:
  - `curl`
  - `jq`

### Changed

- What previously required two separate actions to setup then run TMAS(`tmas-github-action/download-tmas` + `tmas-github-action`) now requires only one action, which downloads and caches TMAS, and then invokes the TMAS binary.
- The action will now post a comment with the summary of the scan results on PRs relevant to the actions pipeline branch. The summary provides a quick view of the critical information, full detailed scan results will still be provided in the action logs.

### Removed

- The `tmas-scan-action` no longer accepts the inputs `severityCutoff` or `fail-build` or `pathToCLI`. The `tmas-scan-action` expects the TMAS CLI binary to be installed in the runner's path. The `tmas-scan-action` will no longer assess the severity of the vulnerabilities found in the scan. The action will always pass the build if the scan is successful, and fail the build if the scan fails (note that Vision One Code Security, starting in TMAS v3.0.0+ will be assessing the scan results and will fail the build if the scan results are found to be in violation of the policy, this policy-check feature will live within the TMAS CLI binary, as opposed to the `tmas-scan-action`).
- The `tmas-github-action/download-tmas` was removed, as its functionality is now embedded in the `tmas-scan-action` action.
