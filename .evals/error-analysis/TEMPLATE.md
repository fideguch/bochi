# Error Analysis: <date>

> `templates/error-analysis.md` から生成。`.evals/error-analysis/<date>-traces.md` に保存。
> Phase 1 の必須ゲート。**メトリクスより先に、実トレースを読むこと。** 合成データは不可。

## 入力 (Inputs)
- trace source: `collect-traces.sh` の出力（Claude session logs / git bug-fix / CI）
- 件数: <N>（目標 ~100。最低でも入手可能な範囲。15 未満なら bootstrap モードで `UNVALIDATED`）

## Step 1: Open Coding（自由記述、~30秒/件、分類しない）
| # | trace ref | 観察した失敗（自由記述） |
|---|-----------|--------------------------|
| 1 | <jsonl#Lxx> | |
| 2 | | |
| … | | |

## Step 2: Axial Coding（5-6 個の具体的カテゴリに集約）
> 「temporal issues」ではなく「date-format error」のように具体的に。

| taxonomy-id | カテゴリ名（具体的） | 説明 |
|-------------|---------------------|------|
| T1 | | |
| T2 | | |

## Step 3: 頻度集計（Count & Prioritize）
| taxonomy-id | 件数 | 全体比 | 優先度 |
|-------------|------|--------|--------|
| T1 | | % | |
| T2 | | % | |

> べき乗則を想定（少数のカテゴリが大半の失敗を占める）。上位から eval 化する。

## Step 4: saturation 判定
- [ ] 直近 ~20 件の新規トレースで新カテゴリが増えていない（=飽和。ここで打ち切ってよい）

## 出力 (Outputs)
- 上位失敗 → `eval-spec.md` を起こす対象:
  1. T?: …
  2. T?: …
