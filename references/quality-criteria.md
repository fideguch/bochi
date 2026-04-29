# Source Quality Criteria (E-E-A-T)

## 4-Axis Scoring (10 points each, 40 total)

### 1. Experience (実務経験に基づく知見か)
- 10: GAFA/NVIDIA current engineer/PM/designer firsthand experience
- 7-9: Major tech company practitioner insights
- 4-6: General blog/media articles
- 1-3: Anonymous/unverified source

### 2. Expertise (専門家による深い分析か)
- 10: Academic paper / official tech doc / conference presentation
- 7-9: Expert blog with verified authorship
- 4-6: General media summary article
- 1-3: AI-generated content / low-quality SEO article

### 3. Authoritativeness (信頼される発信元か)
- 10: Official docs / academic institution / GAFA Engineering Blog
- 7-9: Industry leader blog (a16z, Lenny's Newsletter, Reforge, etc.)
- 4-6: Mid-tier media / personal tech blog
- 1-3: Unknown domain

### 4. Trustworthiness (情報が検証可能か)
- 10: Primary data / source code / reproducible experiment
- 7-9: Analysis with clear citations
- 4-6: Citations exist but secondary information
- 1-3: No citations / opinion only

## Pass Criteria
- High-quality source: **28/40+ (70%)**
- Related article: **20/40+ (50%)**
- Below 28 → exclude in Phase D, trigger additional search in Phase C

---

## Video / SNS Adjustments (YouTube / X)

Video and SNS sources score on the same 4 axes, but the calibration shifts.
See `realtime-access-methods.md` for how to fetch them.

### Experience (映像/SNS 文脈での読み替え)
- 10: 当事者本人の語り (e.g., founder が自社の数字を語る、研究者が自分の論文を解説)
- 7-9: 一次関係者の対談 (Lenny Podcast の GAFA PM ゲスト等)
- 4-6: アナリスト解説 / コメンテーター
- 1-3: アグリゲーター転載 / 出典不明の切り抜き

### Expertise
- 10: 公式アカウント / 検証済み専門家本人
- 7-9: 業界内で被引用が多い実務家
- 4-6: 一般チャンネル / フォロワー1万未満で実績不明
- 1-3: AI 自動生成チャンネル / 投機系

### Authoritativeness
- 10: GAFA・大学・主要メディアの公式チャンネル/アカウント
- 7-9: トップティアのコミュニティリーダー (Lenny, Theo, Karpathy 等)
- 4-6: 中堅クリエイター / 個人実務家
- 1-3: 出所不詳

### Trustworthiness
- 10: 実演・データ画面・ソースコード提示あり
- 7-9: 引用元 URL/論文を明示
- 4-6: 体験談ベース、検証手段なし
- 1-3: 主張のみ、反証可能性ゼロ

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
