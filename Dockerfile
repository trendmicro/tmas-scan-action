FROM alpine

# COPY pull-scan.sh /app/

RUN apk add bash curl sudo jq -q

RUN OS=Linux && ARCH=x86_64 && VERSION=$(curl -s "https://api.github.com/repos/google/go-containerregistry/releases/latest" | jq -r '.tag_name') && curl -sL "https://github.com/google/go-containerregistry/releases/download/${VERSION}/go-containerregistry_${OS}_${ARCH}.tar.gz" > go-containerregistry.tar.gz && tar -zxvf go-containerregistry.tar.gz -C /usr/bin/ crane

# Install cli on latest version
RUN curl -s -L https://gist.github.com/raphabot/abae09b46c29afc7c3b918b7b8ec2a5c/raw/ | bash

# ENTRYPOINT [ "bash", "/app/pull-scan.sh" ]
ENTRYPOINT [ "tmas" ]
