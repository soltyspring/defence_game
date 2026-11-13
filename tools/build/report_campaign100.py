"""Summarize reproducible balance probes without copying private runtime logs."""
import collections
import csv
import json
import statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/design/balance'
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8-sig'))
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    meta=read('data/meta.json')
    products=meta['iap_catalog']['products']
    rows=[];earned=0
    for n in range(1,101):
        r=read(f'data/rounds/r{n:02}.json')
        rows.append({'round':n,'hp_multiplier':r['enemy_scaling']['hp'],'attack_multiplier':r['enemy_scaling']['atk'],
          'first_clear_gold':r['reward']['first_clear_coins'],'repeat_gold':r['reward']['coins'],
          'gold_before_round':earned,'paid_gold_available':sum(p['gold'] for p in products if p['target_round']<=n),
          'paid_krw_cumulative':sum(p['price_krw'] for p in products if p['target_round']<=n),
          'gate':n in [p['target_round'] for p in products]})
        earned+=r['reward']['first_clear_coins']+r['reward'].get('three_star_bonus_coins',0)
    with (OUT/'campaign100_economy.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
    path=ROOT/'build/campaign100/final-balance.json'
    if path.exists():
        data=json.loads(path.read_text(encoding='utf-8-sig'));groups=collections.defaultdict(list)
        for r in data['rows']:groups[(r['round'],r['cohort'],r['skill'])].append(r)
        summary=[]
        for (n,cohort,skill),rs in sorted(groups.items()):
            summary.append({'round':n,'cohort':cohort,'skill':skill,'wins':sum(r['won'] for r in rs),'runs':len(rs),
                            'median_seconds':round(statistics.median(r['seconds'] for r in rs),1),
                            'gold':rs[0]['paid_gold'],'levels':rs[0]['upgrades']})
        (OUT/'campaign100_validation.json').write_text(json.dumps({'assumptions':data['assumptions'],'summary':summary},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Campaign100 economy report:',len(rows),'rounds')
    journey=ROOT/'build/campaign100/journey.json'
    if journey.exists():
        (OUT/'campaign100_journey.json').write_text(journey.read_text(encoding='utf-8-sig'),encoding='utf-8')
if __name__=='__main__':main()
