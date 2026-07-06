# bochi v2.6 — PM Companion

A Claude Code skill that turns idea seeds (memos, URLs, sparks) into structured
hypotheses and supports daily PM work as a thinking companion.
**Talk to the Claude running on this Mac, anytime, from a Discord DM.**

## Product Vision

bochi is a "thinking hub accessible from anywhere" for PMs.

1. **Thinking Hub**: the same memory from Discord DM, Mac CLI, or anywhere
2. **Mac-resident brain**: the Discord responder is the Claude Code session on
   the Mac — with local filesystem and cross-project memory access
3. **S3 Data Hub**: bochi-data syncs across environments via S3
4. **Proactive Memo Save**: bochi proposes saving valuable conversations

## Architecture at a Glance

```
Discord DM (owner allowlist only)
  │ Gateway WebSocket (same bot token, exactly one responder)
  ├─ Lightsail server.ts … dmPolicy=disabled → drop all (kept as newspaper host)
  └─ Mac server.ts ───────→ Mac-resident Claude Code session (the only --channels responder)
                             ├ tmux -L claude-bridge / launchd resident + 120s health
                             ├ cwd ~/bochi-runtime (CLAUDE.md = deploy/mac-claude.md)
                             ├ 3-layer perms: allow / ask (Discord 🔐 relay) / hard-deny
                             └ recalls ~/.claude/projects/*/memory across projects
```

- **The Mac responds**: only the session launched with `--channels plugin:discord`
  receives messages. Lightsail is silenced via `access.json` `dmPolicy:"disabled"`
  (re-read per message; a 1-key, reversible cutover).
- **Newspaper is generated and delivered on the Mac**: launchd at 06:20 JST
  (generate) and 08:00 JST (deliver).
- Full setup / ops / rollback: **`references/mac-bridge-setup.md`**.

## What's New in v2.6 (2026-07-06) — Mac-Resident Claude Bridge

- **Residency**: launchd (RunAtLoad + 120s health) + a dedicated tmux socket
  `claude-bridge`, on top of the mobile-dev-bridge caffeinate substrate. Does not
  depend on the CLI startup banner (which changes across updates); treats the idle
  TUI prompt as healthy to avoid restart loops.
- **Auth overhaul**: drops `--dangerously-skip-permissions` → default-deny perms +
  **Discord permission relay (approve with a 🔐 button on your phone)**. Secret
  stores, self-modification, and any tmux interference are hard-denied by a
  fail-close guard (path-normalized + case-insensitive to close APFS/`../`/
  relative-path/interpreter-write bypasses).
- **Memory hub**: recalls `~/.claude/projects/*/memory/`. PC state is read via
  read-only wrappers (`pc-status` / `repo-status`) — raw `ps|grep` / `tmux ls`
  trigger permission prompts, so the wrappers are mandatory.
- **Non-interference guardrail**: never `send-keys`/`attach` into other projects'
  Claude sessions; heavy work is delegated to headless `claude -p`/`--bg`.
- **Newspaper revival**: the Lightsail RemoteTrigger generation cron had stopped
  (delivery was resending the same stale issue daily). Generation and delivery
  moved to Mac launchd; delivery sends only *today's* issue (no stale fallback).
- **Data layer**: bochi-data's real path moved to `~/bochi-data` (writes under
  `~/.claude/` are blocked as sensitive files); `~/.claude/bochi-data` is a
  symlink. `seen.jsonl` is union-merge synced on both sides.
- Verification: `tests/mac-bridge-e2e.sh` (40 checks) + `.evals/` (failure
  taxonomy + eval specs).

## 8 Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| 1 Idea | `bochiして`, URL, thinking verbs + context | Deep dive + expand + research |
| 2 Newspaper | `新聞`, `朝刊`, daily launchd | Daily curated news by interest |
| 3 Casual Chat | `おすすめ`, `何か面白い？` | Related updates + serendipity |
| 4 Memory | `記憶整理`, `覚えてること教えて` | Search, review, archive |
| 5 Companion | `メモある？`, `前に話したやつ` | Surface relevant memos during work |
| 6 Google Brief | `今日の予定`, `メール確認` | Calendar + Gmail from cache |
| 7 PM Tools | `イシュー一覧`, `チケット作って` | Linear/GitHub Issue delegation |
| 8 Vocab | `単語帳`, `クイズ`, a bare word/phrase | Vocabulary notebook + SM-2 quiz |

The default conversational persona is Claude itself (natural Japanese). The mode
router in `~/.claude/skills/bochi/SKILL.md` engages on the triggers above.

## Quick Start

Talking to it: just DM the bot on Discord — the responder is the Mac-resident
Claude.

Setting up / updating the Mac bridge:

```bash
cd ~/bochi
bash deploy/mac/setup-bridge.sh              # dry-run first
bash deploy/mac/setup-bridge.sh --apply      # build runtime + register 4 launchd agents
bash ~/bochi-runtime/bin/bridge-start.sh start
bash tests/mac-bridge-e2e.sh --with-lightsail
```

Registered launchd agents:

| Label | Schedule | Role |
|-------|----------|------|
| `com.fideguch.claude-bridge` | RunAtLoad | bridge session |
| `com.fideguch.claude-bridge-health` | 120s | liveness + usage-limit modal handling |
| `com.fideguch.bochi-newspaper-gen` | 06:20 JST | generate today's brief |
| `com.fideguch.bochi-newspaper-deliver` | 08:00 JST | deliver today's brief only |

## Newspaper Pipeline (Mode 2)

```
[generate] com.fideguch.bochi-newspaper-gen (06:20 JST)
  → deploy/mac/generate-newspaper.sh runs claude -p
  → interests × WebSearch × E-E-A-T filter → ~/bochi-data/newspaper/YYYY-MM-DD.md
  → on failure, leaves no partial file (delivery then skips)

[deliver] com.fideguch.bochi-newspaper-deliver (08:00 JST)
  → deploy/send-newspaper-to-discord.py delivers ONLY today's issue
  → if today's issue is missing, skips (never resends an old one)
  → article-card format, embeds suppressed for mobile
```

## Data Layer

Real path is `~/bochi-data/` (`~/.claude/bochi-data` is a symlink to it).

```
~/bochi-data/
├── index.jsonl              # Master search index (JSONL append)
├── user-profile.yaml        # Interests, category weights, settings
├── seen.jsonl               # Seen-URL tracking (union-merge synced both sides)
├── topics/  memos/  newspaper/  conversations/  context-seeds/  vocab/
├── reflections/  stats/  sources/  cache/  archive/
└── errors/                  # logs incl. bridge-watchdog.jsonl, newspaper-gen/deliver
```

### Write Ownership (after the responder cutover)

| Data | Owner | Bridge access |
|------|-------|---------------|
| memos/ index.jsonl context-seeds/ vocab/ errors/ topics/ conversations/ newspaper/ | Mac | read-write |
| seen.jsonl | both (union-merge) | read-write |
| user-profile.yaml reflections/ sources/ stats/ cache/ | Lightsail | read-mostly |

## Permission Model (3 layers)

| Layer | Scope | Behavior |
|-------|-------|----------|
| allow | home reads (deny wins) / writes to bochi-data & workspace / WebSearch / trusted-domain WebFetch / Discord tools / status wrappers | no prompt |
| ask | anything else (writes elsewhere, arbitrary Bash, unknown-domain WebFetch) | Discord 🔐 button approval |
| hard-deny | secret stores (.ssh/.aws/gh/gcloud/tokens) / enforcement self-mod / tmux interference | not approvable (fail-close guard) |

## Integrated Frameworks

Socratic Method · SCAMPER · ReAct · E-E-A-T · First-Principles · Opportunity
Solution Tree (Teresa Torres) · Mom Test / JTBD.

## When NOT to use

Team brainstorming (use Miro/FigJam AI) · exhaustive multi-source research (use
Deep Research) · well-defined requirements (use /requirements_designer) ·
quantitative analysis (use /pm-data-analysis) · substantial implementation in
other directories (the bridge delegates instead of editing).

## License & Credits

Copyrights and trademarks of each framework belong to their original authors.
This skill is independently designed and implemented with reference to these
methods.
