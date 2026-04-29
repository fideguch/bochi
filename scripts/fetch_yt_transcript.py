#!/usr/bin/env python3
"""Fetch a YouTube video transcript with cache-first tiered fallback.

Solves the "AWS / GCP / Azure cloud-IP is blanket-blocked by YouTube"
problem (https://github.com/jdepoix/youtube-transcript-api/issues/79)
by storing fetched transcripts in a shared cache that syncs across
environments via the existing bochi-data → S3 sync pipeline.

Architecture (tiered fallback):

    Tier 1 (instant, free, works everywhere — including cloud IPs):
      Read ~/bochi-data/transcripts/<video_id>.txt cache
    Tier 2c (cloud IP, optional Cloudflare Worker proxy):
      If BOCHI_YT_PROXY_URL is set, fetch via the Worker (Cloudflare's edge
      IP is not blocked by YouTube) → write cache → return
    Tier 2 (residential IP only, e.g., Mac at home):
      Fetch via youtube-transcript-api → write cache → return
      The cache syncs to S3 → all bot environments via existing safety-push
    Tier 3 (cloud IP, cache miss, no proxy configured):
      Exit 4 with instruction telling the operator to fetch on a residential IP

Usage:
    python3 scripts/fetch_yt_transcript.py <url_or_id> [lang]
        — try cache → Tier 2c (if configured) → Tier 2 (residential)
    python3 scripts/fetch_yt_transcript.py --cache-only <url_or_id>
        — read cache only, never call the network
    python3 scripts/fetch_yt_transcript.py --no-cache <url_or_id>
        — bypass cache, force fetch via Tier 2c then Tier 2
    python3 scripts/fetch_yt_transcript.py --list-cached
        — list video IDs currently cached

Environment variables (optional):
    BOCHI_YT_PROXY_URL    — Cloudflare Worker URL (enables Tier 2c)
    BOCHI_YT_PROXY_TOKEN  — shared secret for the Worker (X-Bochi-Token header)

Exit codes:
    0  — success (text on stdout)
    1  — usage error
    2  — youtube-transcript-api not installed (Tier 2 fallback unavailable)
    3  — all configured fetch tiers failed (likely no captions, or IP-blocked w/o proxy)
    4  — cache miss in --cache-only mode (operator should fetch on residential IP)
"""
from __future__ import annotations

import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime
from urllib.parse import parse_qs, urlparse

# Cache lives under bochi-data so it syncs via S3 across Mac (residential IP)
# and Lightsail (cloud IP, cache reader). Resolve the right path on each host.
_CANDIDATE_ROOTS = [
    pathlib.Path.home() / "bochi-data",
    pathlib.Path.home() / ".claude/bochi-data",
]
CACHE_DIR: pathlib.Path = _CANDIDATE_ROOTS[0] / "transcripts"
for _root in _CANDIDATE_ROOTS:
    if _root.exists():
        CACHE_DIR = _root / "transcripts"
        break


def extract_video_id(value: str) -> str:
    if re.match(r"^[A-Za-z0-9_-]{11}$", value):
        return value
    p = urlparse(value)
    if p.hostname == "youtu.be":
        return p.path.lstrip("/")
    if p.hostname and "youtube.com" in p.hostname:
        if p.path == "/watch":
            v = parse_qs(p.query).get("v", [""])[0]
            if v:
                return v
        m = re.match(r"^/(shorts|embed|live)/([A-Za-z0-9_-]{11})", p.path)
        if m:
            return m.group(2)
    raise ValueError(f"Cannot extract video_id from: {value}")


def cache_path(video_id: str) -> pathlib.Path:
    return CACHE_DIR / f"{video_id}.txt"


def meta_path(video_id: str) -> pathlib.Path:
    return CACHE_DIR / f"{video_id}.meta.json"


def read_cache(video_id: str) -> str | None:
    p = cache_path(video_id)
    return p.read_text() if p.exists() else None


def write_cache(video_id: str, transcript: str, source: str, lang: str) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path(video_id).write_text(transcript)
    meta_path(video_id).write_text(json.dumps({
        "video_id": video_id,
        "source": source,
        "lang": lang,
        "chars": len(transcript),
        "fetched_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    }, ensure_ascii=False, indent=2))


def list_cached() -> list[dict]:
    if not CACHE_DIR.exists():
        return []
    items: list[dict] = []
    for p in sorted(CACHE_DIR.glob("*.txt")):
        vid = p.stem
        meta = meta_path(vid)
        info: dict = {"video_id": vid, "chars": p.stat().st_size}
        if meta.exists():
            try:
                info.update(json.loads(meta.read_text()))
            except json.JSONDecodeError:
                pass
        items.append(info)
    return items


def fetch_via_proxy(video_id: str, lang: str) -> str | None:
    """Tier 2c: Cloudflare Worker proxy. Returns None if unconfigured/failed."""
    proxy_url = os.environ.get("BOCHI_YT_PROXY_URL", "").rstrip("/")
    if not proxy_url:
        return None
    token = os.environ.get("BOCHI_YT_PROXY_TOKEN", "")
    req_url = f"{proxy_url}/?id={video_id}&lang={lang}"
    headers = {"User-Agent": "bochi-fetch-yt-transcript/2.0"}
    if token:
        headers["X-Bochi-Token"] = token
    req = urllib.request.Request(req_url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:200]
        sys.stderr.write(f"[Tier 2c proxy] HTTP {e.code}: {body}\n")
        return None
    except Exception as e:
        sys.stderr.write(f"[Tier 2c proxy] {type(e).__name__}: {e}\n")
        return None


def fetch_via_api(video_id: str, lang: str) -> str:
    """Tier 2: direct youtube-transcript-api (residential IP only)."""
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
    except ImportError:
        sys.stderr.write(
            "ERROR: youtube-transcript-api not installed.\n"
            "Run: pip3 install --user youtube-transcript-api\n"
        )
        sys.exit(2)
    api = YouTubeTranscriptApi()
    tr = api.fetch(video_id, languages=[lang, f"{lang}-JP", "en"])
    return "\n".join(s.text for s in tr.snippets)


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}

    if "--list-cached" in flags:
        items = list_cached()
        if not items:
            sys.stderr.write(f"No cached transcripts in {CACHE_DIR}\n")
            return 0
        for i in items:
            sys.stdout.write(json.dumps(i, ensure_ascii=False) + "\n")
        return 0

    if not args or "-h" in flags or "--help" in flags:
        sys.stderr.write(__doc__ or "")
        return 1

    try:
        video_id = extract_video_id(args[0])
    except ValueError as e:
        sys.stderr.write(f"ERROR: {e}\n")
        return 1
    lang = args[1] if len(args) > 1 else "ja"

    cache_only = "--cache-only" in flags
    no_cache = "--no-cache" in flags

    # Tier 1: cache lookup
    if not no_cache:
        cached = read_cache(video_id)
        if cached is not None:
            sys.stderr.write(f"[cache hit] {video_id} ({len(cached)} chars)\n")
            sys.stdout.write(cached)
            return 0

    if cache_only:
        sys.stderr.write(
            f"[cache miss] {video_id}\n"
            f"  This environment cannot fetch (likely cloud IP — YouTube blocks).\n"
            f"  Operator: run on a residential IP machine (e.g., Mac at home):\n"
            f"    python3 ~/bochi/scripts/fetch_yt_transcript.py {video_id} {lang}\n"
            f"  The cache will sync via S3 to all bot environments automatically.\n"
        )
        return 4

    # Tier 2c: Cloudflare Worker proxy (preferred when configured — works on cloud IP)
    if os.environ.get("BOCHI_YT_PROXY_URL"):
        sys.stderr.write(f"[Tier 2c] proxy fetch {video_id} lang={lang}\n")
        text = fetch_via_proxy(video_id, lang)
        if text:
            write_cache(video_id, text, source="cloudflare-worker-proxy", lang=lang)
            sys.stderr.write(f"[fetched via proxy + cached] {video_id} ({len(text)} chars)\n")
            sys.stdout.write(text)
            return 0
        sys.stderr.write("[Tier 2c] proxy failed; falling through to Tier 2\n")

    # Tier 2: direct youtube-transcript-api (residential IP only)
    sys.stderr.write(f"[Tier 2] direct fetch {video_id} lang={lang}\n")
    try:
        text = fetch_via_api(video_id, lang)
    except Exception as e:
        msg = f"{type(e).__name__}: {e}"
        sys.stderr.write(f"[Tier 2 failed] {msg}\n")
        if "RequestBlocked" in msg or "IpBlocked" in msg:
            sys.stderr.write(
                "  This is the documented cloud-IP block "
                "(github.com/jdepoix/youtube-transcript-api/issues/79).\n"
                "  Solutions:\n"
                "    (a) Set BOCHI_YT_PROXY_URL + BOCHI_YT_PROXY_TOKEN to use the\n"
                "        Cloudflare Worker proxy (see worker/transcript-proxy/README.md).\n"
                "    (b) Run this command on a residential IP machine (Mac at home);\n"
                "        the cache will sync via S3 within minutes.\n"
            )
        return 3

    write_cache(video_id, text, source="youtube-transcript-api", lang=lang)
    sys.stderr.write(f"[Tier 2 fetched + cached] {video_id} ({len(text)} chars)\n")
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
