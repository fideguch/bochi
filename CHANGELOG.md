# Changelog

All notable changes to bochi are documented here.

## v2.6 (2026-07-06) — Mac-Resident Claude Bridge

### Added

- **Mac 常駐ブリッジ一式** (`deploy/mac/`): `bridge-start.sh`（tmux -L claude-bridge、
  mkdir アトミックロック、claude ≥2.1.195 の起動文言 `Listening for messages from` 対応、
  再起動後の未応答メッセージ回収 bootstrap 注入）、`bridge-health.sh`（permission プロンプトは
  自動承認せず健全待機 + 10 分で通知、rate-limit/parse-fail 検知通知、5 回/時 backoff、
  04:30 JST アイドル時のみ日次リスタート）、`setup-bridge.sh`（dry-run 既定の冪等インストーラ）。
- **Runtime 定義** (`deploy/mac-claude.md`): Claude 人格・全プロジェクト記憶リコール・
  不干渉ガードレール（他 tmux への send-keys 禁止・重作業は headless 委譲）・
  Discord UX（禁止絵文字/再起動非露出/2000 字制限は CI と同一基準）・書込パス HARD-GATE。
- **権限 3 層モデル** (`deploy/mac/templates/bridge-settings.json` + `bridge-guard.sh`):
  allow（ホーム読取 + 限定書込 + 最小 Bash）/ ask（permission relay → Discord 🔐 ボタン）/
  hard-deny（秘匿ストア・enforcement 自己改変・tmux 干渉、fail-close）。
  bypass permissions と tmux-auto-approve は不採用。
- **読み取り専用ラッパー** (`deploy/mac/bin/pc-status`, `repo-status`): git/tmux の
  LOLBIN リスク（`-c core.pager` 等）を固定引数ラッパーで遮断。
- **LaunchAgents** (`com.fideguch.claude-bridge` RunAtLoad / `-health` 120s):
  PATH 明示（.local/bin, .bun/bin, nodebrew, homebrew）、CLAUDE_BRIDGE=1、
  AbandonProcessGroup、ProcessType Interactive。
- **E2E バッテリー** (`tests/mac-bridge-e2e.sh`): guard 3 分類 + fail-close、
  単一応答者不変条件（pgrep 自己マッチ対策済み）、launchd/tmux/pane/API、
  Lightsail dmPolicy + allowFrom 保全チェック。
- **specs-evals**: `.evals/` 初期化、失敗タクソノミー T1-T6
  (`error-analysis/2026-07-06-mac-bridge.md`)、eval specs 2 本 + golden dataset 8 件。
- **Runbook** (`references/mac-bridge-setup.md`): カットオーバー/ロールバック順序、
  新聞配信と access.json の結合注意、既知制約。

### Changed

- **応答者切替**: Lightsail access.json `dmPolicy=disabled`（ホットリロード・即時可逆）。
  Lightsail は新聞生成/配信係として存続。
- **bochi-data 実体移設**: `~/.claude/bochi-data` → `~/bochi-data` + symlink
  （非 bypass セッションの `~/.claude/` Write が sensitive-file ブロックされるため。実測 2026-07-06）。
- **seen.jsonl 同期**: Darwin push 除外を解除し両側 push + pull 時 union-merge に変更
  （応答者交代による split-brain 防止。hooks: bochi-s3-push/safety-push/pull×3）。
- **CI** (`quality.yml`): `deploy/mac/` の bash -n / plist / settings JSON 検証を追加、
  `workflow_dispatch` トリガー追加。`discord-e2e.sh` CH-01（ゆ語尾率）は
  ペルソナ交代に伴い informational WARN 化（CH-02/EH-02/UX-01 は存置し bridge 側仕様で遵守）。
- **グローバル hooks**: `claude-stop-notify.sh`（深夜の通知音防止）と
  `pm-pipeline-guard.js` に `CLAUDE_BRIDGE=1` early-exit を追加（my_dotfiles 側）。

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
