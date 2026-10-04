import json,re,sys,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'docs/portraits_history_modern_20261003_116.json'
NAMES='''北信愛|北就勝|北条幻庵|北条康種|北条景広|北条氏尭|北条氏康|北条氏成|北条氏政|北条氏照|北条氏直|北条氏繁|北条氏規|北条氏邦|北条直定|北条綱成|北条綱房|北条綱高|北条高広|北畠具教|北畠晴具|北郷忠虎|北郷時久|十時惟忠|十時惟次|十河一存|十河景滋|千々石直員|千坂景親|千坂長朝|千徳政武|千本義隆|千本資俊|千秋季忠|千種忠治|千葉利胤|千葉直重|千葉胤宗|千葉胤頼|千葉興常|千葉親胤|千賀信親|南条信正|南条宗勝|南部信直|南部晴政|原昌胤|原田宗時|原田宗資|原田宗輔|原胤従|原胤義|原虎吉|原虎胤|原長頼|口羽通良|古川済堯|古田重然|右田隆次|吉川元春|吉川広家|吉川興経|吉弘鎮信|吉江景資|吉田康俊|吉田弥三|吉田長利|吉良義堯|吉良義安|吉良親貞|吉見正頼|和仁親宗|和智誠春|和田信維|和田惟政|和賀義忠|品川将員|唐沢玄蕃|喜入季久|喜多村政信|国分盛廉|国分盛氏|国分盛顕|国司元相|国富貞次|国重信正|土井利勝|土居清良|土屋昌続|土屋貞綱|土岐頼春|土岐頼純|土岐頼芸|坂崎成政|坂本貞吉|坂本貞次|坪内利定|坪内勝長|坪内友定|坪内広綱|坪内忠勝|坪内昌家|坪内頼定|城井鎮房|埴原八蔵|堀内俊胤|堀尾吉晴|堀尾忠晴|堀尾忠氏|堀無手右衛門|堀直之|堀直定|堀直寄|堀直政|堀秀政|塙直之'''.split('|')
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
        x=matches[0];base=re.sub(r'(?:_history_modern)?_v\d+$','',Path(paths.get(x['id'],x['id'])).stem);version=1
        while (ROOT/'assets/officers/portraits'/f'{base}_history_modern_v{version}.png').exists():version+=1
        stem=f'{base}_history_modern_v{version}'
        rows.append(dict(index=i,name=name,id=x['id'],ability=x['total_ability'],stem=stem,path=f'res://assets/officers/portraits/{stem}.png',status='researching',search_queries=[],sources=[],reference_paths=[]))
    write(rows);print(json.dumps(dict(count=len(rows),maximum_ability=max(x['ability'] for x in rows),officers=[dict(index=x['index'],name=x['name'],ability=x['ability']) for x in rows]),ensure_ascii=False))
def save(index,source):
    rows=read();r=rows[index];im=Image.open(source);assert im.mode=='RGBA' and im.width==im.height
    if im.size!=(512,512):im=im.convert('RGBa').resize((512,512),Image.Resampling.LANCZOS).convert('RGBA')
    assert im.getchannel('A').getextrema()==(0,255)
    p=ROOT/r['path'].removeprefix('res://');im.save(p);p.with_suffix('.prompt.txt').write_text(r['prompt']+'\n'+r.get('framing_edit_prompt',''),encoding='utf-8')
    versions=r.setdefault('production_versions',[])
    if str(source) not in versions:versions.append(str(source))
    r.update(status='generated',generated_original=str(source),size=[512,512],mode='RGBA',alpha_extrema=[0,255],sha256=hashlib.sha256(p.read_bytes()).hexdigest(),alpha_subject_bbox=list(im.getchannel('A').getbbox()),generator='built-in image_gen; individual generation; premultiplied alpha-preserving production resize')
    write(rows);print(index,'saved512RGBA')
if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    elif sys.argv[1]=='save':save(int(sys.argv[2]),Path(sys.argv[3]))
