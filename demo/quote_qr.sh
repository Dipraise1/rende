#!/usr/bin/env bash
# quote_qr.sh [service] [prompt]
# Demo helper: requests a quote from the gateway and renders the Solana Pay
# URL as a QR code (quote_qr.png) for a phone wallet to scan. Prints the
# job_id and the exact curl to resend after paying.
set -euo pipefail

service="${1:-gpu-inference}"
prompt="${2:-Write a haiku about honest machines.}"
gateway="${GATEWAY_URL:-http://127.0.0.1:4020}"

# The quote intentionally comes back as HTTP 402, so no curl -f here.
quote=$(curl -s -X POST "$gateway/jobs/$service" -d "$prompt")
job_id=$(jq -r '.job_id // empty' <<<"$quote")
[ -n "$job_id" ] || { echo "no quote from gateway: $quote" >&2; exit 1; }
pay_url=$(jq -r '.pay_url' <<<"$quote")
amount=$(jq -r '.amount_usdc' <<<"$quote")

echo "service : $service"
echo "amount  : $amount USDC"
echo "job_id  : $job_id"
echo "pay_url : $pay_url"
echo
qrencode -o quote_qr.png -s 10 "$pay_url"
qrencode -t ANSIUTF8 "$pay_url"
echo
echo "Scan with your phone wallet, pay, then run:"
echo "  curl -X POST $gateway/jobs/$service -H 'X-Job-Id: $job_id' -d '$prompt'"
