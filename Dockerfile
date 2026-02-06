FROM alpine:3.22

RUN apk add --update --no-cache curl jq bash grep python3

COPY scripts/ /scripts/
