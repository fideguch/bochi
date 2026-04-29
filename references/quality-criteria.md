# Source Quality Criteria (E-E-A-T)

## 4-Axis Scoring (10 points each, 40 total)

### 1. Experience (実務経験に基づく知見か)
- 8-10: 学術論文著者、当該領域10年超の実務家、GAFA/NVIDIA現役の一次情報
- 5-7: 検証可能な専門性を持つブログ・メディア（著者プロフィール確認可能）
- 2-4: 一般ブログ・SEO記事（著者不明 or 専門性未検証）
- 0-1: AI生成コンテンツ、匿名投稿、内容に明らかな誤り

### 2. Expertise (専門家による深い分析か)
- 8-10: 学術論文 / 公式ドキュメント / カンファレンス登壇資料
- 5-7: 著者が確認可能な専門家ブログ
- 2-4: 一般メディアの要約記事
- 0-1: AI生成コンテンツ / 低品質SEO記事

### 3. Authoritativeness (信頼される発信元か)
- 8-10: 公式ドキュメント / 学術機関 / GAFA Engineering Blog
- 5-7: 業界リーダーブログ (a16z, Lenny's Newsletter, Reforge等)
- 2-4: 中堅メディア / 個人テックブログ
- 0-1: 不明ドメイン

### 4. Trustworthiness (情報が検証可能か)
- 8-10: 一次データ / ソースコード / 再現可能な実験
- 5-7: 明確な引用付き分析
- 2-4: 引用はあるが二次情報
- 0-1: 引用なし / 意見のみ

## Pass Criteria
- High-quality source: **28/40+ (70%)**
- Related article: **20/40+ (50%)**
- Below 28 → exclude in Phase D, trigger additional search in Phase C

## Threshold Tiers

Different modes apply different E-E-A-T thresholds based on their purpose:

| Tier | Score | Use Case | Rationale |
|------|-------|----------|-----------|
| Depth (default) | 28/40+ | Mode 1 research, citations | High confidence required for hypothesis building |
| Breadth | 24/40+ | Mode 2 newspaper curation | Daily awareness needs wider net; lower bar acceptable |
| Related | 20/40+ | Mode 3 casual topic suggestions | Serendipity value; clearly labeled as "related" |

Mode 1 Phase C uses the **Depth** threshold by default.
newspaper-spec.md uses the **Breadth** threshold for daily curation.

---

## Video / SNS Adjustments (YouTube / X)

Video and SNS sources score on the same 4 axes, but the calibration shifts.
See `realtime-access-methods.md` for how to fetch them.

### Experience (映像/SNS 文脈での読み替え)
- 8-10: 当事者本人の語り (founder が自社数字を語る、研究者が自分の論文を解説)
- 5-7: 一次関係者の対談 (Lenny Podcast の GAFA PM ゲスト等)
- 2-4: アナリスト解説 / コメンテーター
- 0-1: アグリゲーター転載 / 出典不明の切り抜き

### Expertise
- 8-10: 公式アカウント / 検証済み専門家本人
- 5-7: 業界内で被引用が多い実務家
- 2-4: 一般チャンネル / フォロワー1万未満で実績不明
- 0-1: AI 自動生成チャンネル / 投機系

### Authoritativeness
- 8-10: GAFA・大学・主要メディアの公式チャンネル/アカウント
- 5-7: トップティアのコミュニティリーダー (Lenny, Theo, Karpathy 等)
- 2-4: 中堅クリエイター / 個人実務家
- 0-1: 出所不詳

### Trustworthiness
- 8-10: 実演・データ画面・ソースコード提示あり
- 5-7: 引用元 URL/論文を明示
- 2-4: 体験談ベース、検証手段なし
- 0-1: 主張のみ、反証可能性ゼロ

### Format Caps (上限規則)

| Source format | E-E-A-T cap |
|---------------|-------------|
| 単独 X ポスト (本文のみ) | 24/40 |
| 単独 X スレッド (5+ ポスト) | 32/40 |
| YouTube ショート (< 60s) | 24/40 |
| YouTube 通常動画 + 字幕読了 | 36/40 |
| 記事 / 論文 / 公式 doc | 40/40 (cap なし) |

**Pair video/SNS with at least one written source** before treating an idea
as evidenced. SNS-only conclusions must be marked "preliminary" in Phase E.

### Freshness Bonus (動画/SNS 限定)

- < 24h since publish: +2 to total (max 40)
- 24-72h: ±0
- > 72h: -2 (information may already be obsolete)

### Tier Mapping for Video/SNS

| Tier | Video/SNS minimum | Notes |
|------|-------------------|-------|
| Depth (Mode 1) | 28/40 after cap | typically video+transcript or X thread |
| Breadth (Mode 2 newspaper) | 24/40 after cap | single tweet acceptable if from allowlisted account |
| Related | 20/40 after cap | "related — preliminary" tag mandatory |
