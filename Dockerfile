FROM alpine:3.22

RUN apk add --update --no-cache curl jq bash python3

COPY scripts/ /scripts/
