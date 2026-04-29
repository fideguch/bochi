# Changelog

All notable changes to bochi are documented here.

## v2.5 (2026-04-30) — Multimedia Research Expansion

### Added

- **YouTube/X real-time sources in Mode 1 Phase C** (`references/realtime-access-methods.md`):
  YouTube channel `@handle` → channelId → RSS, X via `nitter.net/<user>/rss`,
  with verified-channel allowlist (`references/learned-channels.md`) mirroring
  the `learned-sources.md` curation pattern.
- **Format-specific E-E-A-T caps for video/SNS** (`references/quality-criteria.md`):
  single tweet 24/40, thread 32/40, video+transcript 36/40, article uncapped;
  freshness bonus (+2/0/−2 by hours since publish).
- **Phase D check #6** (`references/critique-checklist.md`): Video/SNS hygiene —
  written-source pairing required, ISO publish timestamp, transcript citation.
- **Cache-first transcript pipeline** (`scripts/fetch_yt_transcript.py`): solves
  the documented YouTube cloud-IP block (jdepoix/youtube-transcript-api#79).
  Tier 1 reads `~/bochi-data/transcripts/<id>.txt`; Tier 2 fetches on
  residential IP and writes the cache; Tier 3 emits an operator instruction
  on cache miss. Cache syncs to all bot environments via the existing
  bochi-data → S3 pipeline.
- **Sub-agent summarisation pattern**: any video > 3 min must be summarised by
  a `general-purpose` sub-agent before being used as a Phase C signal —
  saves main context budget, treats video as "why is this trending" signal
  rather than numerical ground truth (adopted from pokemon-champions skill).
- **Cloudflare Worker proxy stub** (`worker/transcript-proxy/`): inactive in
  the current YouTube anti-bot environment (Innertube ANDROID/WEB/TVHTML5
  all rejected from Cloudflare edge as of 2026-04). Kept in tree because
  combining it with a residential proxy or a third-party API revives it
  with no code change. Operator env vars `BOCHI_YT_PROXY_URL` +
  `BOCHI_YT_PROXY_TOKEN` enable Tier 2c when ready.

### Changed

- **`references/idea-expansion-spec.md`** Phase C Action step now branches
  into 2a WebSearch / 2b Context7 / 2c YouTube+X (signal-triggered).
- **`references/trusted-domains.md`** adds curated YouTube + X allowlists.
- **`references/research-strategy.md`** adds YouTube/X cross-domain strategy
  with explicit "when NOT to bother" guidance.
- **`references/output-template.md`** documents how to record video/SNS
  freshness and the `preliminary` tag for SNS-only conclusions.

### Fixed

- **`deploy/setup-cron.sh`**: removed legacy `--trigger` cron entries
  (the flag does not exist in Claude Code CLI; `bochi-daily` /
  `bochi-prefetch` are managed via RemoteTrigger API now). Idempotent
  rebuild strategy. S3 sync cron entries added. @reboot path auto-fix.
- **`deploy/bochi-health-check.sh`**: pass shell variables to embedded
  Python via `os.environ` (no quoting bugs); recognise the
  "Listening for channel messages" + prompt state as healthy idle to
  prevent false unresponsive detection.
- **`deploy/bochi-tmux-start.sh`**: `clean_stale_lock()` resets the lock
  inode atomically via `mv` (releases stale flock holders);
  flock timeout reduced 120s → 30s.

### Operations

- Daily Discord newspaper delivery cron (`deploy/send-newspaper-to-discord.py`)
  scheduled `0 23 * * *` UTC = 8:00 JST. Mobile-friendly card format,
  embed-suppressed URLs, 1900-char chunks per `access.json textChunkLimit`.

## v2.4 (2026-03-28) — Edge Case Completeness + DRY

### Added

- Edge Cases sections for all 14 spec files (9 new: companion, discord-ux, error-reporting, memory, mobile-first, pdca, response-speed, self-healing, skill-tracking)
- Session Continuity Protocol in lightsail-claude.md (6h restart recovery with fetch_messages, profile preload, open memo surfacing)
- EC-01/EC-02 edge case scenario tests (archive dir missing, orphaned index entry)

### Changed

- SKILL.md: Removed duplicate "Mode 2-7: Spec References" table (DRY, ~329 to ~313 lines)
- RS-03 scenario test: "Conclusion first" differentiated to "Progressive timing"
- CI threshold: 47 → 49 tests
- Scenario test suite: 47 → 49 tests

## v2.3 (2026-03-28) — Thinking Hub + Quality

### Added

- Product Vision section in SKILL.md
- `references/idea-expansion-spec.md` (Mode 1 Phases A-G extracted)
- Discord Proactive Save rules in Intake Gate
- Discord-to-S3-to-CLI feedback loop in companion-spec
- Edge Cases for socratic-levels, expansion-framework, output-template
- JSONL Recovery procedure in self-healing-spec
- Mode 4/5 scenario tests (7 new, total 47)
- CI/CD: `.github/workflows/quality.yml` + `.markdownlint.json`
- `CONTRIBUTING.md`, `CHANGELOG.md`, `examples/mode-1-walkthrough.md`
- Deployment Checklist in lightsail-claude.md

### Changed

- SKILL.md: Mode 1 inlined spec replaced with reference link (DRY)
- SKILL.md: Discord Output Rules simplified to reference links (DRY)
- SKILL.md: Feedback Signal table replaced with reference link (DRY)
- SKILL.md: ~444 lines reduced to ~329 lines

## v2.2 (2026-03-28) — Lightsail + Mode 6/7

### Added

- `deploy/lightsail-claude.md` for server-specific CLAUDE.md
- Mode 6: Google Brief (`references/google-brief-spec.md`)
- Mode 7: PM Tools Bridge (`references/pm-tools-bridge-spec.md`)
- 40 scenario tests in `references/scenario-tests.md`

### Fixed

- E-E-A-T boundary clarification (28/40 threshold)
- Critique specificity improvements
- feedback-log and learned-sources format definitions
- Mobile-first, response-speed, discord-ux character count alignment

## v2.1 (2026-03-28) — Speed + Signals

### Added

- `references/response-speed-spec.md` (7 speed techniques)
- `references/discord-ux-spec.md` (section splitting, reactions, feedback)
- Seen-tracking cache (`seen.jsonl`)

### Changed

- Discord output: character-cut replaced with section-based splitting

## v2.0 (2026-03-27) — Initial Release

### Added

- 5 modes: Idea, Newspaper, Casual Chat, Memory, Companion
- SCAMPER expansion framework
- ReAct research loop with E-E-A-T scoring
- Phase D critique with HARD-GATE
- bochi-data persistence layer with index.jsonl
- Owner-only learning protocol
- Pipeline position: bochi -> brainstorming handoff
