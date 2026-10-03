import hashlib, html, json, re, sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'docs/portraits_history_modern_20261003_88.json'
NAMES='''久野宗能 乙部八兵衛 九戸実親 九戸政実 九鬼嘉隆 乾和信 亀井秀綱 二宮俊実 二宮就辰 二本松家泰 二本松晴国 二本松義国 二本松義氏 二見密蔵院 二階堂盛義 五代友喜 井上之房 井上元吉 井上大九郎 井上就在 井上有景 井伊直勝 井伊直孝 井伊直平 井伊直政 井伊直盛 井伊直虎 井伊直親 亘理元宗 亘理重宗 京極忠高 京極高吉 京極高広 京極高次 京極高知 仁木友梅 仁木義広 仁木長政 今井信乂 今井信甫 今井信良 今井定清 今川氏真 今川氏豊 今川義元 今村勝長 今泉盛泰 今泉盛高 今田長佳 仙石定盛 仙石忠政 仙石秀久 仙石秀範 仲井市之進 伊丹康直 伊丹総堅 伊勢貞孝 伊勢貞就 伊勢貞良 伊勢貞辰 伊奈忠家 伊岐真利 伊木忠次 伊東義益 伊東義祐 伊東重信 伊藤信恒 伊藤実信 伊藤祐重 伊達宗利 伊達宗勝 伊達宗実 伊達宗泰 伊達宗清 伊達宗重 伊達定宗 伊達実元 伊達忠宗 伊達成実 伊達政宗 伊達政道 伊達晴宗 伊達秀宗 伊達稙宗 伊達輝宗 伊集院忠朗 伊集院忠棟 伊集院忠真'''.split()
def prepare():
    data=json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))['officers']
    audit=json.loads((ROOT/'docs/PORTRAIT_REFERENCE_WITHDRAWAL_20261002.json').read_text(encoding='utf-8'))
    paths={r['id']:r['path'] for r in audit['removed_registry_entries']}
    paths.update(dict(re.findall(r'"(officer_q[0-9]+)": "([^"]+)"',(ROOT/'scripts/game/officer_portraits.gd').read_text(encoding='utf-8'))))
    rows=[]
    for i,name in enumerate(NAMES):
        expected=name+' (二階堂照行の嫡男)' if name=='二階堂盛義' else name
        matches=[r for r in data if r['display_name']==expected]
        assert len(matches)==1,(name,[(r['id'],r['display_name']) for r in matches])
        r=matches[0];stem=re.sub(r'(?:_history_modern)?_v\d+$','',Path(paths.get(r['id'],r['id'])).stem)+'_history_modern_v1'
        if (ROOT/'assets/officers/portraits'/f'{stem}.png').exists():stem=stem.removesuffix('_v1')+'_v2'
        rows.append(dict(index=i,name=name,id=r['id'],ability=r['total_ability'],stem=stem,path=f'res://assets/officers/portraits/{stem}.png',status='researching',search_queries=[name+' 肖像 所蔵 史料'],reference_paths=[],sources=[],basis='未調査',identity_note='二階堂照行の嫡男' if name=='二階堂盛義' else ''))
    MANIFEST.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'assets/officers/portraits/references/history_modern_20261003_88').mkdir(parents=True,exist_ok=True)
    print('Prepared',len(rows),'highest ability',max(r['ability'] for r in rows))
def save(i,source):
    rows=json.loads(MANIFEST.read_text(encoding='utf-8'));r=rows[i]
    im=Image.open(source).convert('RGBA');assert im.width==im.height
    if im.size!=(512,512):im=im.convert('RGBa').resize((512,512),Image.Resampling.LANCZOS).convert('RGBA')
    assert im.getchannel('A').getextrema()==(0,255)
    path=ROOT/r['path'].removeprefix('res://');im.save(path)
    path.with_suffix('.prompt.txt').write_text(r['prompt']+'\n'+('Framing edit: '+r['framing_edit_prompt']+'\n' if r.get('framing_edit_prompt') else ''),encoding='utf-8')
    originals=r.setdefault('production_versions',[])
    if r.get('generated_original') and r['generated_original'] not in originals:originals.append(r['generated_original'])
    if str(source) not in originals:originals.append(str(source))
    r.update(status='generated',generated_original=str(source),size=list(im.size),mode=im.mode,alpha_extrema=list(im.getchannel('A').getextrema()),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),generator='built-in image_gen, individual generation; premultiplied alpha-preserving production resize',alpha_subject_bbox=list(im.getchannel('A').getbbox()))
    MANIFEST.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(i,r['name'].encode('unicode_escape').decode(),'saved512RGBA')
if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    elif sys.argv[1]=='save':save(int(sys.argv[2]),Path(sys.argv[3]))
