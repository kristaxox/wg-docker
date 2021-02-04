FROM golang:alpine AS build-env
LABEL maintainer=github@kristaxox
RUN apk add git make build-base libmnl-dev iptables
RUN git clone https://git.zx2c4.com/wireguard-go
WORKDIR /go/wireguard-go
RUN make && \
    make install

WORKDIR /go
ENV WITH_WGQUICK=yes
RUN git clone https://git.zx2c4.com/wireguard-tools
WORKDIR /go/wireguard-tools/src
RUN make && \
    make install


FROM alpine
RUN apk add wireguard-tools
COPY --from=build-env /usr/bin/wireguard-go /usr/bin/wg* /usr/bin/
COPY ./wg-entrypoint.sh ./wg-entrypoint
ENTRYPOINT ["./wg-entrypoint"]