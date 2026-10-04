import urllib.request,re,html,json
from pathlib import Path
from urllib.parse import quote
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/officers/portraits/references/history_modern_20261003_116'
def get(u):return urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'HistoricalPortraitResearch/1.0'}),timeout=20).read()
def download(i,f):
    u='https://commons.wikimedia.org/wiki/File:'+quote(f.replace(' ','_'))
    try:
        t=get(u).decode();raw=html.unescape(re.sub(r'\s+',' ',re.sub('<[^>]+>',' ',t)))
        m=re.search(r'<div class="fullImageLink"[^>]*>\s*<a href="([^"]+)"',t)
        image_url=html.unescape(m[1]).split('?')[0];p=DEST/f'{i:03d}_{f}'
        p.write_bytes(get(image_url));(DEST/f'{i:03d}_metadata_extra.html').write_text(t,encoding='utf-8')
        a=raw.find('Description ')
        if a<0:a=raw.find('Summary')
        entry=dict(index=i,url=u,image_url=image_url,reference_path=str(p),metadata_excerpt=raw[a:a+6500])
        rows=json.loads((ROOT/'docs/portrait_research_20261003_116/downloaded_refs.json').read_text(encoding='utf-8'))
        rows=[x for x in rows if x['index']!=i]+[entry]
        (ROOT/'docs/portrait_research_20261003_116/downloaded_refs.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
        print(i,entry['metadata_excerpt'][:900],flush=True)
    except Exception as e:print(i,str(e),flush=True)
if __name__=='__main__':
    import sys
    if len(sys.argv)>2:download(int(sys.argv[1]),sys.argv[2])
    else:
        for c in ['Hojo_Ujiyasu','Furuta_Shigenari','Doi_Toshikatsu','Kikkawa_Motoharu','Chiba_Chikatane','Utsunomiya_Shigefusa']:
            try:
                t=get('https://commons.wikimedia.org/wiki/Category:'+c).decode()
                print(c,sorted(set(html.unescape(x) for x in re.findall(r'title="File:([^"]+)"',t))),flush=True)
            except Exception as e:print(c,str(e),flush=True)
