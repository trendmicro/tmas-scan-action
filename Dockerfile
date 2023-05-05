FROM alpine

COPY pull-scan.sh /app/

RUN apk add bash curl sudo jq -q

RUN OS=Linux && ARCH=x86_64 && VERSION=$(curl -s "https://api.github.com/repos/google/go-containerregistry/releases/latest" | jq -r '.tag_name') && curl -sL "https://github.com/google/go-containerregistry/releases/download/${VERSION}/go-containerregistry_${OS}_${ARCH}.tar.gz" > go-containerregistry.tar.gz && tar -zxvf go-containerregistry.tar.gz -C /usr/bin/ crane

ENTRYPOINT [ "bash", "/app/pull-scan.sh" ]