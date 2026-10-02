import json,re,html,urllib.request,urllib.parse
from pathlib import Path
root=Path(__file__).resolve().parents[1];mp=root/'docs/portraits_history_modern_20261002_55.json';rows=json.loads(mp.read_text(encoding='utf-8'))
ref=root/'assets/officers/portraits/references/history_modern_20261002'
def get(url):return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read()
for i,filename in [(0,'三田村左衛門.jpg'),(6,'Uesugi Sadakatsu.jpg'),(50,'Nomimunekatu01.jpg')]:
    url='https://commons.wikimedia.org/wiki/'+urllib.parse.quote('File:'+filename);h=get(url).decode('utf-8')
    (ref/(rows[i]['stem']+'_source.html')).write_text(h,encoding='utf-8')
    image_url=html.unescape(re.search(r'<div class="fullMedia".*?<a href="([^"]+)"',h,re.S)[1]).split('?')[0]
    path=ref/(rows[i]['stem']+'_historical.jpg');path.write_bytes(get(image_url))
    rows[i].update(reference_paths=[str(path)],sources=[url],source_image_url=image_url,basis='historical portrait; verify identity and date before prompt',rights='Commons public-domain tagging, see saved source page')
    pos=h.find('id="Summary"'); print(i,re.sub(r'<[^>]+>',' ',h[pos:pos+2600]))
url='https://rmda.kulib.kyoto-u.ac.jp/item/rb00033866';h=get(url).decode('utf-8');(ref/'uesugi_kenshin_record.html').write_text(h,encoding='utf-8')
print('Kyoto manifest',re.findall(r'https?[^\s"<>]+manifest[^\s"<>]*',h)[:8])
print('Kyoto image links',re.findall(r'href="([^"]+)"[^>]*>[^<]*(?:マニフェスト|Manifest)',h))
mp.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
