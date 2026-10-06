import json,re,html,urllib.request,sys
from urllib.parse import quote
from portraits_history100 import ROOT
DEST=ROOT/'assets/officers/portraits/references/history_modern_20261006_100'
DEST.mkdir(parents=True,exist_ok=True)
LOG=ROOT/'docs/portrait_research_20261006_100/downloaded_refs.json'
def get(url):return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'HistoricalPortraitResearch/1.0'}),timeout=25).read()
def download(i,f):
    url='https://commons.wikimedia.org/wiki/File:'+quote(f.replace(' ','_'))
    t=get(url).decode();raw=html.unescape(re.sub(r'\s+',' ',re.sub('<[^>]+>',' ',t)))
    m=re.search(r'<div class="fullImageLink"[^>]*>\s*<a href="([^"]+)"',t)
    image_url=html.unescape(m[1]).split('?')[0];p=DEST/f'{i:03d}_{f}'
    try: pixels=get(image_url)
    except urllib.error.HTTPError as e:
        if e.code!=429:raise
        parts=image_url.split('/commons/',1)
        image_url=parts[0]+'/commons/thumb/'+parts[1]+'/960px-'+parts[1].split('/')[-1]
        pixels=get(image_url)
    p.write_bytes(pixels);(DEST/f'{i:03d}_metadata.html').write_text(t,encoding='utf-8')
    rows=json.loads(LOG.read_text(encoding='utf-8')) if LOG.exists() else []
    rows=[x for x in rows if x['index']!=i]+[dict(index=i,url=url,image_url=image_url,reference_path=str(p),metadata=raw[raw.find('Original file'):raw.rfind('File history')])]
    LOG.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(rows[-1],ensure_ascii=True),flush=True)
if __name__=='__main__':
    if sys.argv[1]=='download':download(int(sys.argv[2]),sys.argv[3])
    else:
        names=['塚原卜伝','増田長盛','多胡辰敬','大久保忠世','大久保忠佐','大久保忠教','大久保忠隣','大久保長安','大内義隆','大友宗麟','大友義統','大友義鑑','大島光義','大村喜前','大村純忠','大舘尚氏','大谷吉継','大野治長','大関高増','大須賀康高','太原雪斎','太田牛一','太田資正']
        for name in names:
            try:
                t=get('https://ja.wikipedia.org/wiki/'+quote(name)).decode()
                links=re.findall(r'href="([^"]+)"[^>]*class="mw-file-description"',t)
                print(json.dumps(dict(name=name,images=[html.unescape(x) for x in links[:5]]),ensure_ascii=True),flush=True)
            except Exception as e:print(name.encode('ascii','backslashreplace').decode(),str(e),flush=True)
