"""Classify Ops functions by how they use the whole-page `page` reference.

PURE-SCALAR: every `page.X` is a plain field read (never a call `page.X(`,
never a write), and `page` is never forwarded bare to another function.
DEAD-PAGE : `page` param present but never referenced at all.

These are safe to convert to explicit scalar parameters, which is the
goal's "state boundary" pilot: domain functions stop seeing the whole page.
"""
import re, io, sys, glob, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

FUNC_RE = re.compile(r'^export (?:async )?function ([\w$]+)\s*\(')

def body_of(lines, starts, k):
    s = starts[k][0]
    e = starts[k+1][0] if k+1 < len(starts) else len(lines)
    return lines[s:e], lines[s]

def classify(body, sig):
    txt = '\n'.join(body)
    if 'page: ReadBookPage' not in sig:
        return None, []
    # strip the signature line to avoid counting the param declaration
    only_body = '\n'.join(body[1:])
    if not re.search(r'\bpage\b', only_body):
        return 'DEAD-PAGE', []
    # bare page forwarding (e.g. `Ops.foo(page, ...)` or `foo(page)`)
    fwd = re.findall(r'\bpage\s*[,)]', only_body)
    # writes
    writes = re.findall(r'\bpage\.([\w$]+)\s*(?:=[^=]|\+\+|--|\+=|-=|\|\|=|&&=)', only_body)
    # calls on page
    calls = re.findall(r'\bpage\.([\w$]+)\s*\(', only_body)
    # all member refs
    refs = sorted(set(re.findall(r'\bpage\.([\w$]+)', only_body)))
    if fwd or writes or calls:
        return 'COUPLED', refs
    return 'PURE-SCALAR', refs

allrows = []
for path in sorted(glob.glob('entry/src/main/ets/reader/*Ops.ets')):
    lines = open(path, encoding='utf-8').read().split('\n')
    starts = [(i, m.group(1)) for i, ln in enumerate(lines) if (m := FUNC_RE.match(ln))]
    for k in range(len(starts)):
        body, sig = body_of(lines, starts, k)
        kind, refs = classify(body, sig)
        if kind in ('PURE-SCALAR', 'DEAD-PAGE'):
            allrows.append((os.path.basename(path), starts[k][1], kind, refs, len(body), sig.strip()))

for f in sorted(set(r[0] for r in allrows)):
    rs = [r for r in allrows if r[0] == f]
    ps = [r for r in rs if r[2] == 'PURE-SCALAR']
    dp = [r for r in rs if r[2] == 'DEAD-PAGE']
    print(f'=== {f}: PURE-SCALAR={len(ps)} DEAD-PAGE={len(dp)} ===')
    print('  PURE-SCALAR:')
    for r in ps:
        print(f'    {r[1]:56s} refs={r[3]}  lines={r[4]}')
    print('  DEAD-PAGE:')
    for r in dp:
        print(f'    {r[1]:56s} lines={r[4]}  sig={r[5][:90]}')
    print()
