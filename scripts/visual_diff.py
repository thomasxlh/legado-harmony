#!/usr/bin/env python3
"""对比两组阅读页截图，输出逐图差异指标。

用法：python scripts/visual_diff.py <基线目录> <新目录>

判定标准（阅读页是纯文字渲染，允许极小抗锯齿差异）：
  - 平均绝对差 <= 0.5  且 差异像素占比 <= 0.5%  -> IDENTICAL
  - 平均绝对差 <= 2.0  且 差异像素占比 <= 3.0%  -> MINOR
  - 否则                                          -> CHANGED（需人工看图）
"""

import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

try:
    from PIL import Image, ImageChops
except ImportError:
    print("Pillow not available", file=sys.stderr)
    sys.exit(2)


def _crop(img):
    """裁掉状态栏（含时钟）和底部系统区域，只比较阅读内容。"""
    w, h = img.size
    top = int(h * 0.030)      # 状态栏
    bottom = int(h * 0.965)   # 底部导航条
    return img.crop((0, top, w, bottom))


def compare(a_path, b_path):
    a = _crop(Image.open(a_path).convert("RGB"))
    b = _crop(Image.open(b_path).convert("RGB"))
    if a.size != b.size:
        return {"status": "SIZE_MISMATCH", "detail": f"{a.size} vs {b.size}"}
    diff = ImageChops.difference(a, b)
    gray = diff.convert("L")
    hist = gray.histogram()
    total = a.size[0] * a.size[1]
    # 以 8/255 为阈值区分抗锯齿噪声和真实差异
    changed = sum(hist[8:])
    mean = sum(i * n for i, n in enumerate(hist)) / total if total else 0.0
    ratio = changed / total if total else 0.0
    if mean <= 0.5 and ratio <= 0.005:
        status = "IDENTICAL"
    elif mean <= 2.0 and ratio <= 0.03:
        status = "MINOR"
    else:
        status = "CHANGED"
    return {
        "status": status,
        "mean": round(mean, 4),
        "ratio": round(ratio * 100, 4),
        "changed_px": changed,
        "total_px": total,
    }


def main():
    if len(sys.argv) != 3:
        print("usage: visual_diff.py <baselineDir> <newDir>", file=sys.stderr)
        return 2
    base_dir, new_dir = sys.argv[1], sys.argv[2]
    names = sorted(
        f for f in os.listdir(base_dir)
        if f.lower().endswith((".png", ".jpeg", ".jpg"))
    )
    if not names:
        print(f"no images in {base_dir}")
        return 2
    worst = "IDENTICAL"
    order = {"IDENTICAL": 0, "MINOR": 1, "CHANGED": 2, "SIZE_MISMATCH": 3, "MISSING": 4}
    print(f"{'image':24s} {'status':14s} {'mean':>8s} {'changed%':>10s}")
    print("-" * 60)
    for name in names:
        b_path = os.path.join(base_dir, name)
        n_path = os.path.join(new_dir, name)
        if not os.path.exists(n_path):
            print(f"{name:24s} {'MISSING':14s} {'-':>8s} {'-':>10s}")
            worst = "MISSING"
            continue
        r = compare(b_path, n_path)
        if r["status"] == "SIZE_MISMATCH":
            print(f"{name:24s} {'SIZE_MISMATCH':14s} {r['detail']}")
            worst = "SIZE_MISMATCH"
            continue
        print(
            f"{name:24s} {r['status']:14s} {r['mean']:8.4f} "
            f"{r['ratio']:9.4f}%"
        )
        if order.get(r["status"], 9) > order.get(worst, 0):
            worst = r["status"]
    print("-" * 60)
    print(f"WORST: {worst}")
    return 0 if worst in ("IDENTICAL", "MINOR") else 1


if __name__ == "__main__":
    sys.exit(main())
