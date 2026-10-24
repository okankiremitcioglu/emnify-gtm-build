#!/bin/bash
# Usage: ./run-tests.sh https://YOUR-INSTANCE.app.n8n.cloud/webhook
# Sends the Step 3 test cases to the n8n webhooks and prints each response.
set -u
BASE="${1:?pass the webhook base URL, e.g. https://you.app.n8n.cloud/webhook}"
KEY=$(cat "$(dirname "$0")/../secrets/clay-webhook-key.txt")
DIR="$(dirname "$0")"
post() { curl -s -X POST "$BASE/$1" -H "Content-Type: application/json" -H "x-api-key: $KEY" -d "$2"; echo; }

echo "1. Contact before its account exists (expect account_missing)"
post clay-contact "$(sed 's/acme-telematics.example/no-such-company.example/' "$DIR/sample-contact.json")"
echo "2. New Tier A account (expect ok, created true)"
post clay-account "$(cat "$DIR/sample-account.json")"
echo "3. Same account again (expect ok, created false; still one task)"
post clay-account "$(cat "$DIR/sample-account.json")"
echo "4. Tier C (expect skipped)"
post clay-account "$(sed 's/"icp_tier": "A"/"icp_tier": "C"/' "$DIR/sample-account.json")"
echo "5. Empty domain (expect skipped)"
post clay-account "$(sed 's#"domain": "[^"]*"#"domain": ""#' "$DIR/sample-account.json")"
echo "6. Contact for the account (expect ok, created true)"
post clay-contact "$(cat "$DIR/sample-contact.json")"
echo "7. Same contact again (expect ok, created false)"
post clay-contact "$(cat "$DIR/sample-contact.json")"
echo "8. Wrong API key (expect 403 / authorization error)"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST "$BASE/clay-account" -H "Content-Type: application/json" -H "x-api-key: wrong" -d '{}'
