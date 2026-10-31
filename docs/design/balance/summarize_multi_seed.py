"""Summarize multi_seed_sim output: per round x budget wins/N, time min/median/max, worst base ratio, stars.
Usage: python docs/design/balance/summarize_multi_seed.py <in.json> [par_check]"""
import json, statistics, sys, glob

d = json.load(open(sys.argv[1], encoding='utf-8'))
par = {}
for p in glob.glob('data/rounds/r*.json'):
    r = json.load(open(p, encoding='utf-8')); par[r['id']] = r['stars']['time_3']
g = {}
for r in d['rows']:
    g.setdefault((r['round'], r['kind'], r['budget']), []).append(r)
print('warnings', d['warnings'])
print('| round | kind | budget | wins | t min/med/max (s) | par | med<=1.25par | worst base | base dmg med | stars |')
print('|---|---|---|---|---|---|---|---|---|---|')
for (rid, kind, b), rs in sorted(g.items()):
    ts = [x['t'] for x in rs]; w = sum(x['won'] for x in rs)
    med = statistics.median(ts)
    print(f"| {rid} | {kind} | {b} | {w}/{len(rs)} | {min(ts):.0f}/{med:.0f}/{max(ts):.0f} | {par[rid]} | "
          f"{'yes' if med <= 1.25 * par[rid] else 'NO'} | {min(x['pbase'] for x in rs):.2f} | "
          f"{statistics.median(x['base_dmg'] for x in rs):.0f} | {','.join(str(x['stars']) for x in rs)} |")
