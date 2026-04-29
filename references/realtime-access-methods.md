# Real-Time Access Methods (YouTube / X)

## Why This Exists

WebFetch alone cannot reach the body of X (twitter.com / x.com) posts or YouTube
video pages — both gate content behind dynamic rendering and HTTP 402/403.
Article-only research therefore misses two of the freshest signal sources for
product, AI, and business topics.

This reference defines auth-free access patterns the Phase C ReAct loop should
use whenever a domain benefits from creator videos or practitioner posts.

> Origin: extracted from `pokemon-champions/references/realtime_access_methods.md`
> and adapted to bochi's E-E-A-T scoring + ReAct flow.

---

## Method 1 — YouTube via RSS + Transcript API

### Step 1: resolve `@handle` → internal channelId

```bash
curl -s -L "https://www.youtube.com/@<HANDLE>" \
  | grep -oE '"channelId":"[^"]+"' | head -1
# → "channelId":"UCxxxxxxxxxxxxxxxxxxxxxx"
```

### Step 2: pull the latest 15 videos via RSS (no auth)

```
WebFetch URL: https://www.youtube.com/feeds/videos.xml?channel_id=<UC_ID>
```

Returns title, publish date, and video URL. Sort by date for freshness.

### Step 3: read the transcript (cache-first tiered fallback)

YouTube blanket-blocks **most cloud-provider IPs** (AWS / GCP / Azure) — see
[jdepoix/youtube-transcript-api#79](https://github.com/jdepoix/youtube-transcript-api/issues/79).
Naïvely calling the API from Lightsail or any cloud-hosted bot environment
will fail with `RequestBlocked` / `IpBlocked`. The bochi helper solves this
with a **shared cache that syncs via S3** and a residential-IP fetcher.

#### Architecture

```
Tier 1 — instant, free, works everywhere (including cloud IPs):
  Read ~/bochi-data/transcripts/<video_id>.txt
        ↓ miss
Tier 2 — residential IP only (Mac at home):
  Fetch via youtube-transcript-api → write cache → return
  Cache syncs S3 → all bot environments via existing safety-push (5min)
        ↓ cache-only mode hit (no residential IP path available)
Tier 3 — cloud IP, cache miss:
  Exit 4 with operator instruction (run on residential IP)
```

> **Note on Tier 2c (Cloudflare Worker proxy):**
> The `worker/transcript-proxy/` Worker exists in the repo and is deployable,
> but as of **2026-04** YouTube blocks Cloudflare's egress IPs the same way
> it blocks AWS/GCP/Azure. Verified empirically by trying the ANDROID, WEB,
> and TVHTML5 Innertube clients — all returned `LOGIN_REQUIRED` /
> `Precondition check failed` / `ERROR` from Cloudflare.
> The Worker is kept in the tree for two reasons: (1) future YouTube policy
> may relax, (2) it can be combined with a residential proxy (Webshare,
> Bright Data) or a third-party API (Supadata) to become operational at
> non-zero cost. Until then, **rely on Tier 1 + Tier 2 (Mac fetch)**.

#### One-time setup (residential IP machine)

```bash
pip3 install --user youtube-transcript-api
```

#### Usage

```bash
# Cache-first (recommended on bot environments)
python3 scripts/fetch_yt_transcript.py --cache-only <url_or_id>

# Cache-first, fall back to fetch if on residential IP
python3 scripts/fetch_yt_transcript.py <url_or_id> [lang]

# Bypass cache (force fetch — residential IP only)
python3 scripts/fetch_yt_transcript.py --no-cache <url_or_id>

# List what is cached right now
python3 scripts/fetch_yt_transcript.py --list-cached
```

A 10-minute video yields ~10k chars. **Always pipe long transcripts into
a sub-agent for summarisation** — see "Sub-agent summarisation pattern"
below. Do NOT cite long transcripts verbatim in Phase E output.

#### Sub-agent summarisation pattern (recommended for any video > 3 min)

Adopted from `pokemon-champions/references/data_extraction_guide.md` §4.

```
1. Channel-level filtering (RSS → titles)
   ─ Fetch the channel feed (Method 1 Step 2)
   ─ Filter to titles matching the user's idea keywords
2. Title hit ⇒ fetch the transcript (Method 1 Step 3)
3. Dispatch a `general-purpose` sub-agent with the transcript:
   ─ Prompt: "Summarise this YouTube transcript for the question
     '<user idea>'. Extract: thesis, 3 supporting claims, the speaker's
     evidence type (data / experience / opinion), 1 counter-position
     mentioned. Cite by minute marker if present."
4. Score the summary against E-E-A-T criteria — the speaker's reputation
   and the transcript's evidence type drive the score. Apply the
   format cap from quality-criteria.md (video+transcript ≤ 36/40).
5. Use the summary as a "why is this idea trending / what do practitioners
   actually say" signal — NOT as numerical ground truth.
```

Why a sub-agent and not direct reading: long transcripts blow up the main
context budget and dilute the ReAct loop's focus. A sub-agent returns
~300-character structured digest you can act on.

#### Storage layout

```
~/bochi-data/transcripts/
├── <video_id>.txt          # plain transcript
└── <video_id>.meta.json    # {"video_id","source","lang","chars","fetched_at"}
```

`transcripts/` is **Mac-owned** for writes (residential IP). Lightsail
(cloud IP) reads only — its bochi-s3-push.sh exclude list does not need to
change because the bot never writes here.

#### Why this matters for Phase C

When the Phase C ReAct loop needs to inspect a video's content (not just
the title from RSS), it should call `--cache-only` first. If hit, the bot
can reason over the full transcript in a single iteration. If miss, the
bot surfaces the cache-miss to the user — who can fetch from their Mac
(takes seconds) and the cache will arrive at Lightsail within ~5 min.

This pattern is the standard cache-first / residential-fetch architecture
adopted across the open-source community for the documented cloud-IP block
(see Webshare proxies for the paid alternative — `youtube-transcript-api`
ships with built-in `WebshareProxyConfig` support).

#### Tier 2c — Cloudflare Worker proxy (currently inactive, kept for future)

A stateless Worker (`worker/transcript-proxy/index.js`) was built to let
cloud-hosted bots fetch transcripts directly. As of **2026-04** YouTube
blocks Cloudflare's egress the same way it blocks AWS — verified by
testing ANDROID / WEB / TVHTML5 Innertube clients (all rejected). The
Worker code is preserved because:

- A residential proxy add-on (Webshare ≈ $1/mo) makes it instantly viable
- Future YouTube policy changes may re-enable direct edge access
- The same code can be repointed at a paid third-party (Supadata, etc.)

If the operator chooses to revive Tier 2c in any of those modes, set the
two env vars on the bot host:

```bash
BOCHI_YT_PROXY_URL=https://<your-worker>.workers.dev
BOCHI_YT_PROXY_TOKEN=<shared-secret>
```

`scripts/fetch_yt_transcript.py` will automatically prefer Tier 2c when
both vars are set; otherwise it falls through to Tier 2 / Tier 3 as
documented above. No code change needed.

---

## Method 2 — X (Twitter) via Nitter RSS

### Primary instances (verified 2026-04-30)

| URL | Purpose | Status |
|-----|---------|--------|
| `https://nitter.net/<user>/rss` | RSS feed | ✅ recommended |
| `https://nitter.net/<user>` | HTML profile | ✅ |
| `https://nitter.poast.org/<user>/rss` | backup | ⚠️ flaky |
| `https://nitter.privacydev.net/<user>/rss` | backup | ⚠️ flaky |

### Usage

```
WebFetch URL: https://nitter.net/<USER>/rss
Prompt: "Extract @<USER>'s latest posts as title/body/timestamp"
```

### Liveness probe before relying on an instance

```bash
curl -sI "https://nitter.net/<USER>/rss" | head -1
# HTTP/2 200 = good
# 403 / 404 / 502 = rotate to backup
```

---

## Method 3 — Fallbacks when Nitter is down

Try in order:

1. **Google site search**: `site:x.com @<user> <keyword>`
2. **WebSearch with `site:x.com`** in the query
3. **Wayback Machine**: `https://web.archive.org/web/<ts>/https://twitter.com/<user>`
4. **vxtwitter** (single post only): `https://api.vxtwitter.com/<user>/status/<id>`
5. **snscrape** (Python, unstable): `pip install snscrape`
6. **twscrape** (Python, requires session cookie)

---

## When Phase C Should Use These

Domain signals that justify YouTube/X research:

| Domain | Signal | Likely high-value source |
|--------|--------|---------------------------|
| PM / Product | "what do PMs at GAFA actually do?" | Lenny's Podcast (YT), Reforge talks |
| AI / ML | breaking model release, paper interpretation | researcher X accounts, Anthropic/OpenAI YT |
| Technology | tooling demos, post-mortems | engineer YT (Theo, Primeagen), staff-eng X |
| Business | founder narrative, raise commentary | a16z YT, founder X threads |
| Design | live critiques, prototyping demos | NN Group YT, designer X |
| Advertising | platform-policy reactions | platform-team X (Google Ads, Meta) |

**Always pair video/SNS with a written source when scoring**, because a single
thread or talk rarely meets E-E-A-T 28/40 alone (see `quality-criteria.md`).

---

## Freshness Marking (Critique Phase D)

When the answer leans on YouTube/X content, the output must show:

```
鮮度: < {hours}h since publish
取得時刻: {ISO 8601}
情報源:
  - YouTube ${channel} ${title} (公開: ${date})
  - X @${user} ポスト (${date})
```

- < 24h → "fresh", preferred for trend questions
- 24–72h → "ok"
- > 72h → mark "stale" — usually find a newer signal instead

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `nitter.net` 403 | rate-limited / banned IP | rotate to `nitter.privacydev.net` or fall back to Method 3 |
| `youtube_transcript_api` raises `NoTranscriptFound` | autocaptions off / silent video | retry with `languages=['en','any']`; if still fails skip |
| YouTube channel RSS empty | brand-new or 0 uploads | confirm channelId; check `/about` page |
| WebFetch on a YouTube watch URL returns only footer | JS-rendered, expected | use RSS + transcript instead |
| transcript dump too long for one prompt | 60-min lecture etc. | dispatch a sub-agent with the raw text and ask for structured summary |

---

## Known channel/account catalogue (extend over time)

Curated in `learned-channels.md`. Append-only — promote here only after a
positive user feedback round confirms quality.

---

## Related references

- `learned-channels.md` — verified channel/account inventory
- `learned-sources.md` — verified URL inventory
- `quality-criteria.md` — E-E-A-T scoring with the video/SNS rubric
- `trusted-domains.md` — domain allowlist (now includes YT/X categories)
- `research-strategy.md` — domain-specific search patterns
- `scripts/fetch_yt_transcript.py` — auth-free transcript helper
