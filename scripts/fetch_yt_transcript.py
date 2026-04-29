#!/usr/bin/env python3
"""Fetch a YouTube video transcript without authentication.

Usage:
    python3 scripts/fetch_yt_transcript.py <video_url_or_id> [lang]

Examples:
    python3 scripts/fetch_yt_transcript.py https://www.youtube.com/watch?v=abc12345678
    python3 scripts/fetch_yt_transcript.py abc12345678 en
    python3 scripts/fetch_yt_transcript.py https://youtu.be/abc12345678 ja

Requirements:
    pip3 install --user youtube-transcript-api
"""
from __future__ import annotations

import re
import sys
from urllib.parse import parse_qs, urlparse


def extract_video_id(value: str) -> str:
    if re.match(r"^[A-Za-z0-9_-]{11}$", value):
        return value
    parsed = urlparse(value)
    if parsed.hostname == "youtu.be":
        return parsed.path.lstrip("/")
    if parsed.hostname and "youtube.com" in parsed.hostname:
        if parsed.path == "/watch":
            vid = parse_qs(parsed.query).get("v", [""])[0]
            if vid:
                return vid
        # Shorts / embed URLs
        m = re.match(r"^/(shorts|embed|live)/([A-Za-z0-9_-]{11})", parsed.path)
        if m:
            return m.group(2)
    raise ValueError(f"Cannot extract video_id from: {value}")


def fetch(video_id: str, lang: str = "ja") -> str:
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
    except ImportError:
        sys.stderr.write(
            "ERROR: youtube-transcript-api not installed.\n"
            "Run: pip3 install --user youtube-transcript-api\n"
        )
        sys.exit(2)

    api = YouTubeTranscriptApi()
    try:
        transcript = api.fetch(video_id, languages=[lang, f"{lang}-JP", "en"])
    except Exception as e:
        sys.stderr.write(f"ERROR: {type(e).__name__}: {e}\n")
        sys.exit(3)
    return "\n".join(snippet.text for snippet in transcript.snippets)


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] in {"-h", "--help"}:
        sys.stderr.write(__doc__ or "")
        return 1
    video_id = extract_video_id(sys.argv[1])
    lang = sys.argv[2] if len(sys.argv) > 2 else "ja"
    text = fetch(video_id, lang)
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
