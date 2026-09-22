"""Cache attributed public biography facts for the 1546 affiliation review."""
import concurrent.futures, gzip, hashlib, json, re, urllib.request, urllib.parse
from html.parser import HTMLParser
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'data/sources/officers/affiliations_1546'
class Page(HTMLParser):
    def __init__(self): super().__init__();self.params={};self.text=[];self.skip=0
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if tag in ('script','style'): self.skip+=1
        if 'data-mw' in attrs:
            try:
                for part in json.loads(attrs['data-mw']).get('parts',[]):
                    t=part.get('template',{}) if isinstance(part,dict) else {}
                    p=t.get('params',{})
                    if '主君' in p or ('氏族' in p and '生誕' in p):
                        self.params.update({k:v.get('wt','') for k,v in p.items() if k in ['主君','氏族','生誕','死没','幕府','藩','官位','改名','別名']})
            except (ValueError,TypeError): pass
    def handle_endtag(self,tag):
        if tag in ('script','style'): self.skip=max(0,self.skip-1)
        if tag in ('p','h2','h3','tr'):self.text.append('\n')
    def handle_data(self,d):
        if not self.skip:self.text.append(d)
def fetch(r):
    path=OUT/(r['external_id']+'.json')
    if path.exists():return 'cached'
    entity=json.loads((ROOT/'data/sources/officers/entities'/(r['external_id']+'.json')).read_text(encoding='utf-8'))['entity']
    links=entity.get('sitelinks',{})
    site='jawiki' if 'jawiki' in links else 'enwiki'
    if site not in links:return 'no_page'
    title=links[site]['title'];url='https://'+('ja' if site=='jawiki' else 'en')+'.wikipedia.org/wiki/'+urllib.parse.quote(title.replace(' ','_'))
    try:
        request=urllib.request.Request(url,headers={'User-Agent':'HistoricalGameResearch/1.0 (public biography reference; no images)'})
        raw=urllib.request.urlopen(request,timeout=35).read(); parser=Page();parser.feed(raw.decode('utf-8'))
        text=re.sub(r'[ \t\r\f\v]+',' ',''.join(parser.text));text=re.sub(r'\n\s*\n','\n',text)
        # Keep the attributed research text outside runtime exports; no images.
        payload={'external_id':r['external_id'],'name':r['display_name'],'url':url,'accessed':'2026-09-13','sha256':hashlib.sha256(raw).hexdigest(),'license':'Wikipedia text: CC BY-SA; research cache, not runtime','params':parser.params,'text':text}
        path.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        return 'ok'
    except Exception as e:return 'error:'+r['external_id']+':'+str(e)
def main():
    # Prefer the paced API batches; the original per-page pass hit rate limits.
    from research_affiliations_batch import main as fetch_batches
    fetch_batches()
if __name__=='__main__':main()
