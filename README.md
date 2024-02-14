# TMAS Scan Action Template

![TM Logo](images/tm-logo.jpg)

## Scan your containers with [Vision One Container Security](https://www.trendmicro.com/en_in/business/products/hybrid-cloud/cloud-one-container-image-security.html)

This workflow template is meant to be used as a [GitHub Action](https://github.com/features/actions).

## Requirements

* Have an [Vision One Account](https://signin.v1.trendmicro.com/). [Sign up for free trial now](www.trendmicro.com/en_us/business/products/trials.html?modal=s1b-hero-vision-one-free-trial-c022c8#detection-response) if it's not already the case!
* [A Vision One API Key](https://automation.trendmicro.com/xdr/Guides/First-Steps-Toward-Using-the-APIs) with a custom role that contains the permission `Run artifact scan`.
* A Dockerfile as a build template.

## Usage

Use this Action in your `.github/workflow` directory to build, scan with Vision One Container Security and push your image to a registry. This example uses the GitHub Packages but can be easily adapted to your registry of choice.

The logic implemented in this Action template is as follows:

- Prepare the Docker Buildx environment.
- Build the image and save it as a tar ball.
- Scan the built image for vulnerabilities and malware using Vision One Container Security.
- Upload Scan Result and SBOM Artifact if available. Artifacts allow you to share data between jobs in a workflow and store data once that workflow has completed, in this case saving the scan result and the container image SBOM as an artifact allow you to have proof on what happened on past scans.
- Optionally fail the workflow if malware and/or the vulnerability threshold was reached. Failing the workflow at this stage prevents the registry to get polluted with insecure images.
- Authenticate to the deployment registry.
- Rebuild the image from cache for the desired architectures.
- Push the image to the registry.
- Rescan the image in the registry to allow proper admission control integration.

## The Workflow

### Secrets

The workflow requires a secret to be set. For that navigate to `Settings --> Security --> Secrets and variables --> Actions --> Secrets`.

Add the following secret:

- TMAS_API_KEY: `<Your TMAS API Key>`

### Template

Below, the workflow tamplate. Adapt it to your needs and save it as a `yaml`-file in the `.github/workflow` directory.

Adapt the environment variables in the `env:`-section as required.

Variable       | Purpose
-------------- | -------
`REGISTRY`     | The workflow uses the GitHub Packages by default.
`IMAGE_NAME`   | The image name is derived from the GitHub Repo name.
`TMAS_API_KEY` | The key is retrieved from the secrets.
`REGION`       | Vision One Region of choice (ap-southeast-2, eu-central-1, ap-south-1, ap-northeast-1, ap-southeast-1, us-east-1).
`THRESHOLD`    | Defines the fail condition of the action in relation to discovered vulnerabilities. A threshold of `critical` does allow any number of vulnerabilities up to the criticality `high`. 
`MALWARE_SCAN` | Enable or disable malware scanning.
`FAIL_ACTION`  | Enable or disable failing the action if the vulnerability threshold was reached and/or malware detected.

Allowed values for the `THRESHOLD` are:

- `any`: No vulnerabilities allowed.
- `critical`: Max severity of discovered vulnerabilities is `high`.
- `high`: Max severity of discovered vulnerabilities is `medium`.
- `medium`: Max severity of discovered vulnerabilities is `low`.
- `low`: Max severity of discovered vulnerabilities is `negligible`.

If the `THRESHOLD` is not set, vulnerabilities will not fail the pipeline.

The workflow will trigger on `git push --tags`.

```yml
name: ci

# A push --tags on the repo triggers the workflow
on:
  push:
    tags: [ v* ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  TMAS_API_KEY: ${{ secrets.TMAS_API_KEY }}

  REGION: us-east-1
  THRESHOLD: "critical"
  MALWARE_SCAN: true
  FAIL_ACTION: true

jobs:
  docker:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      # Prepare the Docker Buildx environment.
      - name: Checkout
        uses: actions/checkout@v4
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Extract metadata for the Docker image
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          
      # Build the image and save it as a tar ball.
      - name: Build and store
        uses: docker/build-push-action@v5
        with:
          context: .
          tags: ${{ steps.meta.outputs.tags }}
          outputs: type=docker,dest=/tmp/image.tar

      # Scan the build image for vulnerabilities and malware.
      - name: Scan
        env:
          SBOM: true # Saves SBOM to sbom.json
        run: |
          # Install tmas latest version
          curl -s -L https://gist.github.com/raphabot/abae09b46c29afc7c3b918b7b8ec2a5c/raw/ | bash

          tmas scan "$(if [ "$MALWARE_SCAN" = true ]; then echo "--malwareScan"; fi)" -r "$REGION" docker-archive:/tmp/image.tar "$(if [ "$SBOM" = true ]; then echo "--saveSBOM"; fi)" | tee result.json

          if [ "$SBOM" = true ]; then mv SBOM_* sbom.json; fi

          # Analyze result
          fail_vul=false
          fail_mal=false
          [ "${THRESHOLD}" = "any" ] && \
            [ $(jq '.vulnerability.totalVulnCount' result.json) -ne 0 ] && fail_vul=true

          [ "${THRESHOLD}" = "critical" ] && \
            [ $(jq '.vulnerability.criticalCount' result.json) -ne 0 ] && fail_vul=true

          [ "${THRESHOLD}" = "high" ] && \
            [ $(jq '.vulnerability.highCount + .vulnerability.criticalCount' result.json) -ne 0 ] && fail_vul=true

          [ "${THRESHOLD}" = "medium" ] && \
            [ $(jq '.vulnerability.mediumCount + .vulnerability.highCount + .vulnerability.criticalCount' result.json) -ne 0 ] && fail_vul=true

          [ "${THRESHOLD}" = "low" ] &&
            [ $(jq '.vulnerability.lowCount + .vulnerability.mediumCount + .vulnerability.highCount + .vulnerability.criticalCount' result.json) -ne 0 ] && fail_vul=true

          [ $(jq '.malware.scanResult' result.json) -ne 0 ] && fail_mal=true

          [ "$fail_vul" = true ] && echo !!! Vulnerability threshold exceeded !!! > vulnerabilities || true
          [ "$fail_mal" = true ] && echo !!! Malware found !!! > malware || true

      # Upload Scan Result and SBOM Artifact if available.
      - name: Upload Scan Result Artifact
        uses: actions/upload-artifact@v3
        with:
          name: scan-result
          path: result.json
          retention-days: 30

      - name: Upload SBOM Artifact
        uses: actions/upload-artifact@v3
        with:
          name: sbom
          path: sbom.json
          retention-days: 30

      # Fail the workflow if malware found or the vulnerability threshold reached.
      - name: Fail Action
        run: |
          if [ "$FAIL_ACTION" = true ]; then
            if [ -f "malware" ]; then cat malware; fi
            if [ -f "vulnerabilities" ]; then cat vulnerabilities; fi
            if [ -f "malware" ] || [ -f "vulnerabilities" ]; then exit 1; fi
          fi

      # Login to the registry.
      - name: Login to the Container registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Rebuild the image and push to registry. This is fast since everything is cached.
      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          provenance: false
          tags: ${{ steps.meta.outputs.tags }}

      - name: Summarize the Docker digest and tags
        run: |
          echo 'Digest: ${{ steps.build.outputs.digest }}'
          echo 'Tags: ${{ steps.meta.outputs.tags }}'

      # Rescan in the registry to support admission control
      - name: Registry Scan
        run: |
          tmas scan "$(if [ "$MALWARE_SCAN" = true ]; then echo "--malwareScan"; fi)" -r "$REGION" -p linux/amd64 registry:${{ steps.meta.outputs.tags }} || true
```

## Contributing

If you encounter a bug, think of a useful feature, or find something confusing in the docs, please [create a new issue](https://github.com/trendmicro/tmas-scan-action/issues/new)!

We :heart: pull requests. If you'd like to fix a bug, contribute to a feature or just correct a typo, please feel free to do so.

If you're thinking of adding a new feature, consider opening an issue first to discuss it to ensure it aligns to the direction of the project (and potentially save yourself some time!).

## Support

Official support from Trend Micro is not available. Individual contributors may be Trend Micro employees, but are not official support.
