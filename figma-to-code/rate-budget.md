# figma-to-code Figma MCP のツールコール上限（正本）

SKILL.md「レート予算」節の「予算の立て方」から、Step 0 手順 3 で概算を上限と突き合わせるときに読まれる。

Figma MCP のツールコールには分単位と日/月単位の二段構えの上限がある（2026-08 時点の公式値。上限は変わりうるため、制限に当たったら出典を確認する。出典: https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/ ）:

| シート種別 | 分あたり | 日/月あたり |
|---|---|---|
| View / Collab 席（全プラン） | — | 月 6 回 |
| Dev / Full 席・Starter | 10 回/分 | 200 回/日 |
| Dev / Full 席・Professional | 15 回/分 | 200 回/日 |
| Dev / Full 席・Organization | 20 回/分 | 600 回/日 |
| Dev / Full 席・Enterprise | 未確認（Organization と同水準と推定） | 600 回/日 |

- `whoami` はカウント対象外のため、プラン・シート種別の確認に自由に使える
- Starter プランのチームに属するファイルへの呼び出しは、呼び出し側が他プランの有償席でも月 6 回に制限される
- 残量を事前確認する手段は無く、日次リセットの正確な時刻は非公開（枯渇したら実務上は日付が変わるのを待つ）
- `get_design_context` は応答が最も重く、実行ハーネスのツール出力上限を超えることがある（上限を拡げられるハーネスもある。Claude Code では環境変数 MAX_MCP_OUTPUT_TOKENS）
