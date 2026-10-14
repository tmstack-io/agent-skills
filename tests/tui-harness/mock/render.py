"""送信テキストを TUI 入力欄・シェル入力行の折り返し表示に見立てて画面ファイルへ追記する。

使い方: render.py <画面ファイル> <テキスト>
環境変数 MOCK_MODE: word（空白位置で折り返し、継続行に 2 桁インデント）/ hard（幅で切る、継続行に
2 桁インデント）/ shell（幅で切る、インデントなし。シェルの入力行）/ squash（空白を消して 1 行）/
box（hard と同じ折り返しで、各行を枠線 │ で囲む）/ headonly（hard と同じ折り返しで、先頭 5 行だけ
描く。取り込みが途中で止まった入力欄）
複数行のテキストは改行ごとに区切り、2 行目以降を継続行として折り返す。
環境変数 MOCK_WIDTH: 1 行の幅（既定 60）
"""
import os
import sys

path, text = sys.argv[1], sys.argv[2]
mode = os.environ.get("MOCK_MODE", "word")
width = int(os.environ.get("MOCK_WIDTH", "60"))
prompt, indent = ("$ ", "") if mode == "shell" else ("❯ ", "  ")
if mode == "squash":
    text = text.replace(" ", "")
out = []
for k, line in enumerate(text.split("\n")):
    line = (prompt if k == 0 else indent) + line
    if mode == "word":
        cur = ""
        for word in line.split(" "):
            cand = f"{cur} {word}" if cur else word
            if len(cand) > width and cur:
                out.append(cur)
                cur = indent + word
            else:
                cur = cand
        out.append(cur)
    elif mode in ("hard", "shell", "box", "headonly"):
        first = True
        while line:
            w = width if first else width - len(indent)
            out.append(("" if first else indent) + line[:w])
            line, first = line[w:], False
    else:
        out.append(line)
if mode == "box":
    out = [f"│ {row.ljust(width)} │" for row in out]
elif mode == "headonly":
    out = out[:5]
with open(path, "a", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
