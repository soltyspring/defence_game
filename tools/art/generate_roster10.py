"""Original code-native SVG pixel characters; no external artwork or shared boss/HUD sheets."""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
IDS=['baguette','macaron','chili','donut','waffle']
COLORS=['#cf9652','#b596d7','#e85e44','#d4a277','#e0b957']
def sprite(kind, frame, action):
    parts=[]
    def rect(x,y,w,h,c): parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>')
    c=COLORS[kind]; dark='#392332'; cream='#fff1c9'
    bob=frame%2 if action=='walk' else 0
    # Distinct silhouettes: tall loaf, tiered macaron, pepper cap, ring shield, waffle grid.
    rect(14,39,9,5,dark); rect(27,39-(frame%2 if action=='walk' else 0),9,5,dark)
    rect(11,18+bob,26,22,dark); rect(13,20+bob,22,18,c)
    if kind==0:
        rect(16,5+bob,15,24,dark); rect(18,7+bob,11,23,c)
        for y in [10,16,22]: rect(19,y+bob,7,2,cream)
        rect(39,9,2,34,'#b58557'); rect(37,5,6,9,'#d6edf2')
    elif kind==1:
        rect(9,12+bob,30,12,dark); rect(11,13+bob,26,5,c); rect(11,19+bob,26,3,cream)
        rect(29,28,min(18,16+(frame*2 if action=='attack' else 0)),4,dark); rect(29,28,15,2,'#a4d2e2')
    elif kind==2:
        rect(12,10+bob,25,13,dark); rect(14,12+bob,21,10,c); rect(22,6+bob,9,5,'#73985d')
        rect(33,27,9,9,'#fcad42'); rect(36,24-(frame if action=='attack' else 0),4,9,'#ffe491')
    elif kind==3:
        rect(9,10+bob,30,20,dark); rect(11,12+bob,26,16,c); rect(21,12+bob,6,5,cream)
        rect(28,25,16,16,dark); rect(30,27,12,12,'#e9bd85'); rect(34,31,4,4,dark)
    else:
        rect(10,11+bob,28,22,dark); rect(12,13+bob,24,18,c)
        for x in [16,24,32]: rect(x,14+bob,2,14,'#986035')
        for y in [18,25]: rect(13,y+bob,23,2,'#986035')
        rect(30,30,16,8,dark); rect(31,31,14,5,'#d39c65'); rect(14,36,26,6,'#80513b')
    rect(18,26+bob,3,4,dark);rect(28,26+bob,3,4,dark)
    rect(18,26+bob,1,1,cream);rect(28,26+bob,1,1,cream)
    rect(15,31+bob,4,2,'#ee9d8c');rect(30,31+bob,4,2,'#ee9d8c')
    if action=='attack' and frame==2: rect(42,18,4,3,cream)
    content=''.join(parts)
    if action=='death': content=f'<g opacity="{1-frame*.22}" transform="translate(0 {frame*6}) scale(1 {1-frame*.14})">{content}</g>'
    return content
def svg(body,w,h): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" shape-rendering="crispEdges">{body}</svg>\n'
def main():
    folder=R/'assets/art/roster10';folder.mkdir(parents=True,exist_ok=True)
    atlas={'schema':'defence.atlas/1','atlas':'roster10','frames':{},'anims':{}}
    groups=[]
    for row,uid in enumerate(IDS):
        atlas['anims'][uid]={}
        for a,action in enumerate(['idle','walk','attack','death']):
            keys=[]
            for f in range(4):
                key=f'{uid}/{action}/{f}';keys.append(key);x=(a*4+f)*48;y=row*48
                atlas['frames'][key]={'x':x,'y':y,'w':48,'h':48,'pivot':[24,44]}
                groups.append(f'<g transform="translate({x} {y})">{sprite(row,f,action)}</g>')
            atlas['anims'][uid][action]={'frames':keys,'fps':8 if action!='idle' else 4,'loop':action in ['idle','walk'],'hit_frame':2}
        atlas['anims'][uid]['die']=atlas['anims'][uid]['death']
        portrait=svg(sprite(row,0,'idle'),24,24).replace('height="24" shape-rendering','height="24" viewBox="0 0 48 48" shape-rendering',1)
        (folder/f'{uid}.svg').write_text(portrait,encoding='utf-8')
    (folder/'roster10.svg').write_text(svg(''.join(groups),768,240),encoding='utf-8')
    (folder/'roster10.json').write_text(json.dumps(atlas,indent=2)+'\n',encoding='utf-8')
    path=R/'assets/manifest.json';m=json.loads(path.read_text(encoding='utf-8'))
    m['atlases']=[a for a in m['atlases'] if a['id']!='roster10']
    m['atlases'].append({'id':'roster10','group':'character','load_policy':'battle','image':'res://assets/art/roster10/roster10.svg','frames':'res://assets/art/roster10/roster10.json','size':[768,240],'anim_sets':IDS})
    for uid in IDS:m['anim_sets'][uid]='roster10'
    path.write_text(json.dumps(m,ensure_ascii=False,indent=1)+'\n',encoding='utf-8')
if __name__=='__main__':main()
