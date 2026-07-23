# Daily reconciliation

Post the day's earnings summary to the operator. The gateway's report is
already shaped small — relay it, don't re-fetch anything else.

## Steps

1. **Fetch report** — GET `http://127.0.0.1:4020/report/today`.
   - tools: http_request

2. **Post summary** — Send the operator 2–3 sentences: jobs completed, USDC
   earned, per-service breakdown, and — only if `refund_review_total > 0` —
   a final line listing the flagged job ids and telling the operator the
   refund-review SOP will ask for their decision. No raw JSON, no tables.
