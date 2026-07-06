#!/usr/bin/env python3
"""Send the latest bochi newspaper to Discord DM (mobile-friendly format).

Reads the bot token from ~/.claude/channels/discord/.env and recipient user ID
from ~/.claude/channels/discord/access.json (first allowFrom entry).

Renders the newspaper from markdown tables to article cards optimised for
the Discord mobile app (vertical scroll, no horizontal table, suppressed
link embeds).

Usage:
    python3 send-newspaper-to-discord.py            # actually send
    python3 send-newspaper-to-discord.py --dry-run  # report only
"""
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

HOME = pathlib.Path.home()
# ~/.claude/bochi-data is a symlink to ~/bochi-data on the Mac (real path on
# Lightsail is ~/.claude/bochi-data). Resolve so both hosts read the same dir.
NEWSPAPER_DIR = (HOME / ".claude/bochi-data/newspaper").resolve()
ENV_FILE = HOME / ".claude/channels/discord/.env"
ACCESS_FILE = HOME / ".claude/channels/discord/access.json"
LOG_FILE = (HOME / ".claude/bochi-data/errors/newspaper-discord.log").resolve()
CHUNK_LIMIT = 1900
DRY_RUN = "--dry-run" in sys.argv
# Only deliver a newspaper generated for today (JST). Never fall back to an
# older file — that caused the same stale brief to be resent every morning.
# Set BOCHI_NEWSPAPER_MAX_AGE_DAYS to allow a slightly older file if needed.
MAX_AGE_DAYS = int(__import__("os").environ.get("BOCHI_NEWSPAPER_MAX_AGE_DAYS", "0"))


def log(msg: str) -> None:
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    ts = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{ts} {'[DRY] ' if DRY_RUN else ''}{msg}"
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")
    print(line)


def load_token() -> str:
    for line in ENV_FILE.read_text().splitlines():
        if line.startswith("DISCORD_BOT_TOKEN="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise RuntimeError(f"DISCORD_BOT_TOKEN not found in {ENV_FILE}")


def load_recipient() -> str:
    access = json.loads(ACCESS_FILE.read_text())
    allowed = access.get("allowFrom") or []
    if not allowed:
        raise RuntimeError("access.json has empty allowFrom — no DM target")
    return allowed[0]


class NoFreshNewspaper(Exception):
    """No newspaper generated for today — skip delivery instead of resending
    an old one."""


def pick_newspaper() -> pathlib.Path:
    """Return today's (JST) newspaper file, or one within MAX_AGE_DAYS.
    Raises NoFreshNewspaper if none is fresh — the caller skips delivery."""
    today = datetime.now(ZoneInfo("Asia/Tokyo")).date()
    for age in range(MAX_AGE_DAYS + 1):
        d = today - __import__("datetime").timedelta(days=age)
        candidate = NEWSPAPER_DIR / f"{d.isoformat()}.md"
        if candidate.exists() and candidate.stat().st_size > 0:
            return candidate
    newest = "none"
    files = sorted(NEWSPAPER_DIR.glob("*.md"))
    if files:
        newest = files[-1].name
    raise NoFreshNewspaper(
        f"no newspaper for {today.isoformat()} (max_age={MAX_AGE_DAYS}d); "
        f"newest on disk is {newest} — generation likely did not run"
    )


_LINK_RE = re.compile(r"\[([^\]]+)\]\((https?://[^)]+)\)")
_TABLE_HEADER_RE = re.compile(r"^\|\s*#\s*\|", re.IGNORECASE)
_TABLE_SEPARATOR_RE = re.compile(r"^\|[\s|:\-]+\|\s*$")


def parse_newspaper(text: str):
    """Return (title, [(category, [article_dict])])."""
    title_match = re.search(r"^# (.+?)$", text, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else "Daily Brief"

    categories: list[tuple[str, list[dict]]] = []
    current_cat: str | None = None
    current_articles: list[dict] = []

    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("### "):
            if current_cat is not None:
                categories.append((current_cat, current_articles))
            current_cat = stripped[4:].strip()
            current_articles = []
            continue
        if stripped.startswith("## ") and current_cat is not None:
            # End of last category before next h2 (e.g., "## まとめ")
            categories.append((current_cat, current_articles))
            current_cat = None
            current_articles = []
            continue
        if not stripped.startswith("|") or _TABLE_HEADER_RE.match(stripped) or _TABLE_SEPARATOR_RE.match(stripped):
            continue

        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 5:
            continue
        num = cells[0]
        if not num.isdigit():
            continue
        article_title = cells[1]
        source_cell = cells[2]
        score = cells[3]
        summary = cells[4]
        url_match = _LINK_RE.search(source_cell)
        url = url_match.group(2) if url_match else None
        source_text = _LINK_RE.sub(r"\1", source_cell).strip()
        current_articles.append({
            "num": num,
            "title": article_title,
            "url": url,
            "source_text": source_text,
            "score": score,
            "summary": summary,
        })

    if current_cat is not None:
        categories.append((current_cat, current_articles))

    # Drop empty categories
    categories = [(c, arts) for c, arts in categories if arts]
    return title, categories


def render_article(a: dict) -> str:
    parts = [f"**{a['num']}. {a['title']}**"]
    meta_bits = []
    if a.get("score"):
        meta_bits.append(f"📊 {a['score']}")
    if a.get("url"):
        # Wrap in <> to suppress Discord embed preview (cleaner mobile UI)
        meta_bits.append(f"🔗 <{a['url']}>")
    elif a.get("source_text"):
        meta_bits.append(f"🔗 {a['source_text']}")
    if meta_bits:
        parts.append(" | ".join(meta_bits))
    if a.get("summary"):
        parts.append(a["summary"])
    return "\n".join(parts)


def build_messages(title: str, categories, chunk_limit: int) -> list[str]:
    """Build Discord-ready messages: header first, then per-category bundles
    that respect the chunk_limit (split between articles when too long)."""
    messages: list[str] = [f"📰 **{title}**"]
    for cat_name, articles in categories:
        cat_header = f"━━━ **{cat_name}** ━━━"
        rendered = [render_article(a) for a in articles]
        # Greedy pack into chunks
        buf = cat_header
        for art in rendered:
            candidate = buf + "\n\n" + art
            if len(candidate) > chunk_limit:
                if buf and buf != cat_header:
                    messages.append(buf)
                # Start a new chunk; if even single article + header overflows, split article
                if len(cat_header + "\n\n" + art) > chunk_limit:
                    # Hard-fallback: send header alone, then article alone (may exceed slightly but Discord accepts up to 2000)
                    messages.append(cat_header)
                    if len(art) > chunk_limit:
                        # Last-resort line split
                        for line in art.splitlines():
                            messages.append(line[:chunk_limit])
                        buf = ""
                    else:
                        buf = art
                else:
                    buf = cat_header + "\n\n" + art
            else:
                buf = candidate
        if buf:
            messages.append(buf)
    return messages


def discord_post(url: str, token: str, payload: dict) -> dict:
    req = urllib.request.Request(
        url,
        method="POST",
        headers={
            "Authorization": f"Bot {token}",
            "Content-Type": "application/json",
            "User-Agent": "bochi-newspaper-cron/1.1",
        },
        data=json.dumps(payload).encode(),
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())


def main() -> int:
    log(f"--- run start (dry={DRY_RUN}) ---")
    try:
        token = load_token()
        user_id = load_recipient()
        try:
            newspaper = pick_newspaper()
        except NoFreshNewspaper as e:
            log(f"SKIP: {e}")
            log("--- run skipped (no fresh newspaper) ---")
            return 0
        body = newspaper.read_text()
        title, categories = parse_newspaper(body)
        article_count = sum(len(arts) for _, arts in categories)
        # A file that parses to zero articles is malformed — skip rather than
        # send an empty brief (defence-in-depth alongside the generator's guard).
        if article_count == 0:
            log(f"SKIP: {newspaper.name} parsed to 0 articles — malformed, not sending")
            log("--- run skipped (malformed newspaper) ---")
            return 0
        log(f"newspaper={newspaper.name} bytes={newspaper.stat().st_size} categories={len(categories)} articles={article_count} recipient={user_id}")

        messages = build_messages(title, categories, CHUNK_LIMIT)
        log(f"messages={len(messages)} total_chars={sum(len(m) for m in messages)}")

        if DRY_RUN:
            for i, m in enumerate(messages, 1):
                preview = m.replace("\n", " | ")[:80]
                log(f"  msg {i}/{len(messages)}: {len(m)} chars | preview: {preview!r}")
            return 0

        dm = discord_post(
            "https://discord.com/api/v10/users/@me/channels",
            token,
            {"recipient_id": user_id},
        )
        dm_id = dm["id"]
        log(f"dm_channel={dm_id}")

        for i, msg in enumerate(messages, 1):
            content = msg.rstrip()
            if not content:
                continue
            try:
                discord_post(
                    f"https://discord.com/api/v10/channels/{dm_id}/messages",
                    token,
                    {"content": content},
                )
                log(f"  sent {i}/{len(messages)} ({len(content)} chars)")
            except urllib.error.HTTPError as e:
                err_body = e.read().decode("utf-8", errors="replace")
                log(f"  ERROR sending {i}/{len(messages)}: HTTP {e.code} {err_body}")
                return 1

        log("--- run ok ---")
        return 0
    except Exception as e:
        log(f"FATAL: {type(e).__name__}: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
