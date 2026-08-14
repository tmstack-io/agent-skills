# concertino / solista / maestro を claude-skills から移管し指揮者非依存のセッションモードとして収録する

Status: accepted

ADR 0004 は tui-harness 移管時に concertino / solista の同時移管を「iterate-review（claude-skills 残留・CC 専用）への依存が跨ぎ参照の逆転を生む」として却下し、「codex 指揮者での実運用実績が積めた後に再判定する」とした。tui-harness（ADR 0004）と roundtable（ADR 0005）の codex 指揮者スモークで実績が積まれたため再判定し、3スキルを実行エージェント（指揮者）を問わない汎用スキルへ改めたうえで移管する。

却下理由だった iterate-review 依存は、concertino の `--review` を再定義して解消した: レビュー依頼の形式（対象種別・観点・severity 付き指摘形式・読み取り専用規律・複数奏者の観点分担）を **concertino 内蔵のレビュー規範**として自己完結記述し、iterate-review への参照を削除した。対象は git 差分に限定しない（差分・設計書・任意ファイル）。合否二値（旧レビュー契約の GREEN 集約）は concertino からは消え、統合した指摘一覧の報告までを担う（合否はレビューループやユーザーの判定に委ねる）。iterate-review は claude-skills に残留し、一切変更しない — 同スキルが配役先をレビュアーに使う経路は、依頼文自体が契約形式を運ぶため引き続き成立する。外部レビュー形式（mattpocock/skills の code-review 等）への差し替えは、git 差分専用でありレビューロールの広範な用途に合わないため採らなかった。

maestro の奏者は能力の二段で確定する: サブエージェント起用と継続対話の機能がある実行エージェント（CC: Agent＋SendMessage、codex: ネイティブサブエージェント）ではサブエージェント（既定）。無い環境では**指揮者と同系統の CLI**（codex 指揮者なら codex、grok 指揮者なら grok）を tui-harness のペインで奏者に立てるが、この縮退（委譲の直列化を含む）は散文提示でユーザーの許諾を得た場合のみ採用し、TUI マルチプレクサが無ければ警告を提示して起動しない。品質ゲート三段（実装奏者→別個体レビュー奏者→指揮者検収）は経路によらず維持する。

検証: 2026-08-15 のスモーク6本（concertino / solista / maestro × CC 指揮者・codex 指揮者）で全経路合格。concertino 系はレビュー規範による非 git 文書レビュー（CC 直営・codex 指揮者の solista 経由の両方）と explore 配役を含み、いずれも配役解除（ペインクローズ・`.concertino` 削除）まで完走。maestro は両指揮者ともサブエージェント経路（CC: Agent、codex: ネイティブ）で三段ゲートを完走。maestro の同系統ペイン代替経路は、実測した2指揮者がいずれもサブエージェントを持つため未実測のまま収録する（roundtable の host ペイン代替と同じ扱い）。

## Considered Options

- **claude-skills に残す（ADR 0004 の判断維持）** — 却下。codex 等を指揮者にする実需に対し配布経路を塞ぐ。CC 固有依存（AskUserQuestion・ツール固有名・iterate-review 参照）はいずれも既存規約と再定義で中立化できる薄さだった。
- **iterate-review も同時移管** — 却下。ユーザー判断により iterate-review は現状のまま残す（AskUserQuestion 使用等の規約追随も行わない）。concertino 側の依存切断で跨ぎ参照の逆転は生じない。
- **concertino の --review ロールを削除し外部レビュー機能に委ねる** — 却下。ハーネスによる独立批評の配役経路が失われる。
- **--review をレビュー規範の内蔵で再定義して3スキルを移管（採用）**。

## Consequences

- 語彙（配役・編成・奏者・ロール・パート譜・single-writer・成果物置き場・確定待ち。指揮者は定義を拡張）は本リポジトリの CONTEXT.md へ収録。claude-skills 側は iterate-review / deep-pr-review が参照する範囲で保持する（両リポジトリ保持は ADR 0004 と同じ扱い）。
- maestro の奏者モデル既定は能力主語化（サブエージェント経路: 実行エージェントの標準的な安価モデル〔CC: sonnet〕、ペイン経路: 当該 CLI の既定モデル）。
- git 履歴は移植しない（3スキルの過去の変更履歴は claude-skills 側に残る）。
