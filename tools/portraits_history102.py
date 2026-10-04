import json,re,sys,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'docs/portraits_history_modern_20261003_102.json'
NAMES='''伴盛兼|伴盛陰|佐々成政|佐世元嘉|佐世正勝|佐久間信晴|佐久間信盛|佐久間信辰|佐久間盛重|佐渡長重|佐田九郎左衛門|佐竹義喬|佐竹義宣|佐竹義昭|佐竹義重|佐野昌綱|佐野泰綱|佐野秀綱|佐野豊綱|依田信政|保土原行藤|保科正之|保科正俊|保科正直|保科正貞|児玉就光|児玉景唯|入来院重聡|入田親誠|八戸政栄|六角定治|六角定頼|六角義介|六角義実|六角義治|六角義賢|兼松正吉|内田実久|内藤信成|内藤信正|内藤信照|内藤元家|内藤元康|内藤元忠|内藤家長|内藤忠興|内藤忠郷|内藤政長|内藤昌豊|内藤正成 (四郎左衛門)|内藤清成|内藤清次|内藤清長|内藤源左衛門|内藤興盛|内藤隆世|内藤隆春|内藤隆貞|冷泉為純|冷泉興豊|冷泉隆豊|出浦盛清|初鹿野信昌|初鹿野忠次|別所吉親|別所重宗|別所長治|前波吉継|前田光高|前田利家|前田利常|前田利春|前田利益|前田利長|前田玄以|前野三七郎|前野嘉兵次|前野宗康|前野定時|前野時之|前野時正|前野正吉|前野泰道|前野為定|前野義康|前野義高|前野豊成|前野長宗|前野長康|前野長義|加木屋正則|加藤光泰|加藤嘉明|加藤弥三郎|加藤昌頼|加藤明成|加藤清正|加藤重徳|加藤順盛|加賀井重宗|勝沼信元|勝重久'''.split('|')
def read():return json.loads(MANIFEST.read_text(encoding='utf-8'))
def write(rows):MANIFEST.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def prepare():
    assert not MANIFEST.exists(),'Do not reset existing production'
    officers=json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))['officers']
    audit=json.loads((ROOT/'docs/PORTRAIT_REFERENCE_WITHDRAWAL_20261002.json').read_text(encoding='utf-8'))
    paths={x['id']:x['path'] for x in audit['removed_registry_entries']}
    paths.update(dict(re.findall(r'"(officer_q[0-9]+)": "([^"]+)"',(ROOT/'scripts/game/officer_portraits.gd').read_text(encoding='utf-8'))))
    rows=[]
    for i,name in enumerate(NAMES):
        matches=[x for x in officers if x['display_name']==name];assert len(matches)==1,(name,len(matches))
        x=matches[0];base=re.sub(r'(?:_history_modern)?_v\d+$','',Path(paths.get(x['id'],x['id'])).stem)
        version=1
        while (ROOT/'assets/officers/portraits'/f'{base}_history_modern_v{version}.png').exists():version+=1
        stem=f'{base}_history_modern_v{version}'
        rows.append(dict(index=i,name=name,id=x['id'],ability=x['total_ability'],stem=stem,path=f'res://assets/officers/portraits/{stem}.png',status='researching',search_queries=[],sources=[],reference_paths=[]))
    write(rows);print(json.dumps(dict(count=len(rows),maximum_ability=max(x['ability'] for x in rows),officers=[dict(index=x['index'],name=x['name'],ability=x['ability']) for x in rows]),ensure_ascii=True))
def save(index,source):
    rows=read();r=rows[index];im=Image.open(source)
    assert im.mode=='RGBA' and im.width==im.height
    if im.size!=(512,512):im=im.convert('RGBa').resize((512,512),Image.Resampling.LANCZOS).convert('RGBA')
    assert im.getchannel('A').getextrema()==(0,255)
    p=ROOT/r['path'].removeprefix('res://');im.save(p)
    p.with_suffix('.prompt.txt').write_text(r['prompt']+'\n'+r.get('framing_edit_prompt',''),encoding='utf-8')
    versions=r.setdefault('production_versions',[])
    if str(source) not in versions:versions.append(str(source))
    r.update(status='generated',generated_original=str(source),size=[512,512],mode='RGBA',alpha_extrema=[0,255],sha256=hashlib.sha256(p.read_bytes()).hexdigest(),alpha_subject_bbox=list(im.getchannel('A').getbbox()),generator='built-in image_gen; individual generation; premultiplied alpha-preserving production resize')
    write(rows);print(index,'saved512RGBA')
if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    elif sys.argv[1]=='save':save(int(sys.argv[2]),Path(sys.argv[3]))
