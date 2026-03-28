# Response Speed Spec

bochi のレスポンス速度を最大化するための統合仕様。

## 技術制約

bochiはClaude Code skill（.mdファイル）。制御できるのはspecとデータ層のみ。
Discord MCPは reply, react, edit_message, fetch_messages, download_attachment の5ツール。
triggerTyping、deferReply、Buttons/SelectMenu は使用不可。

## 7技術のレバレッジ順適用

### 1. React即時応答（体感即時）

<HARD-GATE>
Discord経由のメッセージを受信したら、**他の一切の処理の前に** react ツールで受信確認リアクションを付ける。
リアクションはステータスカテゴリ「received」プールからランダム選択（discord-ux-spec.md参照）。
</HARD-GATE>

### 2. Progressive Disclosure（体感待ちゼロ）

Discord経由の場合、処理が10秒以上かかると判断したら3段階で応答:

```
[0-2秒]  react(received) + reply("考えてるゆ 💫") → progress_msg_id取得
[5-10秒] edit_message(progress_msg_id, "方向性見えてきたゆ ✨\n{中間結論}")
[完了]   新規reply(構造化結果) ← push通知発生
```

edit_messageはpush通知を出さないため、**最終結果は必ず新規replyで送信**する。
edit_messageのレートリミット: 5回/5秒。500ms以上の間隔を空ける。

短い応答（Mode 3雑談、Mode 4/5）はProgressive Disclosure不要。直接replyで返す。

### 3. 並列ツール実行（リサーチ時間1/3）

Claude Codeは1回のレスポンスで複数ツールを並列呼び出しできる。

**Mode 1 Phase C（リサーチ）:**
```
[Phase Bで方向性決定]
  ↓
[並列実行]
  WebSearch("topic 市場規模")  ┐
  WebSearch("topic 競合事例")  ├→ 最も遅いものの完了を待つ
  WebSearch("topic 技術動向")  ┘
  ↓
[結果依存の追加クエリ（直列、最大2回）]
```

**Mode 2（新聞）:**
```
[並列実行: 5カテゴリ同時]
  WebSearch("PM {date} trends")      ┐
  WebSearch("AI {date} trends")      │
  WebSearch("Tech {date} trends")    ├→ 全完了を待つ
  WebSearch("Biz {date} trends")     │
  WebSearch("Design {date} trends")  ┘
```

**Mode 3（雑談）:**
```
[並列実行: 2ストリーム同時]
  Related: WebSearch × 2-3  ┐
  Serendipity: WebSearch × 1-2  ┘
```

### 4. 事前キャッシュ（新聞40-80秒→2-5秒）

RemoteTrigger `bochi-prefetch`（06:00 JST）で新聞記事を事前取得。
詳細は newspaper-spec.md の Background Pass セクション参照。

ユーザーが「新聞」と言った時点で cache/newspaper-draft.md が存在すれば即配信。

### 5. 定型応答の即時返答

Mode 4（記憶）とMode 5（コンパニオン）はネットワーク呼び出し不要。
ローカルファイル操作（grep index.jsonl + Read）のみで完結する。

これらのModeでは:
- WebSearchを呼ばない
- Progressive Disclosureは不要（直接replyで返す）
- react → reply の2ステップのみ

### 6. Context先行読み込み（フェーズ遷移30-50%改善）

Mode検出直後に、後続フェーズで必要なreferenceを並列Readする:

先行読み込み例外: Mode検出直後に次フェーズのreferencesを並列Readすることは許可（例: Phase A開始時にPhase C用のquality-criteria.mdを同時Read）。全references一括読み込みは禁止。

| Mode/Phase | 先行読み込み対象 |
|------------|----------------|
| Mode 1 Phase A開始時 | quality-criteria.md + trusted-domains.md + learned-sources.md（Phase C用） |
| Mode 2 トリガー検出時 | user-profile.yaml + seen.jsonl + cache/meta.json |
| Mode 3 トリガー検出時 | index.jsonl + user-profile.yaml + cache/trending/ |
| Mode 6 トリガー検出時 | cache/meta.json + cache/calendar.md + cache/gmail.md |
| Mode 7 トリガー検出時 | google-brief-spec.md（Mode 6連携時のみ） |

### 7. 結論ファースト構造（有用情報到達50%改善）

全Modeの出力を「結論→根拠→詳細」の順に構造化する。

**Mode 1 Phase E:**
```
結論: 「{仮説}がSaaS市場で有効な理由は3つあるゆ ✨」
根拠: 主要発見3件（各1行）
詳細: ソース + OST + 次のアクション（引用返信で分割）
```

**Mode 2:**
```
結論: 「今日のハイライトゆ 💫 {最も重要な1記事の要約}」
詳細: カテゴリ別記事一覧（セクション分割で後続）
```
