#!/usr/bin/env python3
"""Reusable pure-function scanner for ReadBook.ets.

Unlike the earlier one-off scanners, this one locates each method's REAL end
by brace matching (aware of line/block comments, strings, template literals),
so it never overruns into generator markers or the next method's doc comment.

Read-only: prints a JSON report to stdout (or --out FILE). No source edits.

Usage:
  python scripts/scan_pure_fns.py [--src PATH] [--out REPORT.json]
"""
import sys, io, re, json, argparse

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

DEF_RE = re.compile(r"^  (?:(?:private|public|protected|static|async|override|get|set|abstract)\s+)*([\w$]+)\s*\(")
ANCHOR_RE = re.compile(r"^  (?:async\s+)?([\w$]+)\s*\(")
KEYWORDS = {"if", "for", "while", "switch", "catch", "return", "new", "function",
            "constructor", "typeof", "instanceof", "void", "delete", "in", "of", "do", "else", "try"}

# identifiers that are ArkUI / ArkTS / JS globals (no import needed)
GLOBALS = {
    "Math", "JSON", "Object", "Array", "String", "Number", "Boolean", "Map", "Set",
    "Promise", "Date", "RegExp", "Error", "parseInt", "parseFloat", "isNaN", "console",
    "setTimeout", "clearTimeout", "setInterval", "clearInterval", "encodeURIComponent",
    "decodeURIComponent", "AppStorage", "LocalStorage", "px2vp", "vp2px", "fp2px",
    "GestureEvent", "Length", "Resource", "Color", "undefined", "null", "NaN",
    "Infinity", "getContext", "router", "window", "promptAction", "BusinessError",
}
PRIM = {"number", "string", "boolean", "void", "any", "unknown", "object", "never",
        "Number", "String", "Boolean", "Array", "Promise", "Map", "Set", "Record",
        "Uint8Array", "ArrayBuffer", "Int32Array", "Float32Array", "Int16Array"}


def strip_for_ident(src):
    """Blank comments and string/template literal TEXT while preserving code,
    including expressions inside template ${...}. A proper mode stack handles
    nested templates, comments and strings inside expressions."""
    n = len(src)
    out = []
    i = 0
    # frame = [mode, brace_depth]; modes: CODE EXPR LINE_COMMENT BLOCK_COMMENT SQ DQ TPL
    stack = [["CODE", 0]]
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        mode = stack[-1][0]
        if mode == "CODE" or mode == "EXPR":
            if c == "/" and nxt == "/":
                out.append("  "); i += 2; stack.append(["LINE_COMMENT", 0]); continue
            if c == "/" and nxt == "*":
                out.append("  "); i += 2; stack.append(["BLOCK_COMMENT", 0]); continue
            if c == "'":
                out.append(" "); i += 1; stack.append(["SQ", 0]); continue
            if c == '"':
                out.append(" "); i += 1; stack.append(["DQ", 0]); continue
            if c == "`":
                out.append(" "); i += 1; stack.append(["TPL", 0]); continue
            if mode == "EXPR":
                if c == "{":
                    stack[-1][1] += 1; out.append(c); i += 1; continue
                if c == "}":
                    stack[-1][1] -= 1
                    if stack[-1][1] == 0:
                        stack.pop(); out.append(" "); i += 1; continue
                    out.append(c); i += 1; continue
            out.append(c); i += 1; continue
        if mode == "LINE_COMMENT":
            if c == "\n":
                out.append("\n"); i += 1; stack.pop(); continue
            out.append(" "); i += 1; continue
        if mode == "BLOCK_COMMENT":
            if c == "*" and nxt == "/":
                out.append("  "); i += 2; stack.pop(); continue
            out.append("\n" if c == "\n" else " "); i += 1; continue
        if mode in ("SQ", "DQ"):
            q = "'" if mode == "SQ" else '"'
            if c == "\\" and i + 1 < n:
                out.append("  "); i += 2; continue
            if c == q:
                out.append(" "); i += 1; stack.pop(); continue
            out.append("\n" if c == "\n" else " "); i += 1; continue
        if mode == "TPL":
            if c == "\\" and i + 1 < n:
                out.append("  "); i += 2; continue
            if c == "`":
                out.append(" "); i += 1; stack.pop(); continue
            if c == "$" and nxt == "{":
                out.append("  "); i += 2; stack.append(["EXPR", 1]); continue
            out.append("\n" if c == "\n" else " "); i += 1; continue
    return "".join(out)


def brace_end(lines, start):
    """Return index of the line containing the matching close brace for a method
    whose signature line is `lines[start]` (0-based). Brace/string/comment aware."""
    depth = 0
    seen = False
    for k in range(start, len(lines)):
        s = strip_for_ident(lines[k])
        for ch in s:
            if ch == "{":
                depth += 1; seen = True
            elif ch == "}":
                depth -= 1
                if seen and depth == 0:
                    return k
    return -1


def free_identifiers(text, params, locals_, known):
    stripped = strip_for_ident(text)
    stripped = re.sub(r"\.([A-Za-z_$][\w$]*)", ".@", stripped)  # member access
    stripped = re.sub(r"([A-Za-z_$][\w$]*)\s*:", "@:", stripped)  # object key / label
    ids = set(re.findall(r"\b([A-Za-z_$][\w$]*)\b", stripped))
    return sorted(i for i in ids
                  if i not in params and i not in locals_
                  and i not in known and i not in GLOBALS and i not in PRIM
                  and i not in KEYWORDS and not i[0].isdigit())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="entry/src/main/ets/pages/ReadBook.ets")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    raw = open(args.src, "rb").read().decode("utf-8")
    lines = raw.split("\n")

    # top-level names (imports + top-level const/class/function/interface/enum/type)
    top = set()
    for l in lines:
        if l.startswith("import "):
            for m in re.finditer(r"\b([A-Za-z_$][\w$]*)\b", l):
                w = m.group(1)
                if w not in ("import", "from", "as", "default", "type"):
                    top.add(w)
        else:
            m = re.match(r"(?:export\s+)?(?:default\s+)?(?:const|let|var|class|function|interface|enum|type|struct)\s+([\w$]+)", l)
            if m: top.add(m.group(1))
    known = top | GLOBALS | PRIM

    # import table: symbol -> path
    sym2path = {}
    for m in re.finditer(r"import\s*\{([^}]*)\}\s*from\s*'([^']+)';", raw, re.S):
        path = m.group(2)
        for s in m.group(1).split(","):
            s = s.strip().split(" as ")[-1].strip()
            if s: sym2path[s] = path

    # find @Builder decorator lines (2-space indented) so we can exclude them
    builder_next = set()
    for idx, l in enumerate(lines):
        if l.strip().startswith("@Builder") or re.match(r"^  @Builder", l):
            # the decorated method is the next method-def line
            for k2 in range(idx + 1, min(idx + 6, len(lines))):
                if ANCHOR_RE.match(lines[k2]):
                    builder_next.add(k2); break

    methods = []
    for i, l in enumerate(lines):
        m = DEF_RE.match(l)
        if not m: continue
        name = m.group(1)
        if name in KEYWORDS: continue
        end = brace_end(lines, i)
        if end < 0 or end <= i:
            continue
        body = "\n".join(lines[i:end + 1])
        has_this = "this." in strip_for_ident(body)
        sig = l.strip()
        # params: crude split of the (...) on the signature line (may span lines)
        sig_all = l
        j = i
        while "(" in sig_all and ")" not in sig_all and j + 1 < end:
            j += 1; sig_all += " " + lines[j].strip()
        pm = re.search(r"\(([^)]*)\)", sig_all)
        params = set()
        if pm:
            for p in pm.group(1).split(","):
                pm2 = re.search(r"([\w$]+)\s*(?::|\?|=|$)", p.strip())
                if pm2: params.add(pm2.group(1))
        locals_ = set(re.findall(r"\b(?:const|let|var)\s+([\w$]+)", body))
        locals_ |= set(re.findall(r"\(([^)]*)\)\s*=>", body))
        unknown = free_identifiers(body, params, locals_, known)
        needs_import = sorted({s for s in sym2path if re.search(r"\b" + re.escape(s) + r"\b", body)})
        methods.append({
            "name": name, "start": i + 1, "end": end + 1, "lines": end - i + 1,
            "sig": sig, "has_this": has_this, "is_builder": i in builder_next,
            "params": sorted(params), "needs_import": needs_import, "unknown": unknown,
        })

    pure = [x for x in methods if not x["has_this"] and not x["is_builder"]]
    report = {
        "src": args.src, "total_lines": len(lines),
        "method_count": len(methods), "builder_count": sum(1 for x in methods if x["is_builder"]),
        "no_this_count": sum(1 for x in methods if not x["has_this"]),
        "pure_count": len(pure),
        "pure": pure,
        "has_this_no_unknown": [x["name"] for x in methods if x["has_this"] and not x["unknown"]],
        "symbol_imports": sym2path,
    }
    out = json.dumps(report, ensure_ascii=False, indent=1)
    if args.out:
        open(args.out, "w", encoding="utf-8", newline="\n").write(out)
        print("wrote", args.out)
    else:
        print(out)


if __name__ == "__main__":
    main()
