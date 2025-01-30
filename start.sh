#!/bin/sh

mkdir -p /app/data/app/tailscale /var/run/tailscale /app/data/app/adguardhome

if [ -w /etc/resolv.conf ]; then
  echo "nameserver 127.0.0.1" >/etc/resolv.conf
  chmod 644 /etc/resolv.conf
fi

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# ref: https://community.fly.io/t/is-it-possible-to-use-my-own-init/12082/4
if [ "$$" -eq 1; then
  exec /init "$@"
else
  exec unshare --pid sh -c '
        unshare --mount-proc /init "$@" &
        child="$!"
        trap "kill -INT \$child" INT
        trap "kill -TERM \$child" TERM
        until wait "$child" || ! kill -0 "$child" 2>/dev/null; do :; done
    ' sh "$@"
fi
