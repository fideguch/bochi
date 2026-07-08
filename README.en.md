# bochi v2.7 — PM Companion

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
                             ├ 2-layer perms (v2.7): auto-allow (bypassPermissions) / hard-deny (guard + settings.deny)
                             └ recalls ~/.claude/projects/*/memory across projects
```

- **The Mac responds**: only the session launched with `--channels plugin:discord`
  receives messages. Lightsail is silenced via `access.json` `dmPolicy:"disabled"`
  (re-read per message; a 1-key, reversible cutover).
- **Newspaper is generated and delivered on the Mac**: launchd at 06:20 JST
  (generate) and 08:00 JST (deliver).
- Full setup / ops / rollback: **`references/mac-bridge-setup.md`**.

## What's New in v2.7 (2026-07-08) — Conversations That Never Stall

- **Permission relay removed → bypassPermissions**: the bridge Claude launches
  with `--permission-mode bypassPermissions` (added to the `bridge-start.sh`-
  generated launcher, NOT settings `defaultMode`). Permission prompts no longer
  exist, fixing the real-world stall where Notion MCP / raw Bash approvals froze
  the conversation (owner report 2026-07-08). The model goes from 3 layers
  (allow / ask-relay / hard-deny) to **2 layers (auto-allow / hard-deny)**.
- **Hard-deny survives bypass**: settings `permissions.deny` and the bridge-guard
  PreToolUse hook are enforced even in bypass mode (confirmed by official docs +
  a live spike on claude 2.1.204: no first-run dialog, deny-listed Read blocked,
  previously-ask-gated raw Bash runs instantly).
- **Guard hardened (compensating for the removed ask layer)**: three new hard-deny
  controls — egress binaries (curl/wget/nc), shell writes to `.jsonl`, and
  self-modification of the global `~/.claude.json`. The egress block is NOT
  exhaustive (interpreters and `/dev/tcp` remain); the primary confidentiality
  boundary is still the secret-path read-deny.
- **Accepted risk**: WebFetch now auto-runs for all domains (ACCEPTED RISK) —
  DMs are owner-only, secret paths are triple read-denied, and the instruction
  layer mitigates fetched-content injection.

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
  read-only wrappers (`pc-status` / `repo-status`) — under v2.7 bypass mode raw
  `ps|grep` also runs without prompting, but the wrappers are recommended for
  faster, curated, stable output (`tmux ls` stays hard-denied by the guard).
- **Non-interference guardrail**: never `send-keys`/`attach` into other projects'
  Claude sessions; heavy work is delegated to headless `claude -p`/`--bg`.
- **Newspaper revival**: the Lightsail RemoteTrigger generation cron had stopped
  (delivery was resending the same stale issue daily). Generation and delivery
  moved to Mac launchd; delivery sends only *today's* issue (no stale fallback).
- **Data layer**: bochi-data's real path moved to `~/bochi-data` (writes under
  `~/.claude/` are blocked as sensitive files); `~/.claude/bochi-data` is a
  symlink. `seen.jsonl` is union-merge synced on both sides.
- Verification: `tests/mac-bridge-e2e.sh` (50 checks) + `.evals/` (failure
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

## Permission Model (2 layers, v2.7)

| Layer | Scope | Behavior |
|-------|-------|----------|
| auto-allow | everything the guard doesn't stop (home reads / writes to bochi-data & workspace / WebSearch / all-domain WebFetch / Discord & Notion tools / arbitrary Bash) | no prompt (`bypassPermissions` launch flag) |
| hard-deny | secret stores (.ssh/.aws/gh/gcloud/tokens) / enforcement self-mod / tmux interference / **v2.7 additions: egress binaries (curl/wget/nc), .jsonl shell writes, ~/.claude.json** | not approvable (fail-close guard + settings.deny, enforced under bypass) |

> The flag lives on the `bridge-start.sh`-generated launcher (not settings
> `defaultMode`), so the same-runtime headless `claude -p` (newspaper generation,
> allow-rule based) is unaffected.

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
