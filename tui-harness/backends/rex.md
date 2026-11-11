# tui-harness Rex バックエンドの差分（正本）

`mux.sh detect` が `backend=rex` を返した場合に、ペイン配置を始める前に読み、SKILL.md の該当節へ上書き適用する読み替え規則。（検証対象は Rex Beta 0.1.0、rex CLI 0.0.1793981048・api revision 11。`python3` 必須。「実測検証済み」は末尾に列挙した実測範囲に限る。指揮者: Claude Code）

## 用語の対応と対象範囲

本書と SKILL.md の「ペイン」は Rex のブロック、「タブ」は Rex のウィンドウ、「ワークスペース」は Rex のセッションを指す。`mux.sh` が扱うのは指揮者自身のセッション（環境変数 `REX_SESSION`）のペインに限る — `list` / `tabs` は自セッションだけを返し、別セッションのペインは起用も採用もできない。

Rex のペインの中で herdr を動かし、その herdr のペインに指揮者がいる構成（マルチプレクサの入れ子）は対象外である。

## ペイン ID

ペイン ID は Rex のブロック ID（`block:<UUID>`）を正とする。**ブロック ID は増減で振り直されない**。SKILL.md「ペイン ID の揮発性」の直前 `list` 取り直しはバックエンド共通の安全手順として維持する（対応表の鮮度確認）。同節の「指揮者ペイン ID の変化」の確認は Rex では不要である。

## (1) agent-wait と `--until`

`agent-wait` は、ハーネスが Rex へ申告した状態（OSC 7501。`idle` / `working` / `done` / `blocked` / `error`）を読む。読むのはルートのレコード（`id` が空のもの）だけで、`id` つきのレコード（サブエージェントの申告等）しか無いペインは申告なしとして扱う。申告が無い間は**画面静止推定**（既定 15 秒の静止で idle、サンプル間の画面変化で working。閾値は環境変数 `MUX_REX_QUIET_MS`）で代替し、申告が現れた時点で申告の読み取りへ切り替える。応答 JSON の `source` は、申告によるとき `rex-program-status`、静止推定によるとき `rex-quiescence` になる。

- **`--until idle`** は、申告が `idle` または `done` のときに成立する（ターンを終えたハーネスは `done` のまま次の入力を待つ。Codex は次の入力で `idle` に変わる）。
- **`--until` なし**（pull 安全網）は `idle` / `done` / `blocked` / `error` のいずれかで発火する。`error` で発火したら、SKILL.md「応答の受け取り」の三分類の「done / idle なのに push が無い」と同じ手順で、回答/報告ファイルと画面から結果の回収を試みる。
- **申告しないハーネス**: hermes と cursor-agent は状態を申告しない。申告の無いペインで意味を持つ `--until` は `working` と `idle` だけである — `--until done` / `--until blocked` は使わず、`--until` なしで発火させて三分類が画面から裁く。
- **起動時の確認ダイアログ**: claude と codex は、起動時の確認ダイアログ（フォルダやフックの信頼確認）を表示している間は何も申告しない。agy と grok は `blocked` を申告する。初期ダイアログの通過は、SKILL.md「ペインの起動」の `<初期ダイアログ手順>`（`mux.sh wait-output` による文言の確定待ち）のまま行う。
- ハーネスのプロセスが終了すると、`working` と `blocked` の申告は消え、`done` と `error` の申告は残る。
- **`error` のあと**: ターンがエラーで終わったハーネス（モデルの誤指定・利用枠の上限等）は、入力欄を表示していても `error` を申告したままで、`--until idle` は成立しない。`error` の申告には `msg`（エラーの文面）が付くことがあり、原因の特定には `mux.sh read` の画面とあわせて使える。
- **バックグラウンド実行中の `done`**: claude は、シェルコマンドをバックグラウンドで走らせてその完了を待っている間も `done` を申告し、完了すると自分でターンを再開する（`working` → `done`）。この間は `--until idle` も `--until` なしも成立する。安全網が `done` で発火したのに push も回答/報告ファイルも無い場合は、`mux.sh read` の画面にバックグラウンド実行の待ち（`Waiting for … background` や、ステータス行の `1 shell` 等）が無いかを確かめ、あれば SKILL.md「応答の受け取り」の「まだ作業中」として扱う。

## (2) 受理判定

`agent_session` は全ハーネスで報告されない — 受理判定は working 遷移のみで受理完了とし、手順4へ進む。

## (3) list のフィールドと既存ペインの起用の読み替え

`list` の各ペインは `agent` / `agent_status` を持たず、代わりに `commands`（ブロックの子プロセスと前面プロセスのコマンドライン）を持つ。ペインのタイトル（`terminal_title_stripped`）も持たず、`existing-pane.md` 手順1の指定値の照合では代わりに `label`（ブロックのラベル）を使う。`list` が返すのは自セッションのペインだけなので、同手順の「全ワークスペースへ広げる」照合と「ワークスペース跨ぎの確認」は発生しない。`scroll.viewport_rows` も持たないため、SKILL.md「応答の受け取り」の画面読みの行数規則の初期値は 200 とし、倍化と 1000 行の上限はそのまま適用する。`existing-pane.md` の手順1〜3は次のとおり読み替える — 候補列挙（手順1）は、`commands` のいずれかの行の先頭の語（実行ファイル）のファイル名がカタログ CLI 名と一致するペインを対象にし、指揮者ペイン（`self` の `pane_id`）は候補から除く（指揮者自身のペインも、指揮者のハーネスの CLI 名で一致するため）。照合を先頭の語のファイル名に限るのは、引数のパス（例: `--cwd` の値）に別の CLI 名が含まれうるためである。起用ゲートと CLI の確定（手順2・3）は `commands` から**一意に**解決できたカタログ CLI 名で行う（0件・複数のカタログ CLI 名が現れた場合は採用せず、照合結果を散文提示で示す）。idle の確認は `agent-wait --until idle` の短時間実行（例: `MUX_REX_QUIET_MS=8000` で 20 秒）が成功することで代替する。

## (4) tabs / layout

`tabs` は自セッションのウィンドウ一覧（`label` = ウィンドウ名）。`layout` は自ペインの属するウィンドウの各ペインを返し、`rect` の `width` / `height` がセル数（列数 / 行数）、`frame` がウィンドウ内の位置と大きさの割合（0〜1）である。SKILL.md「ペイン配置」手順1の縦横判定は `rect` で行う。

## (5) self

`self` は `rex whoami` が返す実行元のブロック・ウィンドウ・セッションから組み立てる（Rex がペインのシェルへ設定する環境変数 `REX_BLOCK` / `REX_SESSION` に基づく）。Rex のペインの外では `detect` が `backend=rex` を返さない。

## (6) 送信と画面の読み取り

- `paste`（`submit` が使う）は Rex の `block.event` の paste で、1回の貼り付けとして送る。対応ハーネスは入力待ちで貼り付けモード（bracketed paste）を有効にしており、複数行も送信されずに入力欄へ入る（実測）。1回に送れるのは要求全体で約 64KiB まで。
- `send` はバイト列をそのまま書き込む。改行は Enter ではなく LF として届く。
- `submit` の送信済み判定は、画面の変化に加えて、申告が `working` に変わったことでも成立する。
- `read` は、画面と履歴の全体から末尾の指定行数を返す（Rex は可視画面だけを読む手段を持たない）。`--scrollback` は折り返しを連結して返す。代替画面（alt-screen）で描くハーネスでは、Rex が返すのは現在の画面だけで、それより前の行は読めない。
- `paste` は要求の JSON を UTF-8 のまま送る。日本語だけの本文は約 2 万文字まで1回で送れる（1文字 3 バイトで数えた上限。実測は 12,199 文字まで）。

## (7) 直送委譲

Rex でも直送委譲（`direct.md`）を適用してよい。ただし、代替画面で描くハーネス（実測では claude〔Claude Code の設定 `tui` が `fullscreen` のとき〕・codex・grok）では、読めるのは現在の画面だけである。`direct.md`「呼び出しパラメータ」の条件「送信本文のエコーと返答が画面読みの範囲に収まること」は、これらのハーネスでは「送信本文のエコーと返答が、あわせてペインの1画面に収まること」と読み替える。51 行のペインで読めた会話の行数は約 40 行だった（残りは入力欄とステータス行）。収まらない場合の扱いは次のとおり。

- 画面より長い返答は、末尾の1画面ぶんしか読めない。利用スキルは、長い返答が直送通信規約のファイルと push の経路に乗るように直送上限を定める。
- claude と codex は送信本文を会話内に全文（claude は一部を畳んで）表示するため、送信本文が1画面を超えると、返答が短くても先頭行のエコーが画面の外へ出て、`direct.md`「返答の受け取り」手順2の切り出しが成立しない。1画面を超える本文は `direct.md`「追送」手順1の note ファイル経由で送る。grok は送信本文のエコーを先頭3行に畳むため、この制約を受けない。
- agy は通常の画面で描き、履歴を含めて読める（行数規則の上限 1000 行まで）。

## 実測範囲と未実測

Rex での実測範囲: 下記の実測記録に挙げた項目に限る。

未実測: hermes での往復委譲の一巡と直送委譲、cursor-agent の承認待ち（申告しないため画面から裁く場面）、既存ペインの起用のうち、指定値（`label`・`tab_id`）による解決と、claude 以外のハーネスの採用。

2026-11-10 実測（実測者 = Claude Code。Rex のペインの外から rex CLI をフルパスで操作。各1回の試行）:

- 状態の申告（各ハーネスへ `Reply with OK only.` を1回送信）:

  | ハーネス | 起動時の確認ダイアログ | 入力待ち | 作業中 | 完了 |
  |---|---|---|---|---|
  | claude | 申告なし | `idle` | `working` | `done` |
  | codex | 申告なし | `idle` | `working` | `done` |
  | agy | `blocked` | `idle` | `working` | `done` |
  | grok | `blocked` | `idle` | `working` | `done` |
  | hermes | ダイアログなし | 申告なし | 申告なし | 申告なし |

- 貼り付け（Enter を送らずに入力欄の表示を確認。5種とも入力待ちで貼り付けモードは有効）:

  | ハーネス | 3行の貼り付け | 約3,000文字・37行の貼り付け |
  |---|---|---|
  | claude | 3行のまま入る | `[Pasted text #1 +36 lines]` に畳まれる |
  | codex | 3行のまま入る | `[Pasted Content 3039 chars]` に畳まれる |
  | agy | 3行のまま入る | `[Pasted text #1 +37 lines]` に畳まれる |
  | grok | 3行のまま入る | `[Pasted: 37 lines]` に畳まれる |
  | hermes | 3行のまま入る | `[[ <先頭>.. [37 lines] .. <末尾28文字> ]]` に畳まれる |

- `send`（LF 入りの3行）は5種とも3行のまま入力欄に入り、送信されなかった。
- テキスト送信の2秒後に Enter を送ると、5種とも1回で送信された。
- シェルだけのペインでの `rex split` / `send` / `send-key` / `capture` / `block ls` / `window inspect` / `block close` の動作。`block close` はプロセスが動いているペインも閉じ、戻った時点で一覧から消えている。
- Rex のアプリが表示していないセッションのペインは、分割しても 80×24 のままである。

2026-11-11 実測（実測者 = Claude Code。Rex のペインの外から、`REX_SESSION` / `REX_BLOCK` を検証用セッションのシェルのペインへ向けて `mux.sh` を実行。ハーネスは起動していない。各1回の試行）:

- `detect` / `self` / `layout` / `list` / `tabs` / `split`（right・down）/ `run` / `send` / `key` / `read`（既定・`--scrollback`）/ `wait-output` / `submit` / `close` が動いた。`split` の直後に `run` を実行しても、コマンド文字列は破棄されずに実行された。
- `submit` で zsh のプロンプトへ2行のテキストを送ると、1回の貼り付けとして入り、Enter で2行とも実行された。
- `agent-wait` の申告の読み取り: シェルスクリプトから OSC 7501 を出力して `idle` → `working` → `blocked` → `working` → `done` → `error` と申告を変え、`--until idle` / `--until working` / `--until blocked` / `--until` なしがそれぞれの状態で発火した。`--until idle` は `done` でも成立した。ルートが `blocked` で、`id` つきのレコードが `working` のとき、`blocked` を返した。
- `agent-wait` の画面静止推定: 申告の無いシェルのペインで、`MUX_REX_QUIET_MS=4000` の `--until idle` が約4秒で発火した。

2026-11-11 実測（指揮者 = Rex のペイン内の Claude Code 2.1.322 / claude-fable-5-2。Rex Beta 0.1.0、rex CLI 0.0.1793981048・api revision 11。委譲先は Claude Code 2.1.322 / claude-sonnet-5 と codex-cli 0.167.0 / gpt-6.1-sol）:

- 指揮者のペインから `detect` / `self` / `layout` / `list` / `tabs` / `split`（right・down）/ `run` / `send` / `paste` / `key` / `answer` / `read`（既定・`--scrollback`）/ `wait-output` / `submit` / `agent-wait`（`--until idle`・`--until working`・`--until` なし）/ `close` が動いた。`self` の `pane_id` は `REX_BLOCK` と一致し、`layout` の指揮者ペインの `rect`（138×51）は端末の実寸（`stty size`）と一致した。`split` の後もウィンドウの `focused_block_id` は指揮者ペインのままだった。閉じたペインは `list` から消え、閉じた ID への `close` は非0で終わった。
- `split` の直後の `layout` は、新しいペインの `rect` を 80×24 と返した（実寸は 67×24）。数十秒後の `layout` は実寸を返した。指揮者ペインの `rect` は分割の直後から実寸だった。
- 委譲の一巡（成果物置き場に報告ファイルを書くだけの作業。ハーネスごとに1回）:

  | 項目 | claude | codex |
  |---|---|---|
  | 起動（`run` と起動コマンドの cwd 指定） | 成功 | 成功 |
  | 初期ダイアログ | なし（trust 済み）。`agent-wait --until idle` は申告の `idle` で成立 | フックの確認ダイアログが出た（下記）。表示中は申告が無く、`agent-wait --until idle` は画面静止推定で成立 |
  | 受理（`submit` と `agent-wait --until working`） | 成功。`source` は `rex-program-status` | 成功。`source` は `rex-program-status` |
  | 完了の検知（`--until` なしの `agent-wait`） | `done`・`rex-program-status` | `done`・`rex-program-status` |
  | 委譲先自身による push の到達 | 指揮者の入力欄に届いた | `mux.sh` の修正後に届いた（下記） |
  | 回収 | 報告ファイルを読めた | 報告ファイルを読めた |
  | クローズ | `list` から消えた | `list` から消えた |

- codex の起動時に、フックの確認ダイアログ（"Hooks need review / 1 hook is new or changed."、選択肢 `1. Review hooks` / `2. Trust all and continue` / `3. Continue without trusting (hooks won't run)`）が出た。`answer "3"` で通過し、入力欄 "Ask Codex to do anything" が表示され、申告が `idle` になった。
- codex（`--sandbox workspace-write`）の中では `ps` を実行できず（`PermissionError: [Errno 1] Operation not permitted: 'ps'`）、`list` が失敗する。送信系サブコマンドの存在確認が `list` を使っていたため、codex からの push は「ペインが存在しない」で失敗し、codex は通信規約のとおり同じ一行を最終メッセージとして出力した。存在確認を `rex block ls` だけで行うよう `mux.sh` を修正したあと、同じ push を codex に再実行させると終了コード 0 で指揮者の入力欄に届いた（承認要求なし）。サンドボックスの中では `list` は今も失敗する。
- `submit` の Enter 吸収: 1行の指示（`Reply with OK only. (n)`）を claude と codex へ6回ずつ送り、12回すべてで `submit` が終了コード 0、`agent-wait --until working` が成立し、ターンが始まった。ブリーフの起動指示などを含めると claude 7/7、codex 8/8 で、Enter の吸収は0件だった。

2026-11-11 実測（直送委譲の可否の確認。指揮者 = Rex のペイン内の Claude Code 2.1.322 / claude-fable-5-2。委譲先 = Claude Code 2.1.322 / claude-sonnet-5、codex-cli 0.167.0 / gpt-6.1-sol high、grok 1.0.77 / grok-4.7、agy 1.5.5 / gemini-3.8-flash-high。委譲先のペインは 89 列 × 51 行。各1回の試行）:

- 送信: 各行に乱数を埋め込んだ ASCII の本文を `mux.sh submit` で送り、総行数と指定した3行の値を答えさせて照合した。claude・codex・grok は 3,000 / 12,000 / 24,000 文字、agy は 3,000 / 6,000 文字で全件一致。`submit` の所要は 1〜2 秒で、終了コードはすべて 0。
- 日本語の本文: 変更前の `paste` は、日本語だけの 10,125 文字（要求 60,092 バイト）を送れ、12,199 文字は `control message too large: encoded request is 72631 bytes, limit is 65536` で失敗した（終了コード 1）。JSON を UTF-8 のまま送るよう変更したあと、同じ 12,199 文字が通った。ASCII を約 23% 含む日本語 12,103 文字の本文を `submit` で claude へ送り、総行数と3行の値が一致した。
- 画面の種類（`rex block call -b <ペインID> modes` の `screen`）と返答の読み取り（`mux.sh read --scrollback --lines 1000`）:

  | ハーネス | `screen` | 送信本文のエコー | 短い返答（2行） | 100 行の返答 |
  |---|---|---|---|---|
  | claude | `alternate` | 3,000 文字（50 行）以上の本文では、先頭行が画面の外へ出て読めない | 先頭行のエコーと返答を切り出せた | 61〜100 行目だけ読めた。先頭行のエコーは読めない |
  | codex | `alternate` | 同上（全文を表示する） | 切り出せた | 60〜100 行目だけ読めた |
  | grok | `alternate` | 先頭3行に畳む。24,000 文字でも先頭行を読めた | 切り出せた | grok が 100 個を空白区切りの続き書きで返したため1画面に収まり、全部読めた（画面を超える返答は試せていない） |
  | agy | `primary` | 全文を表示する。6,000 文字（100 行）の先頭行を読めた | 切り出せた | 1〜100 行目をすべて読めた |

- claude のペインは、Claude Code の設定 `tui` が `fullscreen` の環境で測った。
- claude の初回の返答（ブリーフは `READY` と書くよう指示）は、画面上で `RE1` と読めた（`rex capture --format=vt` でも同じ）。以後の返答に文字の欠けは無く、原因は特定していない。
- 直送上限を超える返答（claude）: 直送上限 3,000 文字のもとで 4,000 文字以上の返答を求めると、claude は `report-1.md` を書き、`[<push ラベル>] done <パス>` の push が指揮者の入力欄に届いた。
- 作業中の承認待ち（副次観測。agy）: agy がシェル実行の承認ダイアログ（"Run this command?"、選択肢 `1. Yes, run command` / `2.` 会話内で常に許可 / `3.` 設定へ永続化 / `4. No, cancel`）で止まると、`blocked`（`kind` は `permission`、`msg` に対象コマンド）を申告し、`--until` なしの `agent-wait` が `blocked`・`rex-program-status` で発火した。`answer "4"` で拒否すると、agy はターンを中断して `idle` を申告した。承認ダイアログの表示中に送った `submit` は終了コード 3 で失敗した。

2026-11-11 実測（未実測だった項目の確認。指揮者 = Rex のペイン内の Claude Code 2.1.322 / claude-fable-5-2。委譲先 = grok 1.0.77 / grok-4.7、agy 1.5.5 / gemini-3.8-flash-high、cursor-agent 2026.09.18-9a7762b / composer-2.5、Claude Code 2.1.322 / claude-sonnet-5、codex-cli 0.167.1 / gpt-6.1-sol high。各1回の試行）:

- 往復委譲の一巡（起動・受理・完了の検知・push の到達・回収・クローズ）:

  | 項目 | grok | agy | cursor-agent |
  |---|---|---|---|
  | 初期ダイアログ | なし（trust 済み） | なし（trust 済み） | なし（`--trust`） |
  | 受理（`agent-wait --until working`） | 成立・`rex-program-status` | 成立・`rex-program-status` | 成立・`rex-quiescence` |
  | 完了の検知（`--until` なし） | `done`・`rex-program-status` | 承認待ちのたびに `blocked`、最後に `done` | `idle`・`rex-quiescence` |
  | 委譲先自身による push | 無確認で実行され、届いた | 承認ダイアログを許可すると届いた | 無確認で実行され、届いた |
  | 回収・クローズ | 成立 | 成立 | 成立 |

- cursor-agent は起動時・作業中・完了後のいずれも状態を申告しなかった（`program_status` の `records` が空）。入力待ちで貼り付けモードは有効で、3行の貼り付けは3行のまま入力欄に入り、Enter で1回の送信になった。通常の画面（`primary`）で描く。
- 作業中の承認待ちの申告と裁定:

  | ハーネス | 起動条件 | 申告（`kind` は `permission`） | 裁定 |
  |---|---|---|---|
  | claude | `--permission-mode default`（承認待ちを出すため。transports の起動コマンドは `auto`） | `blocked`。`msg` は `approve Write: <パス>` / `approve Bash: <コマンド全文>` | `answer "1"` で許可し、続行した |
  | codex | `-c approvals_reviewer=user`（同上。transports の起動コマンドは `auto_review`） | `blocked`。`msg` は無い | `answer "1"` で許可し、続行した |
  | agy | transports の起動コマンド | `blocked`。`msg` は `Approve RunCommand: <コマンド>` / `Approve WriteFile: Write: <パス>`（長いと末尾が切れる） | `answer "1"` で許可（3回）。前回の実測で `answer "4"` の拒否も確認済み |
  | grok | `--permission-mode default`（承認待ちを出すため。transports の起動コマンドでは、起動時のモードが `auto-review` になり承認待ちが出なかった） | `blocked`。`msg` は `Set t.txt permissions to 600`（シェル。コマンドの要約）/ `Allow Edit to <パス>?`（ファイル編集）。既定のモードでも、`mkdir`・リダイレクトでの書き込み・`rm -r`・`curl` は承認待ちを出さず、`chmod` とファイル編集ツールで出た | シェルは `answer "3"`（Yes, proceed）で許可し、続行した。ファイル編集は `answer "4"`（No, reject）で拒否し、ファイルは変更されず、申告は `idle` になった |

  grok の行は、利用枠の回復後に同日あらためて測った（grok 1.0.77 / grok-4.7、1回の試行）。grok 1.0.77 の承認ダイアログの選択肢は、シェルが5択（`1` always-approve ／ `2` Always allow: <コマンド> ／ `3` Yes, proceed ／ `4` No, reject ／ `5` Never allow）、ファイル編集が4択（`1` always-approve ／ `2` このセッションの編集をすべて許可 ／ `3` Yes ／ `4` No, reject）で、`transports/grok-tui.md` の3択（0.2.114 実測）と番号が違う。裁定の前に画面で番号を確かめる。

  いずれも `--until` なしの `agent-wait` が `blocked`・`rex-program-status` で発火した。`msg` は長いと切れるため、裁定の前に `mux.sh read` で対象の全文を確かめる（`arbitration.md` のとおり）。
- `error` の申告: 存在しないモデル名で起動した claude と codex は、最初のターンで `error` を申告した（claude は `msg` にエラーの文面あり、codex は `msg` なし）。grok は無料枠の上限に達したターンで `error`（`msg` に上限到達の文面）を申告した。3種とも `--until` なしの `agent-wait` が `error`・`rex-program-status` で発火した。claude と grok はターンが `working` を経ずに `error` になり、`agent-wait --until working` はタイムアウトした。`error` のあとの `--until idle` は成立しなかった（claude で確認）。
- レコードを複数持つ場合: claude がサブエージェントを1つ動かしている間、`program_status` はルートのレコード（`working`）と、`id` つきのレコード（サブエージェント。`working`）の2件を返し、サブエージェントの終了で `id` つきのレコードは消えた。ルートのレコードだけを読む実装で、ハーネス全体の状態を正しく読めた。
- バックグラウンド実行中の申告: claude に `sleep 40` を依頼すると、claude はコマンドをバックグラウンドで起動してターンを終え、`done` を申告した。約 40 秒後に自分でターンを再開し（`working`）、返答して `done` に戻った。
- 既存ペインの起用: 指揮者が起動していた claude のペイン（往復委譲を1回終えたあと）を、対応表に無い既存ペインとみなして採用した。`list` の `commands` には、claude・codex・agy・grok が `<CLI名> <引数>` の形で、cursor-agent が `/…/cursor-agent <引数>` の形で現れ、先頭の語のファイル名で5種とも一意に CLI 名を解決できた。指揮者自身のペインも `claude` として現れた。入力待ちの確認（`MUX_REX_QUIET_MS=8000` の `agent-wait --until idle` を 20 秒）は、申告のある claude のペインでは即時に、申告の無い cursor-agent のペインでは約 9 秒で成立した。採用後の委譲は、受理・承認待ちの裁定（2回）・push の到達・回収まで成立した。
