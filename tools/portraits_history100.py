import json,re,sys,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'docs/portraits_history_modern_20261006_100.json'
NAMES='''塚原卜伝|塩屋秋貞|塩川長満|増田長盛|夏目吉久|夏目吉信|多功建昌|多功房朝|多功秀朝|多功綱継|多功長朝|多田三八郎|多羅尾光俊|多胡辰敬|多賀谷家重|多賀谷政経|大久保忠世|大久保忠佐|大久保忠俊|大久保忠員|大久保忠教|大久保忠為|大久保忠舊|大久保忠重|大久保忠隣|大久保教隆|大久保長安|大井信広|大井信為|大井光照|大井安房丸|大井玄慶|大井行吉|大井行真|大井行頼|大井貞清|大井貞重|大井貞隆|大内定綱|大内義尊|大内義長|大内義隆|大内輝弘|大内高弘|大友宗麟|大友義統|大友義鑑|大国実頼|大塚与三衛門|大塚八木右衛門|大山伯耆|大山光隆|大岡忠勝|大島光朝|大島光義|大崎勝長|大崎義宣|大川忠秀|大村喜前|大村純忠|大沢基胤|大沢次郎左衛門|大河内秀綱|大熊朝秀|大田原綱清|大石定久|大石定仲|大石良信|大舘尚氏|大西頼包|大谷吉房|大谷吉継|大道寺周勝|大道寺政繁|大道寺盛昌|大道寺直繁|大道寺資親|大道寺重時|大野治房|大野治胤|大野治長|大野直昌|大関高増|大須賀康高|天羽源鉄|天野元定|天野元景|天野康景|天野隆良|天野隆重|天野雄光|太原雪斎|太田垣誠朝|太田康資|太田景資|太田氏資|太田牛一|太田資正|太田資顕|太田資高'''.split('|')
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
    write(rows);print(json.dumps(dict(count=len(rows),maximum_ability=max(x['ability'] for x in rows),officers=[dict(index=x['index'],name=x['name'],ability=x['ability']) for x in rows]),ensure_ascii=True))
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
