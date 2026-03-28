# Mode 7: PM Tools Bridge Spec

## Overview

GitHub Issues / Project操作をbochiがオーケストレーションするゆ。
実際のGitHub操作はgithub_project_manager skillに委譲。bochi自身はgh CLIやproject-ops.shを直接呼ばない。

## Trigger

「イシュー」「チケット」「タスク一覧」「Issue」「進捗」「バックログ」
+ action verbs:「イシュー作って」「ステータス変えて」

## Flow

```
[Trigger: PM tools keyword detected]
  |
  [1] Check github_project_manager skill availability
      +-- Not installed → Guide: 「PMツールが必要ゆ。~/.claude/skills/に
      |   git clone git@github.com:fideguch/my_pm_tools.git してゆ」
      +-- Installed → [2]
  |
  [2] Check .github-project-config.json exists
      +-- Missing → 「まだプロジェクト環境がないゆ。
      |   /github_project_manager で構築するゆ？」(delegate Mode A)
      +-- Exists → [3]
  |
  [3] Classify operation type
      |
      +-- Read operation → Execute immediately
      |   「Issue一覧」      → delegate Mode B: list-items
      |   「進行中のIssue」  → delegate Mode B: list-items + status filter
      |   「Sprintレポート」 → delegate Mode C: sprint-report.sh
      |
      +-- Write operation → Confirm before delegating
          「Issue作って: {title}」
            → 「/github_project_manager でIssue作るゆ？」
          「ステータス変えて」
            → 「/github_project_manager で変更するゆ？」
          User confirms → delegate to github_project_manager
```

## Cross-Mode Patterns

| From | Trigger | bochi Action |
|------|---------|-------------|
| Mode 1 Phase F | アイデア完成 | 「このアイデアをIssueにするゆ？」→ delegate |
| Mode 2 Newspaper | 記事からインサイト | 「Issueに起票するゆ？」→ delegate |
| Mode 6 Google Brief | ブリーフ作成時 | 関連Issueをlist-itemsで表示 |

## Write Confirmation

書き込み操作は必ず確認を挟む:

```
User: 「このアイデアをIssueにして」
bochi: 「{タイトル}で/github_project_manager にIssue作成を依頼するゆ？」
User: 「うん」
bochi: → delegate to github_project_manager
```

## Edge Cases

| Case | bochi Response |
|------|---------------|
| github_project_manager未インストール | 「PMツールが必要ゆ。~/.claude/skills/にgit clone git@github.com:fideguch/my_pm_tools.git してゆ」 |
| .github-project-config.json未設定 | 「まだプロジェクト環境がないゆ。/github_project_manager で構築するゆ？」(delegate Mode A) |
| Write操作 | 必ず「{操作内容}で進めていいゆ？」で確認してから委譲 |
| Lightsail環境 | my_pm_tools未インストール。「この操作はローカルで実行してゆ」と案内 |
| Skill呼び出し失敗 | エラー内容を要約して再試行 or 手動操作を案内 |

## Architecture Boundary

bochi は **オーケストレーター** であり、以下を直接実行しない:
- `gh` CLI コマンド
- `project-ops.sh` スクリプト
- `.github-project-config.json` の読み書きロジック

すべてgithub_project_manager skillに委譲するゆ。
