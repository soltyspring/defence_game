"""Reproducible extension. Run once on the committed 40-round baseline."""
import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE_REF = '28905c1'
def read(path):
    # Immutable input: rerunning never compounds gates twice or duplicates levels.
    return json.loads(subprocess.check_output(['git','show',f'{BASE_REF}:{path}'],cwd=ROOT).decode('utf-8-sig'))
def write(path, obj):
    (ROOT / path).parent.mkdir(parents=True, exist_ok=True)
    (ROOT / path).write_text(json.dumps(obj, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

GATES = [23, 42, 61, 79, 96]
# gold to recruit each expansion character once its round is reached: about 1.5 first clears of that round,
# ~16% of the first-clear gold earned in the ten rounds before it (7,900 in total, 6% of R1-100)
RECRUIT = {'baguette': 1000, 'macaron': 1200, 'chili': 1500, 'donut': 1800, 'waffle': 2400}

NEW = [
    # id, name, role, unlock, cost, cd, hp, atk, interval, range, speed, armor, splash, kb, structure
    ('baguette','바게트','장창 · 근접 선제 타격',30,65,5,155,23,1.25,48,33,1,0,8,1),
    ('macaron','마카롱','저격 · 강한 단일 공격',40,95,8,65,62,2.4,180,26,0,0,0,0.65),
    ('chili','고추빵','화염 · 밀집 적 광역 공격',50,100,9,110,24,1.8,105,29,1,46,0,0.7),
    ('donut','도넛','수호 · 중장갑 전선 유지',60,100,9,650,8,1.6,20,21,7,0,18,0.7),
    ('waffle','와플','공성 · 기지 파괴 특화',70,145,14,200,48,2.8,165,20,2,18,8,4.2),
]

def main():
    tuning_path = ROOT/'data/campaign100_tuning.json'
    tuning = json.loads(tuning_path.read_text(encoding='utf-8')) if tuning_path.exists() else {}
    units = read('data/units/units.json')['units']
    base = next(u for u in units if u['id']=='melee_basic')
    extra=[]
    for uid,name,role,unlock,cost,cd,hp,atk,interval,reach,speed,armor,splash,kb,structure in NEW:
        u = dict(base)
        u.update(id=uid,name=name,name_key=f'unit.{uid}.name',desc_key=f'unit.{uid}.desc',
                 unlock_round=unlock,recruit_cost=RECRUIT[uid],cost=cost,cooldown=cd,hp=hp,atk=atk,atk_interval=interval,
                 range=reach,speed=speed,armor=armor,splash=splash,knockback=kb,structure_mult=structure,
                 anim_set=uid,hit_frame=2,role=role,tags=[role.split(' · ')[0]],
                 attack_type='melee' if reach<60 else 'ranged',projectile='' if reach<60 else 'rock' if uid=='waffle' else 'arrow')
        extra.append(u)
    write('data/units/roster_expansion.json',{'schema_version':2,'units':extra})
    for lang in ['ko','en']:
        text = read(f'data/text/{lang}.json')
        for u in extra:
            text['strings'][u['name_key']] = u['name'] if lang=='ko' else u['id'].capitalize()
            text['strings'][u['desc_key']] = u['role'] if lang=='ko' else {'baguette':'Long reach melee','macaron':'Long range single target','chili':'Area damage','donut':'Armored frontline','waffle':'Structure specialist'}[u['id']]
        for n in range(41,101):
            text['strings'][f'round.r{n:02}.name'] = f'{"성장 관문" if n in GATES else "원정"} {n}' if lang=='ko' else f'{"Growth gate" if n in GATES else "Expedition"} {n}'
        labels={
          'roster.title':('편성','Squad'),'roster.save':('편성 저장','Save squad'),
          'roster.heading':('출전 %d / 5','Squad %d / 5'),'roster.hint':('카드를 눌러 선택 · 한 번에 최대 5종 출전','Tap to select · Bring up to 5 types'),
          'roster.full':('최대 5종입니다. 먼저 한 종을 빼 주세요.','Remove one type before adding another.'),
          'roster.unlock':('R%d 해금','R%d unlock'),'roster.cost':('밀가루 %d','Flour %d'),
          'roster.failed':('저장하지 못했습니다. 다시 시도해 주세요.','Save failed. Please retry.'),
          'shop.growth':('성장 팩','Growth packs'),'shop.regular':('일반 골드','Gold packs'),
          'shop.growth_price':('%s원 · %s 골드','KRW %s · %s gold'),
          'shop.growth_name':('R%d 원정 지원','R%d expedition'),
          'shop.owned':('이미 받은 성장 팩입니다.','Already claimed.'),'shop.locked':('해금 라운드에 도달하면 받을 수 있습니다.','Reach the unlock round first.'),
        }
        for key,values in labels.items():text['strings'][key]=values[0 if lang=='ko' else 1]
        write(f'data/text/{lang}.json',text)
    meta = read('data/meta.json')
    meta['upgrades'] = [u for u in meta['upgrades'] if u['id'] not in ['up_'+v[0] for v in NEW]]
    for u in extra:
        template=json.loads(json.dumps(meta['upgrades'][0]))
        template.update(id='up_'+u['id'],target='unit:'+u['id'])
        meta['upgrades'].append(template)
    for u in meta['upgrades']:
        u['costs'] = u['costs'][:8 if u['id']!='up_worker' else 7]
        old_max=len(u['costs'])+1
        u['max_level']=40
        start=u['costs'][-1]
        for level in range(old_max+1,41):
            u['costs'].append(int(round(start*1.115**(level-old_max)/10)*10))
        u['level_unlock_rounds']={k:v for k,v in u['level_unlock_rounds'].items() if int(k)<=old_max}
        for level in range(old_max+1,41):
            u['level_unlock_rounds'][str(level)]=max(26, 20+(level-10)*2)
        # Existing levels retain exactly the old stats; late levels compound.
        u['compound_after_level']=9
        u['compound_rate']=0.06
    meta['upgrade_rules']='Levels 1–9 retain additive stats; HP/ATK gain another x1.06 per level above 9. Resource upgrades remain additive. Level cap 40.'
    meta['iap_catalog']={'enabled':False,'note':'Design prices in KRW, preview only. No real billing provider. Gates are public round rules, independent of purchases.', 'products':[
        {'id':f'growth_{gate}','price_krw':price,'gold':gold,'unlock_round':gate-2,'target_round':gate,'purchase_limit':1}
        for gate,price,gold in zip(GATES,[3000,8000,12000,16000,22000],[6000,18000,30000,44000,64000])]}
    write('data/meta.json',meta)
    # Existing mechanics / boss IDs preserved. Later chapters revisit the four biomes with mixed armies.
    for n in range(1,101):
        template_n=n if n<=40 else 21+(n-41)%20
        r=read(f'data/rounds/r{template_n:02}.json')
        if n>40:
            r.update(id=f'r{n:02}',index=n,chapter=(n-1)//10+1,name=f'{"성장 관문" if n in GATES else "원정"} {n}',name_key=f'round.r{n:02}.name')
            r['enemy_scaling']={'hp':round(1.82*1.027**(n-40),4),'atk':round(1.442*1.020**(n-40),4)}
            r['enemy_base_hp']=round(3200*1.024**(n-40))
            r['player_base_hp']=round(2850*1.012**(n-40))
            r['reward']={'coins':round(280*1.022**(n-40)),'first_clear_coins':round(780*1.025**(n-40)),'three_star_bonus_coins':round(180*1.02**(n-40))}
            r['stars']['time_3']=360
            r['tutorial']=[]

        # Permanent round progression starts after the first growth gate.
        if n > 23:
            early_steps=min(n-23,17)
            r['enemy_scaling']['hp']=round(r['enemy_scaling']['hp']*1.018**early_steps,4)
            r['enemy_scaling']['atk']=round(r['enemy_scaling']['atk']*1.012**early_steps,4)
        if n > 40: r['challenge']=False
        if n >= 41 or n in GATES: r['growth_gate']=n in GATES
        if n in GATES:
            r['enemy_scaling']={k:round(v*(1.28 if k=='hp' else 1.16),4) for k,v in r['enemy_scaling'].items()}
            r['reward']['first_clear_coins']=round(r['reward']['first_clear_coins']*1.3)
            boss={23:'boss_frostguard',42:'boss_nestcore',61:'boss_rootking',79:'boss_ovenheart',96:'boss_nestcore'}[n]
            boss_ids={u['id'] for u in units if u.get('is_boss')}
            r['waves'][0]['spawns']=[s for s in r['waves'][0]['spawns'] if s['unit'] not in boss_ids]
            r['waves'][0]['spawns'].insert(0,{'unit':boss,'count':1,'interval':0})
            r['waves'][0]['boss']=True
            r['boss_round']=True
            factor=float(tuning.get('gate_factors',{}).get(str(n),1.0))
            r['enemy_scaling']['hp']=round(r['enemy_scaling']['hp']*factor,4)
            r['enemy_scaling']['atk']=round(r['enemy_scaling']['atk']*math.sqrt(factor),4)
            r['growth_pressure_factor']=factor
        if n >= 23:
            r['balance_note']='Campaign100 candidate: fixed public growth gates R23/42/61/79/96. Late HP x1.027/round, ATK x1.020. No spending-dependent difficulty. See CAMPAIGN100.md and simulator evidence.'
        write(f'data/rounds/r{n:02}.json',r)
    write('data/rounds/order.json',{'schema_version':1,'rounds':[f'r{n:02}' for n in range(1,31)],'challenge':{'enabled':True,'rounds':[f'r{n:02}' for n in range(31,101)]}})

if __name__=='__main__': main()
