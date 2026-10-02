from pathlib import Path
import json,urllib.request,re,html
root=Path(__file__).resolve().parents[1];mp=root/'docs/portraits_history_modern_20261002_55.json';rows=json.loads(mp.read_text(encoding='utf-8'));ref=root/'assets/officers/portraits/references/history_modern_20261002'
url='https://upload.wikimedia.org/wikipedia/commons/3/32/Niwa_Nagahide.jpg';p=ref/(rows[49]['stem']+'_historical.jpg');p.write_bytes(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read())
rows[49].update(reference_paths=[str(p)],sources=['https://commons.wikimedia.org/wiki/File:Niwa_Nagahide.jpg','https://www.history.museum.city.fukui.fukui.jp/tenji/kaisetsusheets/18.pdf'],source_image_url=url,basis='Sixteenth-century Nagahide historical portrait, source Fukui Prefectural Archives; author unknown.',rights='Commons PD-Art (PD-old-100-expired), public-domain mark')
mp.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for i in [9,33,50]:
    h=(ref/(rows[i]['stem']+'_source.html')).read_text(encoding='utf-8');part=h[h.find('id="mw-content-text"'):];part=part[:part.find('Licensing')]
    print(i,html.unescape(re.sub('<[^>]+>',' ',part))[-3800:].encode('unicode_escape').decode())
