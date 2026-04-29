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

### Step 3: read the transcript (no auth, no scraping)

```bash
# One-time install
pip3 install --user youtube-transcript-api

# Use the bochi helper
python3 scripts/fetch_yt_transcript.py <video_url_or_id> [lang]
```

A 10-minute video yields ~10k chars. Pipe into a sub-agent for summarisation
when long, or read directly for short ones.

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
