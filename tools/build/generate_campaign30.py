"""Deterministic chapter 2/3 content. Preserves r01-r10 and their original units.

Only existing animation sets/projectiles are reused; role marks live in battle_view.
Run from the repository root. No downloaded assets or external services.
"""
from pathlib import Path
import copy
import json

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8-sig"))


def write(path, obj):
    (ROOT / path).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def generate():
    units = read("data/units/units.json")
    original = {u["id"]: u for u in units["units"]}
    specs = [
        ("e_guard", "e_grunt", "껍질 방패병", "Husk Guard", dict(hp=210, atk=11, atk_interval=1.3, speed=26, armor=7, bounty=8, kill_coins=3, visual_mark="shield", visual_tint="c7b394", audio_pitch=0.88)),
        ("e_runner", "e_swarm", "솜털 질주자", "Dust Runner", dict(hp=55, atk=7, atk_interval=0.7, speed=82, bounty=5, kill_coins=2, visual_mark="runner", visual_tint="dfbb83", audio_pitch=1.12)),
        ("e_mortar", "e_spitter", "포자 포격수", "Spore Mortar", dict(hp=95, atk=18, atk_interval=2.7, range=155, speed=24, splash=24, structure_mult=0.55, bounty=9, kill_coins=4, visual_mark="spore", visual_tint="bba4db", audio_pitch=0.80)),
        ("boss_millward", "boss_warlord", "제분장 파수꾼", "Mill Warden", dict(hp=2200, atk=32, armor=5, visual_mark="warden", visual_tint="c9af88", audio_pitch=0.83)),
        ("boss_rootking", "boss_overlord", "과수원 균사왕", "Root King", dict(hp=3400, atk=34, armor=5, visual_mark="root", visual_tint="93bb91", audio_pitch=0.76, summon={"unit":"e_guard","count":1,"interval":18.0,"max_alive":4,"summon_frame":3})),
        ("boss_frostguard", "boss_warlord", "서리 방벽", "Frost Warden", dict(hp=3700, atk=40, armor=7, visual_mark="frost", visual_tint="93c7df", audio_pitch=0.80)),
        ("boss_ovenheart", "boss_overlord", "곰팡이 오븐 심장", "Mold Oven Heart", dict(hp=4500, atk=42, armor=7, visual_mark="ember", visual_tint="dba883", audio_pitch=0.70, summon={"unit":"e_runner","count":3,"interval":16.0,"max_alive":9,"summon_frame":3})),
    ]
    new_ids = {s[0] for s in specs}
    units["units"] = [u for u in units["units"] if u["id"] not in new_ids]
    extra_text = {"ko":{},"en":{}}
    for ident, parent, ko, en, changes in specs:
        u = copy.deepcopy(original[parent])
        u.update(changes)
        # Opaque head height from the existing atlas walk frames, relative to the
        # foot pivot. Do not anchor hats to the transparent 32/64/80 px cell tops.
        u['visual_mark_height'] = {'e_grunt':18,'e_swarm':23,'e_spitter':18,'boss_warlord':44,'boss_overlord':55}[parent]
        u.update(id=ident, name=ko, name_key=f"unit.{ident}.name", desc_key=f"unit.{ident}.desc")
        units["units"].append(u)
        extra_text["ko"][u["name_key"]] = ko
        extra_text["en"][u["name_key"]] = en
        extra_text["ko"][u["desc_key"]] = {"e_guard":"두꺼운 껍질을 두른 방패병. 강한 한 방으로 돌파하세요.","e_runner":"빠르게 보급로로 파고드는 질주자. 뒤로 새지 않게 막으세요.","e_mortar":"후열을 노리는 포자 범위 포격수. 영웅과 속공병으로 접근하세요."}.get(ident,"지원 병력을 동반하는 구간 보스. 전선을 유지하며 공략하세요.")
        extra_text["en"][u["desc_key"]] = {"e_guard":"Armored frontline. Break its shell with heavy hits.","e_runner":"Fast raider. Keep it away from the bakery.","e_mortar":"Long-range splash fire. Close in with your hero and raiders."}.get(ident,"A checkpoint boss backed by reinforcements. Hold the frontline.")
    write("data/units/units.json",units)

    names = [
        ("껍질 방패대","Husk Vanguard"),("포자 폭격길","Spore Battery"),("솜털 돌격로","Dust Rush"),("과수원 협공","Orchard Crossfire"),("제분장 파수꾼","Mill Warden"),
        ("밤의 수확","Night Harvest"),("사과 창고 포위","Apple Store Siege"),("포자 공성진","Spore Siege"),("뿌리 속 전선","Root Front"),("균사왕의 과수원","Root Orchard"),
        ("서리 묻은 길","Frostbound Road"),("냉동 저장고","Cold Store"),("눈보라 질주","Blizzard Rush"),("얼음 포격대","Frozen Battery"),("서리 방벽","Frost Warden"),
        ("깊은 발효실","Deep Cellar"),("검은 효모의 밤","Black Yeast Night"),("마지막 보급로","Last Supply Route"),("오븐 심장 앞","Before the Oven Heart"),("곰팡이 오븐 심장","Mold Oven Heart"),
    ]
    patterns = [
        [("e_guard",3),("e_grunt",4)],
        [("e_mortar",2),("e_grunt",5)],
        [("e_runner",8),("e_spitter",3)],
        [("e_guard",3),("e_mortar",2),("e_runner",4)],
    ]
    bosses = {15:"boss_millward",20:"boss_rootking",25:"boss_frostguard",30:"boss_ovenheart"}
    summary = []
    for number, (ko,en) in enumerate(names,11):
        stage = number-11
        pattern = patterns[stage%4]
        boss = bosses.get(number)
        waves = []
        for wi, at in enumerate([12,44,82,124]):
            spawns = [{"unit":u,"count":n+(wi//2),"interval":0.7 if u in ["e_runner","e_swarm"] else 1.2} for u,n in pattern]
            if wi%2 == 1:
                spawns.append({"unit":"e_bomber" if wi == 3 else "e_spitter","count":2+(stage//10),"interval":1.6})
            if boss and wi == 0:
                spawns = [{"unit":boss,"count":1,"interval":0}]+spawns[:1]
            waves.append({"at":at,"spawns":spawns,**({"boss":True} if boss and wi==0 else {})})
        rd = {
            "schema_version":1,"id":f"r{number:02}","index":number,"chapter":2 if number<=20 else 3,
            "name":ko,"name_key":f"round.r{number:02}.name","biome":"biome_orchard" if number<=20 else "biome_frost",
            "lane_length":1800+(stage%5)*90+(100 if number>20 else 0),
            "player_base_hp":2400+stage*25,"enemy_base_hp":2200+stage*55+(300 if boss else 0),
            "start_gold":110+stage//5*10,"gold_max":500,"workers_max":8,"hero":"hero_captain",
            "cards":["melee_basic","ranged_basic","tank","fast","siege"],"skills":["skill_slam","skill_rally","skill_barrage"],
            "waves":waves,"enemy_ai":{"pool":[],"income":0,"start_gold":0,"think":2.5,"after_waves_loop":False},
            "trickle":{"start":7,"pattern":[pattern[0][0],"e_grunt","e_swarm",pattern[-1][0]],"interval":9.0-stage*0.08,"interval_min":7.0,"ramp_per_min":0.25},
            "enemy_base_spawns_on_hp":[{"below":0.55,"spawns":[{"unit":"e_guard","count":2,"interval":1.3},{"unit":"e_mortar","count":1,"interval":0}]},{"below":0.25,"spawns":[{"unit":"e_runner","count":5,"interval":0.6}]}],
            "reward":{"coins":180+stage*6,"first_clear_coins":360+stage*18,"three_star_bonus_coins":100+stage*4},
            "stars":{"time_3":300 if boss else 270,"base_hp_2":0.4},
            "enemy_scaling":{"hp":round(1.25+stage*0.03,3),"atk":round(1.10+stage*0.018,3)},"enemy_tower_atk_mult":0.5,
            "tutorial":[],"boss_round":bool(boss),"provisional":True,
            "balance_note":"Campaign 30: distinct wave compositions, reused animation sets, gated late upgrades; bot validation in docs/qa/CAMPAIGN30_20261105.md. Human difficulty remains to be played."
        }
        write(f"data/rounds/r{number:02}.json",rd)
        extra_text["ko"][rd["name_key"]] = ko
        extra_text["en"][rd["name_key"]] = en
        summary.append({"id":rd["id"],"role":pattern,"boss":boss,"recommended_level":5+min(4,stage//5+1)})
    order = read("data/rounds/order.json")
    if isinstance(order,list): order = [f"r{i:02}" for i in range(1,31)]
    else:
        key = "order" if "order" in order else "rounds"
        order[key] = [f"r{i:02}" for i in range(1,31)]
    write("data/rounds/order.json",order)
    meta = read("data/meta.json")
    for u in meta["upgrades"]:
        original_max = 4 if u["id"] == "up_worker" else 5
        old = u["costs"][:original_max-1]
        last = old[-1]
        u["max_level"] = original_max+4
        u["costs"] = old+[round(last*f/10)*10 for f in [1.25,1.75,2.35,3.1]]
        u["level_unlock_rounds"] = {str(original_max+j+1):11+j*5 for j in range(4)}
    write("data/meta.json",meta)
    for loc,strings in extra_text.items():
        p=f"data/text/{loc}.json";d=read(p);d["strings"].update(strings);write(p,d)
    write("docs/design/campaign30.json",{"rounds":summary,"original_rounds_unchanged":"r01-r10","extra_texture_pages":0,"extra_audio_files":0})
    print("CAMPAIGN30 generated 20 rounds, 7 enemy variants, 4 gated upgrade tiers")


if __name__ == "__main__":
    generate()
