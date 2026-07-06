# Eval フィードバック（プロジェクト向け）: <date>

> `gen-feedback.sh` が生成。対象 = プロジェクト本体。`.evals/feedback/FEEDBACK.md`。
> これは「何が・どれだけ・いつから劣化したか」と「具体的な修正案」を示す。

## サマリ (Summary)
- run: `<sha>_<date>` （dirty: <true|false>）
- 結果: pass <P>/<N>（`pass@k=__` / `pass^k=__`、95% CI=`[__,__]`）
- baseline 比較: regression <R> 件 / 改善 <I> 件
- verdict: `PASS` | `REGRESSION` | `NO_BASELINE`

## 検出された regression（baseline 比較）
| assertion id | eval | baseline | latest | 差分 | 重大度 |
|--------------|------|----------|--------|------|--------|
| A1 | <feature> | 0.98 | 0.81 | -0.17 | HIGH |

## 失敗トランスクリプト（抜粋）
- <assertion id> — `history/<sha>_<date>.json` / `transcript_ref`:
  ```
  <excerpt>
  ```

## 修正提案（プロジェクト本体）
> 具体的なコード/プロンプト変更。重大なものはタスク化を推奨。
1. [HIGH] <file:line> — <現状> → <提案>。根拠: <assertion id + transcript>
2. [MED]  …

## criteria drift シグナル
- [ ] 現 taxonomy に無い失敗モードが出現 → **Phase 1（error analysis）を再実行**することを推奨
- [ ] judge↔outcome の不一致が上昇 → judge 再校正を推奨

## 次のステップ
- [ ] 修正を適用 → `run` → `report`
- [ ] 改善が確認できたら `accept-baseline`（human-gated）
