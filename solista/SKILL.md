---
name: solista
description: セッション中の指定ロール（implement / review / explore）を単独の奏者に配役するセッションモード（編成1の concertino）。
disable-model-invocation: true
argument-hint: "--implement [<値>]|--review [<値>]|--explore [<値>]（1つ以上・併用可。implement×review の併用は不可。値は <CLI名>[=<モデル>[@<エフォート>]] で、値を付けられるロールフラグは最大1つ） [--sandbox <mode>] [--approval <policy>] [--approvals-reviewer <裁定者>]"
---

# solista — ソリストは同時に一人

> **明示起動の確認**: ユーザーがこのスキルを名指しで起動した場合のみ実行する。
> 文脈からの自動適用で読み込まれた場合は、実行せずユーザーに起動意思を確認する
> （`disable-model-invocation` を解釈しない実行環境での暴発防止）。

編成1の concertino。名前が規律である: ソリスト（ハーネスとモデルは concertino の異系統委譲規定に従って明示選択。指揮者と異系統のモデルであることが必須で、成立しなければ中止）が立っている間、同じパートを弾く者はいない。

concertino の SKILL.md を Read し、**指定ロールのすべてを兼任する奏者1人の編成**として適用する（奏者ラベルは `solista`。全パラメータをそのまま透過し、ロール間の禁則・規律・ハーネス起用も concertino の規定がそのまま生きる。ロールフラグの値 `<CLI名>[=<モデル>[@<エフォート>]]`〔書式の正本は tui-harness の「委譲先指定値の書式」〕は、どのロールフラグに付けてもよいが**最大1つ**で、concertino における奏者 solista のハーネス・モデル指定として適用する。2つ以上のロールフラグに値が付いた場合は〔同じ値であっても〕、また同一ロールフラグが繰り返し指定された場合は〔奏者は常に1人のため〕、いずれも解釈せず、指定値と正しい形式を示して再指定を求める）。解決順: `../concertino/SKILL.md` → 実行ハーネス自身のスキルディレクトリをプロジェクト側 → グローバル側の順（Claude Code: `.claude/skills/` → `~/.claude/skills/`、Codex: `.agents/skills/` → `~/.agents/skills/`。他ハーネス用のディレクトリは探さない）。見つからない場合は配役を開始せず、復旧手順（`npx skills add tmstack-io/agent-skills --skill concertino`）を案内して中止する。

複数ロールを兼務する場合、実行中の作業が属するロールの規律を適用する（implement 作業中はパート譜の書き込み範囲、explore / review 作業中は成果物置き場への読み取り専用規律）。
