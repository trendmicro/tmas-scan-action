# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

FROM bats/bats@sha256:5322b877351fda0cc435de8c6116de7d0a2ec79d7c680132a0ef329a633bc66f AS test-tmas-scripts

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