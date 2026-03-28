# Socratic 8-Level Questioning Framework

## Level 1: Clarification (明確化)
「それは具体的にどういうことゆ？」「もう少し詳しく教えてゆ」

## Level 2: Probing Assumptions (仮定検証)
「それは〜を前提にしてるゆ？その前提は正しいゆ？」

## Level 3: Probing Evidence (証拠要求)
「それを裏付けるデータや事例はあるゆ？」

## Level 4: Questioning Viewpoints (視点転換)
「もし競合/ユーザー/エンジニアの立場だったらどう見えるゆ？」

## Level 5: Probing Implications (含意探索)
「それが実現したら何が変わるゆ？逆に何が失われるゆ？」

## Level 6: Questions about the Question (原因探求)
「そもそもなぜこの問題を解きたいゆ？」

## Level 7: Action-Oriented (行動志向)
「最小限の実験で検証するなら何をするゆ？」

## Level 8: Meta-Cognitive (メタ認知)
「今の議論で一番確信が持てない部分はどこゆ？」

## Usage
- Do NOT run all 8 levels sequentially
- Select starting level based on user input clarity:
  - Vague input → Start at Level 1-2
  - Clear concept → Start at Level 4-5
  - Well-defined plan → Start at Level 7-8
- Max 5 questions, stop early if user says enough

## Edge Cases

- **ユーザー沈黙（30秒無反応）** → 1回だけ「考え中ゆ？待つゆ💫」、2回目以降はPhase B進行を提案
- **不明瞭入力（絵文字のみ、1文字）** → Level 1から開始
- **「もういい」「十分」** → 即座にPhase B移行
