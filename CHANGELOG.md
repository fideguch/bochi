# Changelog

All notable changes to bochi are documented here.

## v2.7.3 (2026-07-28) — Sleep-Loss Recovery（スリープ中に失われた受信の回収）

### Why

7/28 12:04・12:05 のオーナー DM 2 通に 👀 も返信もゼロ。直前の応答は 7/26 11:42 で、
**57 時間の沈黙**。その間 `bridge-health.sh` は `healthy-idle` を **815 回連続**で報告していた。

### Root Cause（実測で確定）

1. **ホストが寝ている**: ブリッジはノート PC 上で動作する。clamshell（蓋閉じ）スリープは
   `caffeinate` では防げず、一度入ると Sleep Service / Maintenance Sleep のサイクルに移行して
   DarkWake は 2〜11 秒しかない。launchd の実績は **7,099 回 / 期待 15,885 回 = 44.7%**
   （22 日間・StartInterval 120s）。
2. **スリープ中の受信は永久に失われる**: プロセス凍結中に届いた MESSAGE_CREATE は処理されず、
   Discord は事後にゲートウェイイベントを再送しない。該当 2 通に 👀（`handleInbound` 内で
   Claude へ渡す**前**に付く ack）が無いことが証拠。着弾時刻 12:04:52 JST は `pmset -g log` 上の
   Sleep 区間（11:57:54 開始・997 秒）に完全に含まれる。
3. **ゲートウェイは無罪**: 起床後、シャードのソケットへ TYPING_START を 5 発注入すると rx **+172B**
   （アイドル 20 秒では +0B）。WebSocket は正常にイベントを配信していた。プラグインの不具合ではない。
4. **回収の口が無い**: 未応答を拾う `fetch_messages` 復帰プロンプトは `bridge-start.sh` の起動時に
   しか存在しない。watchdog は全生存判定（tmux / claude / Phase 1.5 チャンネル子プロセス）を
   通過するため再起動もしない。無音は仕様上「健全」と定義されていた（`idle alone never restarts`）。

### Fixed

- **Phase 0（wake-gap 検知）を `bridge-health.sh` に追加**: 自前の tick ファイルとの差分が 300s
  （120s 間隔の 2.5 倍）以上なら「ホストが寝ていた」と判定し、キャッチアップをキューに積む。
  キューは変数ではなく**ファイル** — モーダル / 権限 / 上限の各分岐が早期 exit するため、
  アイドルプロンプトを持つ実行まで gap を生存させる必要がある。
- **Phase 0b（配信）**: 上記の全分岐より**後ろ**に配置。そこへ到達した時点でキー入力待ちが
  無いことが保証され、send-keys がダイアログに吸われない。`bridge-start.sh` と同じ復帰プロンプトを
  **再起動せずに**注入するので、会話コンテキストは温存される。
- **二重発火防止**: `try_restart` 成功時にキューを破棄（起動時注入がキャッチアップを兼ねるため）。
  さらに直近 10 分以内に実施済みならスキップし、DarkWake の連打で多重注入しない。

### Verified

- `bash -n` / `shellcheck -S warning` ともにクリーン。
- 初回実行（tick 未作成）でキャッチアップが発火しないことを確認 = 導入時の誤注入なし。
- 20 分前の tick を書いてスリープ復帰を再現 → `wake_gap` / `wake_catchup` を watchdog jsonl に記録、
  ペインへ注入、Claude が `fetch_messages` を実行し、**12:01:44Z に未応答 2 通への返信到達を
  Discord API で確認**。

### Known / Not Fixed

- 新聞パイプラインは同根の別問題として**未修正**。7/26 の生成が `claude -p exit=1` で無言失敗し
  （`notify-owner` が呼ばれない）、さらに「06:20 生成 → 08:00 配信」という**時刻結合**が
  スリープ由来の launchd 遅延に耐えられない（gen / deliver とも 21 日間で 13 回 = 62% しか発火せず、
  7/28 は生成完了が 09:52 で配信ウィンドウを 1 時間 52 分超過）。イベント結合への変更が必要。
- ホストのスリープ自体は放置（`pmset disablesleep` は未適用）。取りこぼしは Phase 0/0b で
  吸収する方針のため、返信はスリープ時間ぶん遅延する。

## v2.7.2 (2026-07-15) — Channel-Less Zombie Fix (MCP connect timeout + health blind spot)

### Why

7/15 09:06〜09:26 のオーナー DM 4 通に 👀 だけ付いて返信ゼロ（オーナー報告）。
ブリッジ本体は「稼働中・healthy-idle」を報告し続けており、無応答が 8 時間検知されなかった。

### Root Cause（MCP ログ・プロセスツリー実測で確定）

1. **接続タイムアウト**: 04:30 の daily freshness restart 時、discord プラグイン MCP サーバの
   起動接続が claude デフォルトの 30s を超過し失敗（`mcp-logs-plugin-discord-discord/`:
   `connection timed out after 30000ms`）。プラグインの start script が **接続のたびに
   `bun install`（npm registry アクセス）を実行**するため、成功日ですら 28.4s と限界だった
   （04:30 は 7 個の MCP サーバ同時起動と重なる最悪条件）。
2. **チャンネル無しゾンビ**: claude は MCP 接続失敗を再試行しない。argv に `--channels` は
   残るため health の Phase 1 は素通りし、pane はアイドルプロンプト表示 = 「healthy-idle」を
   95 回連続報告（実際は fetch_messages ツール自体が不在）。
3. **👀 の正体**: 7/11 起動の残骸 gateway（別開発セッションの discord MCP 子プロセス）が
   同一 token で受信 ack だけ付けていた。v2.7.1 のスコープ限定より前に起動したセッション由来。

### Fixed

- **接続パスから bun install を排除**: `setup-bridge.sh` に `patch_discord_plugin()` を追加。
  deps を setup 時に事前インストールし、plugin cache の package.json `start` を
  `bun server.ts` に書換（冪等・`.bak-pre-fast-start` 保持）。接続実測 28.4s → **2.1s**。
- **MCP_TIMEOUT=120000**: `bridge-start.sh` の launcher 生成に追加。プラグイン更新で
  cache が再生成され install が復活しても最悪ケースを吸収。
- **health Phase 1.5（盲点の恒久解消）**: bridge claude の子プロセスに discord プラグイン
  サーバが居るかを毎 2 分検査。2 回連続不在（≈4 分）で自動再起動（既存の 5 回/h backoff・
  通知に接続）。以後どんな理由でチャンネルが落ちても放置は最大 ≈4 分。
- **残骸 gateway 駆除**: 7/11 起動の stale gateway（bun ×2）を停止。

### Verified

- 再起動後: `Starting connection with timeout of 120000ms` → `Successfully connected in 2109ms`
  → `Channel notifications registered` → bootstrap が未応答 DM を検出し `reply` ×3 送信成功（E2E）。
- 新 health 手動実行: Phase 1.5 通過・`healthy` exit 0。

## v2.7.1 (2026-07-08) — Discord Reply Stability Fix (plugin outbound-gate bug)

### Why

ブリッジの reply / edit_message が間欠的に `channel is not allowlisted` で失敗
（bochi-data/errors/ 2026-07-08 02:40 / 05:15 UTC。fetch_messages は成功するのに送信だけ落ちる）。

### Root Cause（discord.js 14.25.1 実ソース照合済み）

discord プラグイン v0.0.4 の送信ゲート `fetchAllowedChannel` は DM を
`access.allowFrom.includes(ch.recipientId)` で判定するが、キャッシュ済み DMChannel の
`recipientId` は **bot 自身の送信で生成されたチャンネルや recipients 欠落の REST 応答では
undefined** になる（discord.js は `recipients` を含む payload でしか recipientId を設定せず、
受信ユーザーメッセージだけがキャッシュを修復する）。このため「受信直後の返信は通るが、
proactive な送信・edit は落ちる」という間欠障害になる。access.json は無関係（破損・外部書換なし）。

### Fixed

- **上流修正を plugin cache に同期**: marketplace 側 server.ts（2026-07-08 12:30 更新、
  バージョン 0.0.4 のままのステルス修正）に同一バグの修正（`dmChannelUsers` Map による
  inbound author フォールバック）が入っていたため、
  `~/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/server.ts` に同期し
  ブリッジを `bridge-start.sh restart manual` で再起動。バージョン据え置きのため
  プラグインマネージャは cache を自動更新しない = 手動同期が唯一の適用手段だった。
  旧版は `server.ts.bak-pre-recipientid-fix` として保持。
- **残骸 gateway 接続の掃除**: 同一 token の gateway 接続が 10 本あった（6/28〜の放置
  ターミナルセッション由来）。設計上は無害（`--channels` セッションのみ応答）だが、
  ブリッジと現用セッション以外の discord MCP 子プロセスを停止し 2 本に削減。

### Added

- **discord プラグインのスコープ限定（gateway 接続の再蓄積防止）**: プラグイン有効 =
  全セッションで MCP サーバ（= gateway 接続）が自動起動する仕様のため、user スコープ
  （`~/.claude/settings.json` → dotfiles 実体）で `discord@claude-plugins-official: false`、
  `deploy/mac/templates/bridge-settings.json`（project スコープ、優先）で `true` に設定。
  以後 gateway 接続は `~/bochi-runtime` 発のセッションのみ。実機検証済み
  （`claude plugin list`: runtime=enabled / 他=disabled）。
  **運用上の注意**: `/discord:access` 等 discord プラグイン操作は今後 `~/bochi-runtime`
  で claude を起動して行うこと。

## v2.7 (2026-07-08) — Conversation-Stall Fix via bypassPermissions

### Why

Mac 常駐ブリッジ（v2.6）は権限プロンプト（Notion MCP・生 Bash 等）で会話が停止していた。
オーナーは応答中に Discord の 🔐 承認ボタンを見張れないため、承認待ちで会話がそのまま死ぬ
実運用問題（2026-07-08 オーナー報告）。

### Changed

- **permission relay を会話パスから撤去**: ブリッジ Claude は `bridge-start.sh` が生成する
  launcher で `--permission-mode bypassPermissions` 付き起動する（settings の defaultMode
  ではない）。権限モデルを 3 層（allow / ask-relay / hard-deny）→ **2 層（auto-allow /
  hard-deny）** に転換。同じ RUNTIME の headless `claude -p`（新聞生成）は allow ルール
  ベースのため影響なし。
- **検証済みの安全性**: deny ルールと PreToolUse hook は bypass モードでも強制されることを
  公式ドキュメント + 実機スパイク（claude 2.1.204）で確認（初回受諾ダイアログは出ず、
  deny 対象 Read はブロック、旧 ask 対象の生 Bash は即実行）。

### Added

- **guard 強化（撤去した ask 層の代替 3 制御）** (`deploy/mac/bridge-guard.py`):
  egress バイナリ（curl/wget/nc/ncat/netcat）・`.jsonl` へのシェル書込（`>>`/`tee`/`> *.jsonl`）・
  グローバル `~/.claude.json` 自己改変を hard-deny に追加。egress ブロックは網羅的ではない
  （インタープリタ・`/dev/tcp` は残る — 一次防衛線は秘匿パスの読取遮断）。
- `bridge-settings.json` に `mcp__claude_ai_Notion` allow（bypass 下では無効・フラグ喪失時の
  グレースフルデグレード用）と `~/.claude.json` の Write/Edit deny を追加。
- `tests/mac-bridge-e2e.sh` に guard ケース 10 件追加（egress / .jsonl / ~/.claude.json。guard
  バッテリー計 35 ケース、e2e 全体 約 50 チェック）。headless probe を
  `--permission-mode bypassPermissions` 付きに更新。
- ドキュメント・evals を v2.7 に更新（`deploy/mac-claude.md`, `references/*`, `README(.en).md`,
  `.evals/` specs + dataset）。

## v2.6.1 (2026-07-06) — Newspaper Revival + Conversation Fixes

### Fixed

- **新聞が毎日同じ号を再送する不具合**: Lightsail の RemoteTrigger 生成 cron が
  機能停止（最新号が 2026-06-06 で固定）していたのに、配信スクリプトが「今日の号が
  無ければ最新 mtime の号」にフォールバックしていたため、同じ古い号を毎朝再送していた。
  `send-newspaper-to-discord.py` の stale フォールバックを撤廃し、今日の号（JST）が
  無ければ**配信をスキップ**するように変更（`NoFreshNewspaper`）。
- **会話が権限プロンプトで停止する不具合**: 「稼働中のセッション教えて」等で
  `ps aux | grep` のようなパイプ付きコマンドを打つと allowlist に一致せず権限
  プロンプトで止まっていた。`deploy/mac-claude.md` を HARD-GATE 化し、状態確認は
  必ず `pc-status`/`repo-status` ラッパー（単一 allowlist コマンド）を使うよう明記。
- **利用上限モーダルを権限待ちと誤認**: アカウントの利用上限モーダル（"Stop and wait
  for limit to reset" 等）が "Esc to cancel" を含むため権限プロンプト検出に誤ヒットし、
  放置＋誤った「10分権限待ち」通知を出していた。上限モーダルを先に検出して option 1
  （待機・リセット後自動再開）を自動選択し、オーナーに1回だけ正しく通知するよう修正。
- **死んだ起動文字列**: Lightsail の `bochi-health-check.sh` / `restart-bot.sh` が
  claude <2.1.195 の旧文言 `Listening for channel messages` に依存し、CLI 更新で
  再起動ループを起こす潜在バグ。新旧両文言（`Listening for (channel messages|messages from)`）
  に対応。

### Added

- **Mac 側の新聞生成・配信** (`deploy/mac/generate-newspaper.sh`,
  `deploy/mac/deliver-newspaper.sh` + launchd `com.fideguch.bochi-newspaper-gen`
  06:20 JST / `-deliver` 08:00 JST): 生成は `claude -p` が Mode 2 を実行して
  今日の号を出力（生成失敗時は部分ファイルを残さず配信スキップ）。配信は今日の号のみ。
- Lightsail の配信 cron を無効化（Mac へ移管、二重配信防止）。

### Changed

- README.md / README.en.md を v2.6 の実態（Mac ブリッジ応答者・新聞パイプライン・
  データ層実パス・権限3層・フォルダ構成）に全面刷新。

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
