# tui-harness cmux バックエンドの差分（正本）

`mux.sh detect` が `backend=cmux` を返した場合に、ペイン配置を始める前に読み、SKILL.md の該当節へ上書き適用する読み替え規則。（検証対象は cmux 0.64 系。`python3` 必須。「実測検証済み」は末尾に列挙した実測範囲に限る。指揮者: Claude Code）

## ペイン ID

ペイン ID は surface の UUID を正とする。**UUID は増減で振り直されない**（振り直されるのは外部インターフェースに使わない `surface:N` 形式の ref）。SKILL.md「ペイン ID の揮発性」の直前 `list` 取り直しはバックエンド共通の安全手順として維持する — herdr の ID 振り直しに固有の別ハーネス誤送信リスクは cmux には無いが、対応表の鮮度確認として同じ手順を踏む。

## (1) agent-wait の代替と `--until`

エージェント状態 API が無いため、`agent-wait` は**画面静止推定**（既定 15 秒の静止で idle、サンプル間の画面変化で working。閾値は環境変数 `MUX_CMUX_QUIET_MS`）と**通知高速経路**（対象 surface 宛の新着通知で即 idle 発火。cmux のエージェント連携が効いているハーネスで発火し、効いていなくても静止推定で動作する）で代替する。**意味を持つ `--until` は `working` と `idle` のみ** — done / blocked への到達は確認できないため `--until done` / `--until blocked` は使わず、`--until` なしで発火させてSKILL.md「応答の受け取り」の三分類が画面から裁く。

## (2) 受理判定

`agent_session` は全ハーネスで報告されない — 受理判定は working 遷移のみで手順3へ進む。

## (3) list のフィールドと既存ペインの起用の読み替え

`list` の各ペインは `agent` / `agent_status` を持たず、代わりに `commands`（surface 配下プロセスのコマンドライン一覧）を持つ。`existing-pane.md` の手順1〜3は次のとおり読み替える — 候補列挙（手順1）は `commands` のいずれかにカタログ CLI 名が現れるペインを対象にし、起用ゲートと CLI の確定（手順2・3）は `commands` から**一意に**解決できたカタログ CLI 名で行う（0件・複数のカタログ CLI 名が現れた場合は採用せず、照合結果を散文提示で示す）。idle の確認は `agent-wait --until idle` の短時間実行（例: `MUX_CMUX_QUIET_MS=8000` で 20 秒）が idle を返すことで代替する。

## (4) tabs / layout

`tabs` はワークスペース一覧（`label` = ワークスペース名）、`layout` は `list-panes` 形式（`columns` / `rows` をセル寸法の width / height として読む）。

## (5) self / layout の前提

`self` は `CMUX_SURFACE_ID` / `CMUX_WORKSPACE_ID`（cmux が端末のシェルへ自動設定する env。名称の根拠は cmux CLI ヘルプの Environment 節）から組み立てる — どちらかが未設定なら非0終了し、呼び出し側はSKILL.md「ペイン配置」手順1と `existing-pane.md` 手順1の self 非0分岐に従う。self の `tab_id` にはワークスペース ID を充てる（list / tabs と同じ ID 空間に統一）。`layout` は自ワークスペースへ固定するため `--workspace` に `CMUX_WORKSPACE_ID` を渡す（未設定なら非0終了）。

## 実測範囲と未実測

cmux での実測範囲: mux.sh 全サブコマンド（`self` と、`layout` の自ワークスペース固定を除く）、codex / grok の委譲一巡（起動・trust 通過・受理・完了検知・回収・クローズ）、委譲先（codex）自身による通信規約の push 送達。

未実測: `self`（env 組み立ての cmux セッション内動作）、`layout` の自ワークスペース固定（`--workspace` 指定での挙動）、blocked（承認ダイアログ）場面の安全網検知と裁定、既存ペインの起用（`existing-pane.md`）の cmux 代替判定（`commands` 照合・短時間 idle 判定）、claude / cursor-agent / agy / hermes の各初期ダイアログ（transports の実測記録は herdr 指揮者のもの）。
