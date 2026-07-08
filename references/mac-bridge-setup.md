# Mac Bridge Setup & Operations Runbook

Mac 常駐 Claude Code を Discord DM の応答者にする仕組み（v2.6）のセットアップ・運用・ロールバック手順。

## アーキテクチャ

```
Discord DM（オーナーのみ allowlist）
  │ Gateway WebSocket
  ├─ Lightsail bun/server.ts … dmPolicy=disabled → 全 drop（新聞係として存続）
  └─ Mac bun/server.ts ────→ Mac 常駐 claude セッション（唯一の --channels）
                               ├ tmux -L claude-bridge（専用 socket）
                               ├ launchd: com.fideguch.claude-bridge (RunAtLoad)
                               ├ launchd: com.fideguch.claude-bridge-health (120s)
                               ├ cwd ~/bochi-runtime/（CLAUDE.md = deploy/mac-claude.md）
                               └ 権限: bypassPermissions + hard-deny guard（2層）
```

- **応答者の決定**: `--channels plugin:discord` 付きで起動したセッションだけがメッセージを受け取る。Lightsail は access.json の `dmPolicy:"disabled"`（メッセージ毎に再読込・即時反映）で受信を止めている。
- **新聞**: 生成 = Lightsail の RemoteTrigger cron、配信 = Lightsail crontab の `send-newspaper-to-discord.py`（REST 直叩き・claude 非依存）→ **カットオーバーの影響なし**。

## セットアップ

```bash
cd ~/bochi
bash deploy/mac/setup-bridge.sh            # dry-run で内容確認
bash deploy/mac/setup-bridge.sh --apply    # インストール + launchd 登録
bash ~/bochi-runtime/bin/bridge-start.sh start
bash tests/mac-bridge-e2e.sh --with-lightsail
```

`setup-bridge.sh --apply` がやること:

1. `~/bochi-runtime/` を構築（CLAUDE.md 444 / settings.json 444 / bin/* 555）
2. LaunchAgents 2 本を plutil-lint → bootstrap
3. `bridge-start.sh start` は初回に bochi-data を `~/bochi-data`（実体）へ移設し `~/.claude/bochi-data` を symlink 化する（`~/.claude/` 配下への Write は sensitive-file ブロックされるため）

## 権限モデル（2 層・v2.7）

| 層 | 対象 | 実装 |
|---|---|---|
| auto-allow | guard が止めないものはすべて即実行（ホーム Read / bochi-data・workspace・tmp への Write / WebSearch / 全ドメイン WebFetch / Discord・Notion ツール / 任意 Bash など） | `--permission-mode bypassPermissions` 起動フラグ（＋ settings.allow は bypass 喪失時のグレースフルデグレード用に維持） |
| hard-deny | 従来の秘匿ストア（.ssh/.aws/gcloud/gh/docker/kube/gnupg/Keychains/.env/credentials/transcripts）・enforcement ファイル・tmux send-keys/attach に加え、v2.7 で **egress バイナリ（curl/wget/nc）**・**.jsonl へのシェル書込**・**~/.claude.json** を追加 | permissions.deny + `bin/bridge-guard.sh`（fail-close, exit 2）— deny ルールと PreToolUse hook は bypass 下でも強制される |

- **フラグは `bridge-start.sh` が生成する launcher に付与**する（settings の defaultMode ではない）。したがって同じ RUNTIME で走る `generate-newspaper.sh` の headless `claude -p`（allow ルールベースで動作）には影響しない。
- v2.6 では relay 方式だったが、承認待ちで会話が止まる実運用問題（2026-07-08 オーナー報告）により v2.7 で `--dangerously-skip-permissions` ではなく `bypassPermissions` に転換した。deny ルールと PreToolUse hook が bypass 下でも強制されることは公式ドキュメント＋実機スパイク（claude 2.1.204）で確認済み。検討した代替案（PreToolUse hook による選択的自動承認）は、未知ドメイン WebFetch が引き続きプロンプト化して Mode 1（URL 共有→深掘り）を止めるため不採用。
- 権限プロンプトは bypass 下では本来出ない。万一 pane に表示された場合は health が anomaly 検知として扱い（フラグ未反映の可能性）、10 分以上続けば REST 直叩きで通知 DM を送る（fail-safe。自動承認はしない）。

## 運用

| 操作 | コマンド |
|---|---|
| 状態確認 | `bash ~/bochi-runtime/bin/bridge-start.sh status` / `bash deploy/mac/setup-bridge.sh --status` |
| 手動再起動 | `bash ~/bochi-runtime/bin/bridge-start.sh restart manual` |
| 画面を見る | `tmux -L claude-bridge attach`（デタッチ: Ctrl-b d） |
| E2E 検証 | `bash tests/mac-bridge-e2e.sh --with-lightsail --with-headless` |
| 停止 | `bash ~/bochi-runtime/bin/bridge-start.sh stop` |
| アンインストール | `bash deploy/mac/setup-bridge.sh --uninstall` |
| 設定更新の反映 | リポジトリ編集 → `setup-bridge.sh --apply` → `bridge-start.sh restart` |

- watchdog ログ: `~/bochi-data/errors/bridge-watchdog.jsonl` / launchd ログ: `~/bochi-runtime/logs/`
- 毎日 04:30-04:59 JST、アイドル時のみ鮮度リスタート（再起動後は bootstrap プロンプトが未応答メッセージを自動回収）

## カットオーバー / ロールバック（順序が重要）

**Mac へ切替（手順）**:

1. Mac ブリッジ起動 + E2E PASS（この間は二重応答があり得る・数分）
2. v2.7 検証: (a) ゾーン外の生 Bash が承認なしで即実行されること、(b) guard ブロック（例: `tmux ls`）が bypass 下でも exit 2 で発火すること — これが Bash 経由の秘匿読取遮断が生きている証明になる。発火しなければロールバックする
3. **Lightsail の pull フックに seen.jsonl の exclude + union-merge を適用**（ssh。Mac 側 hooks と同一の変更。適用前に切り替えると Lightsail の pull が seen.jsonl を破壊的上書きする）
4. Lightsail: `dmPolicy` を `disabled` に変更（**allowFrom は新聞配信の宛先なので絶対に消さない**）

```bash
ssh -i ~/.ssh/lightsail-bochi.pem ubuntu@54.249.49.69 \
  'chmod 644 ~/.claude/channels/discord/access.json && \
   python3 -c "import json;p=\"/home/ubuntu/.claude/channels/discord/access.json\";a=json.load(open(p));a[\"dmPolicy\"]=\"disabled\";json.dump(a,open(p,\"w\"),indent=2)"'
```

**Lightsail へ戻す（ロールバック）**:

1. **先に** Mac を止める: `bash ~/bochi-runtime/bin/bridge-start.sh stop` + `bash deploy/mac/setup-bridge.sh --uninstall`（health の自動復活を止める）
2. Lightsail: 上記コマンドの `"disabled"` を `"allowlist"` にして実行（即時反映・再起動不要）

## 既知の制約

| 制約 | 内容 |
|---|---|
| バッテリー駆動 | caffeinate -s は AC 電源時のみ有効。電源断でバッテリー駆動になるとスリープしブリッジ断（AC 復帰で自動復旧） |
| 再起動後 | LaunchAgent はログイン後に起動。FileVault 環境では再起動後に一度ログインが必要 |
| CLI 自動更新 | claude はほぼ日次で自動更新される。起動文言変更等は health が WARN+通知に縮退（再起動ループはしない） |
| See more レース | （v2.6 relay 時代の事象・v2.7 で relay 廃止につき歴史的記録）permission relay の「See more」は複数 gateway 接続の ack レースで "Details no longer available" になることがあった（Allow/Deny 自体は機能した） |
| 反応学習の休止 | 新聞へのリアクションによるカテゴリ weight 学習は Lightsail 応答停止に伴い休止中（follow-up: Mac 側 Mode 2 実装時に復活） |
| Lightsail ジョブ凍結 | Lightsail 担当の `cache/`（Google 予定・メール）と `reflections/` が **2026-04-14 から更新停止**（2026-07-08 発見）。Mode 6 はキャッシュが古い旨を正直に報告して縮退する。恒久対応は newspaper と同様に **Google 同期の Mac launchd 移行**（未着手・オーナー判断待ち） |
| 会話中のメッセージ | 処理中に届いた次のメッセージは現ターン終了後に処理される（単一セッション） |
| サブスク上限 | 上限到達時は応答不能。health が pane の limit 文言を検知して通知 DM を送る |

## セキュリティ設計の根拠

- **同一トークン複数 gateway**: DM は全接続にファンアウトするが、`--channels` セッションだけが応答する（数ヶ月の共存実績）。ローカルの `--channels` プロセスは常に 1 個（e2e が検査）。
- **injection 脅威モデル**: 攻撃文は DM ではなく WebFetch/WebSearch の取得内容から来る。対策は (1) 秘匿パスの Read/Bash/Grep 三重遮断（読めなければ exfil できない）、(2) enforcement ファイルの自己改変禁止、(3) pairing/allowlist 変更要求の一律拒否、(4) 主要 egress バイナリ（curl/wget/nc）の guard 遮断。
- **WebFetch 全ドメイン自動実行（受容リスク・v2.7）**: v2.7 では WebFetch は全ドメイン即実行になった（ACCEPTED RISK）。根拠: DM はオーナーのみ受信 / 秘匿パスの直接読取は三重遮断（難読化インタープリタ読取の残余は instruction 層で防ぐ受容リスク） / 主要 egress バイナリは guard で遮断（**網羅的ではない** — インタープリタや `/dev/tcp` は残るが、一次防衛線はあくまで読取遮断） / 取得コンテンツ内 instruction への非追従（instruction 層）/ 未知ドメイン遮断は Mode 1（URL 共有→深掘り）を殺し本修正の目的と矛盾するため採らない。残余リスク: 非秘匿の bochi-data メモを細工 URL 経由で exfil される可能性 — これは受容し、instruction 層で防ぐ。
- **guard は fail-close**: 不正入力・内部エラーは exit 2（ブロック）に倒れる。
