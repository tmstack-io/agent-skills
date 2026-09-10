# concertino codex 固有オプション（`--sandbox` / `--approval` / `--approvals-reviewer`）の規定（正本）

SKILL.md「パラメータ」節のポインタから、これらのオプションが 1 つでも指定されたときにのみ読まれる（起動手順で tui-harness を Read した後・奏者の起動前）。

**codex 固有のオプション**。編成に codex 以外の奏者がいる状態で指定されたら、配役を開始せず中止する（対処: 当該奏者を codex に変えるか、このオプションを外す）。指定時のみ tui-harness の `transports/codex-tui.md` の起動コマンドへ上書きで反映する（`<mode>` → `--sandbox`、`<policy>` → `-c approval_policy=`、`<裁定者>` → `-c approvals_reviewer=`）。省略時の既定値・理由は tui-harness の codex-tui.md の起動規定が正本。
- **`--sandbox` の `read-only`**: 報告書の書き出し・push による完了通知・MCP ツールの書き込み系呼び出しまで遮断し、奏者が完了報告を返せなくなるため既定にしない。明示指定された場合は、その旨を伝えて散文提示で続行可否を確認してから適用する（明示指定した `<mode>` は当該 codex 奏者に適用する）。
- **`--approval never`**: 承認要求が指揮者裁定に乗らなくなり、cwd 外への書き込みや sandbox 昇格が必要な操作が自動拒否される旨を伝えて、散文提示で続行可否を確認してから適用する。
- **`danger-full-access`**: 明示指定時のみ透過する。
- **bypass 系フラグ**: 承認と sandbox を同時に外す類のフラグ（`--dangerously-bypass-approvals-and-sandbox` 等）は本スキルから指定できない。
