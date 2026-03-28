# Mode 1 E2E Walkthrough: Discord DM

This walkthrough demonstrates a complete Mode 1 (Idea Expansion) session via Discord DM.

## Scenario

User sends: `SaaSのチャーン対策について考えたい`

---

## Phase A: Socratic Questioning

**bochi reacts**: (instant, before any text)

**bochi replies**:
> チャーン対策、いいテーマゆ！💫
> まず確認させてゆ — どのフェーズのチャーンが気になるゆ？
> オンボーディング初期？それとも契約更新タイミングゆ？

**User**: `オンボーディング初期の離脱が多い`

**bochi**:
> なるほどゆ。初期離脱ってことは「価値を感じる前に去ってる」パターンゆ？
> ターゲットユーザーのセグメントは決まってるゆ？

**User**: `SMBのマーケティング担当者`

## Phase B: SCAMPER Expansion

**bochi**:
> 整理するゆ！「SMBマーケ担当がオンボーディング初期に離脱する」問題ゆ ✨
>
> 3つの拡張方向を提案するゆ:
>
> **S（代替）**: オンボーディングをセルフサーブからハイタッチCSに切り替えたら？
> **C（結合）**: 既存ツール（Slack/Teams）と統合してオンボ体験をシームレスに
> **E（排除）**: 初期設定ステップを半分に削減して最短でAha momentに到達
>
> どの方向が気になるゆ？💗

**User**: `E（排除）が面白い`

## Phase C: Research (ReAct Loop)

**bochi** (edit_message for progress):
> 調べてるゆ...💫

3 parallel WebSearch queries fire:

1. `SaaS onboarding step reduction churn impact 2025`
2. `time-to-value optimization B2B SaaS`
3. `aha moment onboarding best practices`

**bochi** (new reply with results):
> リサーチ結果が出たゆ ✨
>
> **Thought 1**: オンボーディングステップ削減のチャーン改善効果を確認
> **Observation**: ステップ50%削減で30日チャーン率が23%改善したケーススタディあり
> 📎 [SaaS Onboarding Optimization — userpilot.com](https://userpilot.com/xxx)

## Phase D: Critique

bochi runs critique-checklist internally:

- First-principles check: PASS
- Bias check: PASS (opposing view: ステップ削減で機能理解が浅くなるリスクあり)
- Freshness: All sources within 1 year

## Phase E: Output

**bochi** (structured summary via Discord messages):

Message 1:
> **SaaSオンボーディング初期離脱の対策**ゆ ✨
>
> 結論: 初期設定ステップを50%削減し、最短でAha momentに到達させることで
> 30日チャーン率を20-30%改善できる可能性が高いゆ

Message 2:
> **高品質ソース** 📚
>
> 1. [Onboarding最適化 — userpilot.com](URL) | 35/40
> 2. [Time-to-Value分析 — openviewpartners.com](URL) | 33/40
> 3. [B2B SaaSチャーン統計 — profitwell.com](URL) | 32/40

Message 3:
> **機会 → 解決策 → 実験**
>
> - 機会: SMBマーケ担当の初期設定負荷が高すぎる
> - 解決策A: プリセットテンプレートで設定を自動化 (実現性: High)
> - 実験: 既存ユーザー50名にテンプレート版を提供、7日後のアクティブ率比較

File saved: `~/.claude/bochi-data/topics/2026-03-28-saas-churn-onboarding.md`
Index updated: `index.jsonl` appended

## Phase F: Next Steps

**bochi**:
> 次どうするゆ？💗
>
> 1. /brainstorming で設計に落とすゆ？
> 2. /pm-discovery-interview-prep でユーザーに聞いてみるゆ？
> 3. もっと深掘りするゆ？
>
> あと、このアイデア **メモに残すゆ？💫**

**User**: reacts with two emoji

**bochi**: (detects high interest, records to seen.jsonl, proposes memo save)

---

## Key Observations

- React appeared before any text reply (HARD-GATE compliance)
- Each Discord message was under 300 characters (section-based splitting)
- Conclusion appeared in the first message (conclusion-first)
- Sources used hyperlink format with domain labels
- File output used professional tone (no "ゆ")
- Proactive save was offered after detecting user engagement
