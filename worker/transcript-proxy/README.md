# bochi YouTube transcript proxy (Cloudflare Worker)

A tiny Cloudflare Worker that fetches YouTube transcripts on behalf of
cloud-IP-blocked clients — primarily the bochi Discord bot on Lightsail
(AWS), whose IP is blanket-blocked by YouTube.

> Why Cloudflare? Their edge IPs are not on YouTube's cloud-IP block list,
> so a Worker can reach YouTube where AWS / GCP / Azure cannot. The free
> tier (100k req/day) is far above what bochi needs.

## What it does

- Accepts `GET /?id=<video_id>&lang=<lang>` (or `?url=<watch_url>`)
- Hits the public watch page from Cloudflare's edge (residential-class IP)
- Extracts the captionTracks JSON, picks the best language track
- Fetches and parses the caption XML, returns plain text (one cue per line)
- Optional `X-Bochi-Token` header check via `WORKER_SHARED_SECRET` var

## Deploy (Cloudflare Dashboard, ~5 minutes)

1. **Cloudflare Dashboard → Workers & Pages → Create**
2. **Create Worker** → name it `bochi-yt-transcript` (or anything)
3. **Edit Code** → delete the boilerplate → paste the contents of `index.js`
4. **Save and Deploy**
5. **Settings → Variables and Secrets → Add variable**
   - Name: `WORKER_SHARED_SECRET`
   - Value: a random ~32-char string (e.g., `openssl rand -hex 24`)
   - Type: **Encrypt** (so the value is hidden after save)
6. Copy the Worker URL displayed at the top (e.g.,
   `https://bochi-yt-transcript.<account>.workers.dev`)

## Wire into bochi

On the host that needs it (Lightsail bot), add the URL + token to
`~/.claude/channels/discord/.env`:

```bash
BOCHI_YT_PROXY_URL=https://bochi-yt-transcript.<account>.workers.dev
BOCHI_YT_PROXY_TOKEN=<your-secret>
```

`scripts/fetch_yt_transcript.py` automatically uses Tier 2c when both vars
are present and the local cache misses.

## Verify

```bash
curl -s -H "X-Bochi-Token: $BOCHI_YT_PROXY_TOKEN" \
  "$BOCHI_YT_PROXY_URL/?id=zjkBMFhNj_g&lang=en" | head -3
# Expected: first lines of the Karpathy LLM intro transcript
```

## Cost / quota

| Plan | Daily request limit | bochi typical usage |
|------|--------------------:|--------------------:|
| Free | 100,000 | ~10–50 |

Even with aggressive bot use, free tier is comfortable.

## Security notes

- Always set `WORKER_SHARED_SECRET`. Without it, anyone who finds the URL
  can use your Worker quota.
- Never commit the secret. It lives only in Cloudflare's encrypted vars
  and the bot host's local `.env`.
- The Worker is read-only — it has no database, no write access to anything.

## Local dev (optional)

```bash
npm install -g wrangler
cd worker/transcript-proxy
wrangler dev   # local preview
wrangler deploy   # CLI deploy (alternative to Dashboard)
```
