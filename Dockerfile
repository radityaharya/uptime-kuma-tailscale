FROM louislam/uptime-kuma:beta-slim as uptime-kuma

FROM alpine:3.14 AS adguard
WORKDIR /app
RUN wget https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.55/AdGuardHome_linux_amd64.tar.gz \
  && tar -xzf AdGuardHome_linux_amd64.tar.gz \
  && rm AdGuardHome_linux_amd64.tar.gz

FROM node:23-bookworm
ARG S6_OVERLAY_VERSION=3.2.0.0
ARG S6_OVERLAY_ARCH="x86_64"

WORKDIR /app

RUN apt-get update && apt-get install -y \
  ca-certificates \
  iptables \
  iputils-ping \
  wget \
  xz-utils \
  && rm -rf /var/lib/apt/lists/* \
  && wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -O /tmp/s6-overlay-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
  && wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz -O /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz \
  && rm -rf /tmp/*.tar.xz

# Copy uptime-kuma files
COPY --from=uptime-kuma /app /app

# Copy AdGuard binary
COPY --from=adguard /app/AdGuardHome/AdGuardHome /app/AdGuardHome

# Copy Tailscale binaries
COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscaled /app/tailscaled
COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscale /app/tailscale

RUN mkdir -p /var/run/tailscale /var/cache/tailscale /app/data/app/tailscale /app/data/app/adguardhome \
  && echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf \
  && echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf

COPY ./start.sh /app/start.sh
COPY s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d
RUN chmod +x /app/start.sh /etc/s6-overlay/s6-rc.d/*/run

EXPOSE 80

CMD ["/app/start.sh"]