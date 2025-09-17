# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

FROM node:20-slim AS test-github-script

# Copy to the working directory.
COPY . /src/
WORKDIR /src

CMD ["node", "test-js/test.js"]