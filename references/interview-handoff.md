# pm-discovery-interview-prep Handoff Spec

## Handoff Trigger
- User says: "ユーザーに聞きたい", "検証したい", "インタビューしたい"
- User selects option 2 in Phase F

## Data Mapping

| bochi Output | → | interview-prep Input |
|---|---|---|
| Opportunities | → | Research Goal |
| Target User | → | Target Segment |
| User Hypotheses | → | Assumptions to validate |
| Solution Candidates | → | Solutions to explore in interviews |

## Handoff Message Format
「pm-discovery-interview-prepを起動するゆ。以下の情報を引き継ぐゆ:
- 研究目標: {converted from Opportunities}
- 対象セグメント: {converted from Target User}
- 検証仮説: {User Hypotheses}
この内容で進めていいゆ？」

## After Confirmation
Invoke /pm-discovery-interview-prep with the mapped context.
The user proceeds to interview design with bochi's structured hypotheses
as the starting point for discovery questions.
