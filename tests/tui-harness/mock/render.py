"""送信テキストを TUI 入力欄・シェル入力行の折り返し表示に見立てて画面ファイルへ追記する。

使い方: render.py <画面ファイル> <テキスト>
環境変数 MOCK_MODE: word（空白位置で折り返し、継続行に 2 桁インデント）/ hard（幅で切る、継続行に
2 桁インデント）/ shell（幅で切る、インデントなし。シェルの入力行）/ squash（空白を消して 1 行）
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
line, out = prompt + text, []
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
elif mode in ("hard", "shell"):
    first = True
    while line:
        w = width if first else width - len(indent)
        out.append(("" if first else indent) + line[:w])
        line, first = line[w:], False
else:
    out.append(line)
with open(path, "a", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
