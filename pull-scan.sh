#!/bin/bash

# Install cli on latest version
curl -s -L  https://gist.githubusercontent.com/raphabot/abae09b46c29afc7c3b918b7b8ec2a5c/raw/90c24ac0eb5235819bbb3ee7f575500d7debfcfb/tmas-install.sh | bash

# Sets default value for IMAGE_TARBALL
IMAGE_TARBALL="image.tar"

# Checks if a locally available image tarball was provided by verifying if LOCAL_IMAGE_TARBALL is empty
# If it is, it will pull the image from the registry
# If it isn't, it will use the local image tarball
if [ -z "$LOCAL_IMAGE_TARBALL" ]; then
  # Pulls the image
  echo "Pulling Image ""$IMAGE""..."
  crane pull "$IMAGE" "$IMAGE_TARBALL"
else
  # Uses the local image tarball
  IMAGE_TARBALL="$LOCAL_IMAGE_TARBALL"
  echo "Using local image tarball: $IMAGE_TARBALL"
fi

# Scans the image
tmas scan --endpoint "https://artifactscan.$REGION.cloudone.trendmicro.com" docker-archive:"$IMAGE_TARBALL" > "$SCAN_RESULT_ARTIFACT"

# print the result
cat "$SCAN_RESULT_ARTIFACT"

# Evaluates the result
MESSAGE=""
TOTAL_VULNERABILITIES="$(jq '.totalVulnCount' "$SCAN_RESULT_ARTIFACT")"
if [ "$TOTAL_VULNERABILITIES" -gt "$MAX_TOTAL" ]; then MESSAGE+="Your total vulnerabilities is $TOTAL_VULNERABILITIES, which is higher than $MAX_TOTAL"; fi
TOTAL_CRITICAL="$(jq '.criticalCount' "$SCAN_RESULT_ARTIFACT")"
if [ "$TOTAL_CRITICAL" -gt "$MAX_CRITICAL" ]; then MESSAGE+="Your total of Critical vulnerabilities is $TOTAL_CRITICAL, which is higher than $MAX_CRITICAL"; fi
TOTAL_HIGH="$(jq '.highCount' "$SCAN_RESULT_ARTIFACT")"
if [ "$TOTAL_HIGH" -gt "$MAX_HIGH" ]; then MESSAGE+="Your total of High vulnerabilities is $TOTAL_HIGH, which is higher than $MAX_HIGH"; fi
TOTAL_MEDIUM="$(jq '.mediumCount' "$SCAN_RESULT_ARTIFACT")"
if [ "$TOTAL_MEDIUM" -gt "$MAX_MEDIUM" ]; then MESSAGE+="Your total of Medium vulnerabilities is $TOTAL_MEDIUM, which is higher than $MAX_MEDIUM"; fi
TOTAL_LOW="$(jq '.lowCount' "$SCAN_RESULT_ARTIFACT")"
if [ "$TOTAL_LOW" -gt "$MAX_LOW" ]; then MESSAGE+="Your total of Low vulnerabilities is $TOTAL_LOW, which is higher than $MAX_LOW"; fi
TOTAL_NEGLIGIBLE="$(jq '.negligibleCount' "$SCAN_RESULT_ARTIFACT")"
if [ "$TOTAL_NEGLIGIBLE" -gt "$MAX_NEGLIGIBLE" ]; then MESSAGE+="Your total of Negligible vulnerabilities is $TOTAL_NEGLIGIBLE, which is higher than $MAX_NEGLIGIBLE"; fi
TOTAL_UNKNOWN="$(jq '.unknownCount' "$SCAN_RESULT_ARTIFACT")"
if [ "$TOTAL_UNKNOWN" -gt "$MAX_UNKNOWN" ]; then MESSAGE+="Your total of Unknown vulnerabilities is $TOTAL_UNKNOWN, which is higher than $MAX_UNKNOWN"; fi

# Issue found
if [ "$MESSAGE" != "" ]; then printf "%s" "$MESSAGE"; exit 1; fi

# No issues found
echo "Evaluation found no issues against the provided policy."
exit 0