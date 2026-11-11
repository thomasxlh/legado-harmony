#!/usr/bin/env python3
"""把 uitest dumpLayout 的 JSON 拍平成一行文本，供 shell 做断言。

用法：python scripts/device_screen_text.py <layout.json> [子串过滤]

输出用 UTF-8；Windows 控制台默认 GBK，界面里的箭头等字符会直接炸掉 print，
所以这里必须显式包一层 TextIOWrapper。
"""

import io
import json
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


def main():
    if len(sys.argv) < 2:
        print("usage: device_screen_text.py <layout.json> [filter]", file=sys.stderr)
        return 2
    path = sys.argv[1]
    needle = sys.argv[2] if len(sys.argv) > 2 else ""
    try:
        with open(path, encoding="utf-8") as f:
            root = json.load(f)
    except Exception:
        print("")
        return 0

    texts = []

    def walk(node):
        attrs = node.get("attributes", {})
        for key in ("text", "accessibilityText", "description"):
            value = attrs.get(key)
            if value:
                texts.append(str(value))
        for child in node.get("children", []):
            walk(child)

    walk(root)
    if needle:
        texts = [t for t in texts if needle in t]
    print(" | ".join(texts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
