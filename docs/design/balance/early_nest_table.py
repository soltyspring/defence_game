"""Early-nest check (01-director, BALANCE_DIAGNOSIS Update 12 criterion 4).
For each round: can a no-upgrade bot destroy the enemy base before the boss spawns or before the last scripted
(non-pressure) wave starts? Usage: python docs/design/balance/early_nest_table.py <sweep json (budget none)>
Bot sims are not human playtests."""
import json, statistics as st, sys

d = json.load(open(sys.argv[1], encoding='utf-8'))
print('| round | last scripted wave (s) | boss wave (s) | policy | none wins | min win t (s) | wins before last wave | wins before boss | flag |')
print('|---|---|---|---|---|---|---|---|---|')
rounds = sorted({x['round'] for x in d['rows']})
for rid in rounds:
    r = json.load(open(f'data/rounds/{rid}.json', encoding='utf-8'))
    waves = [w for w in r['waves'] if not w.get('pressure')]
    last = max(w['at'] for w in waves)
    boss = [w['at'] for w in waves if any(s['unit'].startswith('boss_') for s in w['spawns'])]
    bt = boss[0] if boss else None
    for k in ('competent', 'casual'):
        rs = [x for x in d['rows'] if x['round'] == rid and x['kind'] == k and x['budget'] == 'none']
        w = [x for x in rs if x['won']]
        bl = sum(1 for x in w if x['t'] < last)
        bb = sum(1 for x in w if bt is not None and x['t'] < bt)
        flag = 'EARLY' if (bl or bb) else ''
        print(f"| {rid} | {last} | {bt if bt is not None else '-'} | {k} | {len(w)}/{len(rs)} | "
              f"{min(x['t'] for x in w):.0f} | {bl} | {bb if bt is not None else '-'} | {flag} |" if w else
              f"| {rid} | {last} | {bt if bt is not None else '-'} | {k} | 0/{len(rs)} | - | 0 | - | |")
