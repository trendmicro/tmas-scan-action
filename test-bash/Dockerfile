# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

FROM bats/bats@sha256:0257e4f5326dd37046e94d4b8ce07c293447be80a9db6d6dfff1d50d07617e2e AS test-tmas-scripts

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