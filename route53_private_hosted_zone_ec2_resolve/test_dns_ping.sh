#!/usr/bin/env bash
# Simple utility to verify DNS resolution and connectivity
# Usage: bash test_dns_ping.sh <fqdn-to-ping>
set -euo pipefail

TARGET=${1:-}
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <fqdn-to-ping>" >&2
  exit 1
fi

echo "Resolving $TARGET ..."
dig +short "$TARGET" || true

echo "Pinging $TARGET ..."
ping -c 4 "$TARGET"

