FROM haproxy:3.0-alpine

USER root

# Install lua-openssl so the attestation Lua script can do ECDH + AES-128-GCM.
# Build tools are removed after install to keep the image small.
RUN apk add --no-cache lua5.4 lua5.4-dev luarocks gcc musl-dev make openssl-dev && \
    luarocks-5.4 install lua-openssl && \
    apk del lua5.4-dev gcc musl-dev make openssl-dev && \
    rm -rf /tmp/* /var/cache/apk/*

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY zerofox_attest.lua /etc/haproxy/zerofox_attest.lua
