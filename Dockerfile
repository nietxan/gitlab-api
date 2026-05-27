FROM alpine:3.22

RUN apk add --update --no-cache git curl jq yq bash grep 

COPY scripts/ /scripts/
