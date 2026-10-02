import json, urllib.request, re, html, urllib.parse
from pathlib import Path
root=Path(__file__).resolve().parents[1]
mp=root/'docs/portraits_history_modern_20261002_55.json'
rows=json.loads(mp.read_text(encoding='utf-8'))
ref=root/'assets/officers/portraits/references/history_modern_20261002'
def get(url):
    return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read()
url='https://rmda.kulib.kyoto-u.ac.jp/iiif/metadata_manifest/RB00033866/manifest.json'
j=json.loads(get(url)); (ref/'uesugi_kenshin_manifest.json').write_text(json.dumps(j,ensure_ascii=False,indent=2),encoding='utf-8')
resource=j['items'][0]['items'][0]['items'][0]['body']
service=resource.get('service',[{}])[0]; print('resource',resource)
image_url=service.get('id','').rstrip('/')+'/full/!2000,2000/0/default.jpg' if service else resource['id']
p=ref/(rows[12]['stem']+'_historical.jpg');p.write_bytes(get(image_url))
rows[12].update(reference_paths=[str(p)],sources=['https://rmda.kulib.kyoto-u.ac.jp/item/rb00033866','https://rmda.kulib.kyoto-u.ac.jp/reuse'],source_image_url=image_url,basis='historical copy of Uesugi Kenshin portrait, possibly Edo period; Kyoto University Museum',rights='Kyoto University reuse policy: credit, link and disclose modifications; downloaded JPEG maximum edge 2000')
for i,filename in [(9,'Uesugi Kagekatsu.jpg'),(32,'Nakagawa Kiyohide.jpg'),(33,'Nakagawa Hidenari.jpg'),(49,'Niwa Nagahide.jpg')]:
    try:
        url='https://commons.wikimedia.org/wiki/'+urllib.parse.quote('File:'+filename)
        h=get(url).decode('utf-8');(ref/(rows[i]['stem']+'_source.html')).write_text(h,encoding='utf-8')
        image_url=html.unescape(re.search(r'<div class="fullMedia".*?<a href="([^"]+)"',h,re.S)[1]).split('?')[0]
        p=ref/(rows[i]['stem']+'_historical.jpg');p.write_bytes(get(image_url))
        rows[i].update(reference_paths=[str(p)],sources=[url],source_image_url=image_url,basis='candidate historical portrait: verify before adopting',rights='verify saved Commons metadata')
        print(i, re.sub('<[^>]+>',' ',h[h.find('id="fileinfotpl_desc"'):h.find('id="fileinfotpl_desc"')+4500]))
    except Exception as e: print(i, type(e).__name__,str(e))
mp.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
