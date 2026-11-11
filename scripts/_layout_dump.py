import json, io, re, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
path = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\riska\AppData\Local\Temp\deveco\layout2.json'
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 60
d = json.load(open(path, encoding='utf-8'))
out = []
def walk(n):
    a = n.get('attributes', {})
    t = a.get('text', '') or ''
    hint = a.get('hint', '') or ''
    desc = a.get('description', '') or ''
    key = a.get('key', '') or ''
    if t or hint or desc or key:
        out.append('%s t=%r hint=%r desc=%r key=%r click=%s type=%s' % (
            a.get('bounds', ''), t[:24], hint[:24], desc[:24], key[:32],
            a.get('clickable', ''), n.get('type', '')))
    for c in n.get('children', []):
        walk(c)
walk(d)
print('\n'.join(out[:limit]))
