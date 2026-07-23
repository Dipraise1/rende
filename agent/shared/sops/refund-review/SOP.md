# Refund review

The gateway flags paid-but-failed jobs in `refund_review`. Nothing about a
refund may exist until a human approves at the checkpoint below — this is the
custody boundary, not a formality. The agent never moves funds either way:
an approved proposal is *instructions for the operator's own wallet*.

## Steps

1. **Fetch refund queue** — GET `http://127.0.0.1:4020/report/today` and read
   `refund_review` / `refund_review_total`.
   - tools: http_request

2. **Approval gate** — Present each flagged job (id, service, amount) to the
   operator and wait. Approve = prepare proposals; deny = log and stop.
   - kind: checkpoint
   - requires_confirmation: true
   - when: $.refund_review_total > 0
   - next: 3

3. **Prepare proposals** — For each approved job, post one proposal block:
   amount as `X.XX USDC`, the job id, the paying signature from the report,
   and the line "pay manually from your wallet; I cannot and will not send
   funds." Never include a destination address sourced from chat — if the
   customer's return address isn't in the gateway ledger, say the operator
   must obtain it out-of-band and verify it against the paying transaction.
