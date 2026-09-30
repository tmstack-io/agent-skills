# tui-harness のペイン入力の送信を散文の手順から mux.sh のサブコマンドへ移す

Status: accepted

ハーネスの入力欄へテキストを送って送信する操作を、SKILL.md に書いた手順（`send` → `sleep 1` → `key Enter`）から `mux.sh submit`（`send` → 画面への出現確認 → Enter → 入力欄の変化確認と Enter の再送、合計 3 回）へ移した。ダイアログへの番号・文字列の応答は `mux.sh answer`（`send` → 1 秒 → Enter）に移し、`send` と `key Enter` を手で組み合わせる形は SKILL.md・direct.md・transports・通信規約から消した。あわせて `send` / `key` / `run` / `submit` / `answer` / `close` に対象ペイン ID の存在確認を、herdr の `close` に消滅確認を内蔵し、`wait-output` の一致をリテラル部分一致に統一した。

理由: 実運用（tandem、指揮者 = Claude Code、委譲先 = Codex）で、指揮者が手順書の `sleep 1` を省いて `send && key Enter` と送り、question への回答 2 件が入力欄に残ったまま送信されない事故が起きた。再現実験（有効試行 40 件）で、間を置かない Enter は Codex TUI で 12 試行中 7 件が吸収され、1 秒の間・出現確認・herdr の一体送信 API はいずれも失敗しなかった。手順書に太字で書いても指揮者（LLM）は省略しうる。省略できない場所は散文ではなくツールであり、cmux バックエンドの `run` が既に持っていた「出現確認してから Enter」の構造を、送信全般へ両バックエンド共通のサブコマンドとして広げるのが最小の変更だった。`sleep` の秒数ではなく出現確認を採ったのは、「待ちは確定待ち」の原則（状態の完了を秒数で推測しない）と、TUI 初期化中の破棄を同じ確認で検出できるため。

## Considered Options

- **散文の強化（「省略不可」の明記・太字）** — 却下。今回まさに書いてあった手順が省かれた。読む側の注意に依存する対策は再発を防がない。
- **`sleep 1` をツールに内蔵するだけ** — 却下。実測では失敗ゼロだが、秒数は環境依存の推測であり、TUI 初期化中の破棄（テキスト自体が捨てられる）を検出できない。
- **herdr の `agent prompt`（送信 API）を使う** — 却下。失敗ゼロで blocked 中の送信拒否など利点はあるが herdr 固有で、cmux と実装が分かれる。出現確認と入力欄の変化確認を別途持つなら実質的な差は小さい。
- **`submit` に受理完了の判定（`agent-wait --until working`・`agent_session` の有無）まで内蔵する** — 却下。受理完了の条件はハーネス依存（`agent_session` を報告しないハーネス、初期化中の working 誤検知）で、失敗時の画面の意味読みは指揮者の判断が要る。ツールは「入力欄の状態」という機械判定できる範囲で止める。
- **`submit` と `answer` を導入し、両バックエンドに実装する（採用）**。

## Consequences

- SKILL.md「タスクの委譲」手順3の三分（作業表示あり / テキスト残存 / 何もなし）は、「テキスト残存 → Enter 再送」が `submit` に移ったため二分になった。question 回答の受理完了は `submit` の成功のみで判定する（委譲先が working のまま質問する場合、working 遷移は送信成否を示さないため）。
- cmux バックエンドの `submit` / `answer` / `wait-output` のリテラル一致化は未実測（herdr でのみ実測。`backends/cmux.md` に明記）。
- 送信の証跡が `submit` の終了コード（3: 画面に現れない、4: 入力欄が変わらない）になり、指揮者の即興（Tab の送信、Enter の二度押し）が入る余地を減らす。
- 副次観測として、`herdr agent wait --until idle` が idle 中の対象でタイムアウトする間欠事象と、Codex がターン完了後に done を報告する事象を記録した（`transports/codex-tui.md`）。起動時の idle 待ちと pull 安全網に影響しうるが、原因の切り分けは別件とした。
- 棚卸しで見つかった同型の候補（起動シーケンスと trust ダイアログ定義のデータ化 `launch`、行数規則の内蔵 `read --auto`、通信規約ブロックの機械生成 `brief`、分割方向の算術 `place`、既存ペインの照合 `resolve`、agent-wait の延長回数の内蔵、回答ファイルの直接回収 `collect`、直送返答の切り出し `reply`）は本 ADR の対象外とし、必要になった時点で個別に判断する。
