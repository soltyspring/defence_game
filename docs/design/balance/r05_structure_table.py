"""r05 structure experiment table (01-director). Usage: python docs/design/balance/r05_structure_table.py <name=json> ...
Criteria (BALANCE_DIAGNOSIS Update 10): LOW median <= 325 s both bots; casual LOW >= 7/10; none 0/10 both bots;
competent LOW median end base <= 0.80 and median time after boss death >= 30 s (not too easy); share of LOW losses
before the boss dies (reported). Bot sims are not human playtests."""
import json, statistics as st, sys

def med(a):
    return st.median(a) if a else float('nan')

print('| variant | casual LOW W | competent LOW W | none W (cas/comp) | LOW median t cas/comp (s) | comp LOW end base med | comp LOW after-boss med (s) | LOW losses before boss death | pass |')
print('|---|---|---|---|---|---|---|---|---|')
for arg in sys.argv[1:]:
    name, path = arg.split('=', 1)
    d = json.load(open(path, encoding='utf-8'))
    g = lambda k, b: [x for x in d['rows'] if x['kind'] == k and x['budget'] == b]
    cl, ml, cn, mn = g('casual', 'low'), g('competent', 'low'), g('casual', 'none'), g('competent', 'none')
    W = lambda rs: sum(x['won'] for x in rs)
    tmed = lambda rs: med([x['t'] for x in rs if x['won']])
    after = [x['t'] - x['boss_dead_t'] for x in ml if x['won'] and x['boss_dead_t'] > 0]
    losses = [x for x in cl + ml if not x['won']]
    before = [x for x in losses if x['boss_dead_t'] < 0 or x['boss_dead_t'] > x['t']]
    endb = med([x['pbase'] for x in ml])
    ok = (tmed(cl) <= 325 and tmed(ml) <= 325 and W(cl) >= 7 and W(cn) == 0 and W(mn) == 0
          and endb <= 0.80 and med(after) >= 30)
    print(f"| {name} | {W(cl)}/{len(cl)} | {W(ml)}/{len(ml)} | {W(cn)}/{len(cn)} / {W(mn)}/{len(mn)} | "
          f"{tmed(cl):.0f} / {tmed(ml):.0f} | {endb:.2f} | {med(after):.0f} | {len(before)}/{len(losses)} | {'PASS' if ok else 'fail'} |")
