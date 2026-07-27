# Setup

Target: running in an evening. Two pieces — the gateway (sells the services) and
the ZeroClaw agent (talks to you). The gateway works standalone; the agent adds
reporting and refund approvals.

## 1. Gateway

```sh
git clone https://github.com/Dipraise1/rende && cd rende
cp services.example.toml services.toml
# edit services.toml:
#   - operator.receive_address = your Solana address (rende never sees its key)
#   - operator.rpc_url         = your RPC (public mainnet works to start)
#   - one [[service]] block per thing you sell
cargo build --release --manifest-path gateway/Cargo.toml
./gateway/target/release/rende-gateway services.toml
```

Smoke it:

```sh
curl localhost:4020/services
curl -X POST localhost:4020/jobs/gpu-inference
# → HTTP 402 with a job_id and a solana: pay URL
# pay it from any wallet, then:
curl -X POST localhost:4020/jobs/gpu-inference -H "X-Job-Id: <job_id>" -d "your prompt"
# → gateway verifies the payment on-chain and runs your adapter
curl localhost:4020/report/today
# → compact daily summary (this is what the agent reads)
```

The gateway binds `127.0.0.1` by default. To sell publicly, front it with a
reverse proxy or tunnel (Caddy, cloudflared, Tailscale Funnel) — TLS is that
layer's job.

## 2. Adapters

Each `[[service]]` runs one executable per paid job — see
[adapters.md](adapters.md). The repo ships two references:

- `adapters/gpu_infer.sh` — forwards prompts to an Ollama endpoint (`INFER_URL`)
- `adapters/store_blob.sh` — encrypted blob storage with claim tickets
  (`STORAGE_AGE_RECIPIENT` for age encryption)

## 3. ZeroClaw agent (front-of-house on Telegram)

The agent quotes customers, delivers paid results in chat, reports revenue
daily, and holds the approval checkpoint for refund reviews — it never
touches payments. Full install in [`agent/README.md`](../agent/README.md);
the short version:

```sh
# a) a tool-calling model the agent can reach — self-hosted reference:
ollama pull qwen3:14b        # on your GPU box; 7B-class models fabricate
                             # pay_urls under pressure — don't go smaller

# b) ZeroClaw (stock release binary), then deploy this repo's composition
#    per agent/README.md: config.example.toml -> ~/.zeroclaw/config.toml,
#    skills + SOPs into the shared tree, bot token via env
# edit ~/.zeroclaw/config.toml:
#   providers.models.ollama.rig  -> your box's IP, model qwen3:14b, temperature 0.2
#   channels.telegram.default    -> your bot token (from @BotFather)

zeroclaw sop validate        # both SOPs must parse; checkpoint shows
                             # [confirmation required]
zeroclaw daemon              # message your bot: "how's business today?"
```

Two config lines matter more than they look (both already set in
`agent/config.example.toml`):

- `allowed_tools = ["http_request", "memory_recall", "memory_store"]` — local
  models grab plausible ambient tools (`ask_user`, `channel_room`) instead of
  `http_request`; pinning the surface is what makes them reliable.
- The skill quotes via `GET /quote/{service_id}`, never `/jobs` — agent HTTP
  tools drop non-2xx bodies, so the x402 `402` quote would never reach the
  model.

For a phone-payable QR without the agent: `demo/quote_qr.sh gpu-inference`.

## 4. Integrating as a customer (any client, human or agent)

The gateway speaks plain HTTP — no SDK:

```sh
# discover what's for sale
curl <gateway>/services

# x402 flow (machine clients): POST the job, read the 402
curl -X POST <gateway>/jobs/gpu-inference -d "your prompt"
# → 402 {"job_id", "amount_usdc", "pay_url", "expires_at"}
# pay pay_url (Solana Pay: any wallet, or programmatically), then re-POST:
curl -X POST <gateway>/jobs/gpu-inference -H "X-Job-Id: <job_id>" -d "your prompt"
# → 200 {"status":"completed","result":...} once the payment confirms

# agent-tooling flow: same quote as HTTP 200 (many agent HTTP tools
# swallow non-2xx response bodies)
curl <gateway>/quote/gpu-inference
```

Rules your client should honor: quotes expire (default 300 s) and each
reference key is single-use — re-quote rather than retry a stale `job_id`; a
402 on the paid call means the payment hasn't confirmed yet — back off a few
seconds and re-POST (the quote is kept, you are not double-charged).

## Custody notes

- The gateway holds **no keys**. `receive_address` is a plain address; payment
  verification is read-only RPC (`getSignaturesForAddress` + token-balance
  deltas on the quote's reference key).
- A paid job that fails is **never silently retried or refunded** — it lands in
  `refund_review` in the daily report, and refunds happen only through the
  agent's human-approval checkpoint.
- Quotes expire (`quote_ttl_secs`, default 300s); each quote's reference key is
  single-use.
