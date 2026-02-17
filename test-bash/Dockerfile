# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

FROM bats/bats@sha256:6e4b9369468b7f3fd8f402ac6cc8ea7b2e4903eae28d08785f31a0245eb51a44 AS test-tmas-scripts

RUN apk --no-cache --update add curl jq

# Create a non-root user
RUN adduser -D -s /bin/sh testuser

# Copy to the working directory.
COPY . /src/
WORKDIR /src

# Change ownership and switch to non-root user, needed for some tests
RUN chown -R testuser:testuser /src
USER testuser

ENTRYPOINT [ "/opt/bats/bin/bats", "--print-output-on-failure" ]
CMD [ "./test-bash/" ]