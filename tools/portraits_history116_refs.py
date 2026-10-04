import urllib.request,re,html,json
from pathlib import Path
from urllib.parse import quote
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/officers/portraits/references/history_modern_20261003_116'
DEST.mkdir(parents=True,exist_ok=True)
FILES={2:'Hojo Gennann.jpg',6:'Hojo Ujiyasu.jpg',8:'Hojo Ujimasa.jpg',10:'Hojo Ujinao.jpg',15:'Hojo Tsunashige.jpg',19:'Kitabatake Tomonori.jpg',40:'Chiba Chikatane.jpg',44:'Nanbu Nobunao01.jpg',55:'Kuchiba Michiyoshi.jpg',57:'Furuta Oribe.jpg',59:'Kikkawa Motoharu.jpg',60:'Kikkawa Hiroie.jpg',66:'Yoshida Nagatoshi.jpg',70:'Yoshimi Masayori.jpg',83:'Kunishi Motosuke.jpg',86:'Doi Toshikatsu.jpg',91:'Toki Yorizumi.jpg',92:'Toki Yorinari.jpg',103:'Kii Shigefusa.jpg',106:'Horio Yoshiharu.jpg',108:'Horio Tadauji.jpg',112:'Hori Naoyori.jpg',114:'Hori Hidemasa.jpg'}
out=[]
def get(u):return urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'HistoricalPortraitResearch/1.0'}),timeout=20).read()
for i,f in FILES.items():
    u='https://commons.wikimedia.org/wiki/File:'+quote(f.replace(' ','_'))
    try:
        t=get(u).decode('utf-8');raw=html.unescape(re.sub(r'\s+',' ',re.sub('<[^>]+>',' ',t)))
        m=re.search(r'<div class="fullImageLink"[^>]*>\s*<a href="([^"]+)"',t)
        if not m:raise ValueError('No original image link')
        image_url=html.unescape(m.group(1)).split('?')[0];path=DEST/f'{i:03d}_{Path(f).name}'
        (DEST/f'{i:03d}_metadata.html').write_text(t,encoding='utf-8');path.write_bytes(get(image_url))
        a=raw.find('Description ');out.append(dict(index=i,url=u,image_url=image_url,reference_path=str(path),metadata_excerpt=raw[a:a+4800]));print(i,'downloaded',flush=True)
    except Exception as e:out.append(dict(index=i,url=u,error=str(e)));print(i,str(e),flush=True)
    (ROOT/'docs/portrait_research_20261003_116/downloaded_refs.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
