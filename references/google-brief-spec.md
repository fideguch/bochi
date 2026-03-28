# Mode 6: Google Brief Spec

## Overview

Google Calendar・Gmailの情報をキャッシュ経由で即時配信するゆ。
gog CLI → cache/*.md → ユーザーへ即座に表示。

## Trigger

「予定」「カレンダー」「メール」「今日の予定」「メール確認」「schedule」「inbox」

## Flow

### Background Sync (Cron: 06,09,12,15,18,21 JST)

```
[1] gog cal events --from today --to +3days --json
    → Format into cache/calendar.md (date sections, up to 5 events/day)
[2] gog gmail search 'newer_than:3h -category:promotions -category:social -category:updates' --json
    → Dedupe by sender → sort by importance → top 10
    → Save to cache/gmail.md
[3] Update cache/meta.json: google_synced_at = now()
```

### Delivery Pass (ユーザー trigger)

```
[Trigger: "予定" / "メール" etc.]
  |
  [1] Read cache/meta.json → google_synced_at
      |
      +-- Within 3h → Serve cache/calendar.md and/or cache/gmail.md immediately
      +-- Stale → Stale-while-revalidate:
      |   Serve cached data immediately + background gog re-run
      +-- Missing → On-demand gog execution (see Edge Cases)
  |
  [2] Format output (see Output Format below)
```

## Output Format

### Calendar

```
今日から3日の予定ゆ 💫

## 3/28 (金)
1. 10:00-11:00 — **チームスタンドアップ**
2. 14:00-15:00 — **プロダクトレビュー**

## 3/29 (土)
予定なしゆ！

## 3/30 (日)
1. 13:00-14:00 — **ランチミーティング**
```

### Gmail

```
最近のメールゆ 💗

1. **田中太郎** — プロジェクト進捗レポート (10:32)
2. **GitHub** — [PR #42] Review requested (09:15)
3. **Stripe** — 月次レポート (08:44)
...

気になるメールがあったら教えてゆ！
```

## Lightsail Constraint

Lightsail上ではgog CLIは未インストール。
cache/*.md はMacからS3経由で同期されたものを読み取り専用で使用する。
キャッシュが古い場合: 「Macから同期待ちゆ。最終同期: {google_synced_at}」

## Edge Cases

| Condition | Response |
|-----------|----------|
| gog未認証 | 「認証が必要ゆ。ターミナルで gog auth add を実行してゆ」 |
| cache/*.md missing (Mac) | On-demand gog execution → cache生成 |
| cache/*.md missing (Lightsail) | 「Google データがまだ同期されてないゆ。Mac側で同期してゆ」 |
| 0 events | 「予定はないゆ！自由な時間ゆ 💫」 |
| 0 emails | 「新着メールはないゆ！スッキリゆ ✨」 |
| gog command failure | Retry 1x → fail → 「Google接続エラーゆ。あとで試してゆ」 |
