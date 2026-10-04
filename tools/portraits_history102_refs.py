import urllib.request,re,html,json,time
from pathlib import Path
from urllib.parse import quote
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/officers/portraits/references/history_modern_20261003_102'
DEST.mkdir(parents=True,exist_ok=True)
FILES={12:'Satake Yoshinobu.jpg',21:'Hoshina Masayuki.jpg',36:'Kanematsu Masayoshi.jpg',38:'Naitō Nobunari.jpg',47:'Naitō Masanaga.jpg',54:'Naitō Okimori.jpg',69:'Maeda Toshiie.jpg',70:'Maeda Toshitsune.png',73:'MaedaToshinaga1.jpg',74:"Maeda Gen'i.jpg",92:'Katō Yoshiaki.jpg',96:'Katō Kiyomasa.jpg'}
out=[]
def get(u):
    return urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'HistoricalPortraitResearch/1.0'}),timeout=30).read()
for i,f in FILES.items():
    u='https://commons.wikimedia.org/wiki/File:'+quote(f.replace(' ','_'))
    try:
        t=get(u).decode('utf-8')
        if 'fullImageLink' not in t:t=get(u+'?uselang=en').decode('utf-8')
        raw=html.unescape(re.sub(r'\s+',' ',re.sub('<[^>]+>',' ',t)))
        m=re.search(r'<div class="fullImageLink"[^>]*>\s*<a href="([^"]+)"',t)
        if not m:raise ValueError('No original image link')
        image_url=html.unescape(m.group(1)).split('?')[0]
        rec={'index':i,'url':u,'image_url':image_url,'metadata_excerpt':raw[raw.find('Summary [ edit ]'):raw.find('Summary [ edit ]')+3400]}
        if not rec['metadata_excerpt']:rec['metadata_excerpt']=raw[raw.find('Description '):raw.find('Description ')+3400]
        (DEST/f'{i:03d}_metadata.html').write_text(t,encoding='utf-8')
        path=DEST/f'{i:03d}_{Path(f).name}'
        path.write_bytes(get(image_url));rec['reference_path']=str(path)
        out.append(rec);print(i,'downloaded',flush=True)
    except Exception as e:out.append({'index':i,'url':u,'error':str(e)});print(i,str(e),flush=True)
(ROOT/'docs/portrait_research_20261003_102/downloaded_refs.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
