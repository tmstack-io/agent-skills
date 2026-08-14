---
name: solista
description: セッション中の指定ロール（implement / review / explore）を単独の奏者に配役するセッションモード（編成1の concertino）。
disable-model-invocation: true
argument-hint: "--implement|--review|--explore（1つ以上・併用可。implement×review の併用は不可） [--harness <CLI名>] [--model <モデル>] [--sandbox <mode>] [--approval <policy>] [--reviewer <裁定者>] [--effort <level>]"
---

# solista — ソリストは同時に一人

> **明示起動の確認**: ユーザーがこのスキルを名指しで起動した場合のみ実行する。
> 文脈からの自動適用で読み込まれた場合は、実行せずユーザーに起動意思を確認する
> （`disable-model-invocation` を解釈しない実行環境での暴発防止）。

編成1の concertino。名前が規律である: ソリスト（ハーネスは concertino の規定に従い指定可・既定 codex）が立っている間、同じパートを弾く者はいない。

concertino の SKILL.md を Read し、**指定ロールのすべてを兼任する奏者1人の編成**として適用する（奏者ラベルは `solista`。人数指定を除く全パラメータをそのまま透過し、ロール間の禁則・規律・ハーネス起用も concertino の規定がそのまま生きる。`--harness <CLI名>` / `--model <モデル>` / `--effort <level>` は concertino の `--harness solista=<CLI名>` / `--model solista=<モデル>` / `--effort solista=<level>` として適用する）。解決順: `../concertino/SKILL.md` → 実行エージェント自身のスキルディレクトリをプロジェクト側 → グローバル側の順（Claude Code: `.claude/skills/` → `~/.claude/skills/`、Codex: `.agents/skills/` → `~/.codex/skills/`。他エージェント用のディレクトリは探さない）。見つからない場合は配役を開始せず、復旧手順（`npx skills add tmstack-io/agent-skills --skill concertino`）を案内して中止する。

複数ロールを兼務する場合、実行中の作業が属するロールの規律を適用する（implement 作業中はパート譜の書き込み範囲、explore / review 作業中は成果物置き場への読み取り専用規律）。
