FROM alpine:3.22

RUN apk add --update --no-cache curl jq bash

COPY scripts/ /scripts/
