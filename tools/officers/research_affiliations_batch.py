"""Fill missing biography caches with batched, revision-attributed API requests."""
import json, urllib.request, urllib.parse, time, re, hashlib
from pathlib import Path
from research_affiliations import ROOT, OUT
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    roster=json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))['officers']
    missing={}
    for r in roster:
        if (OUT/(r['external_id']+'.json')).exists():continue
        e=json.loads((ROOT/'data/sources/officers/entities'/(r['external_id']+'.json')).read_text(encoding='utf-8'))['entity']
        t=e.get('sitelinks',{}).get('jawiki',{}).get('title')
        if t:missing[t]=r
    titles=list(missing)
    for start in range(0,len(titles),20):
        batch=titles[start:start+20]
        url='https://ja.wikipedia.org/w/api.php?'+urllib.parse.urlencode({'action':'query','format':'json','prop':'revisions','rvprop':'ids|content','rvslots':'main','titles':'|'.join(batch),'redirects':1})
        req=urllib.request.Request(url,headers={'User-Agent':'HistoricalGameResearch/1.0 (batched public biography research)'})
        result=json.load(urllib.request.urlopen(req,timeout=50))
        query=result.get('query',{});aliases={x['to']:x['from'] for x in query.get('normalized',[])+query.get('redirects',[])}
        for page in query.get('pages',{}).values():
            title=page['title'];original=title
            for _ in range(4):original=aliases.get(original,original)
            row=missing.get(original) or missing.get(title)
            if not row or not page.get('revisions'):continue
            revision=page['revisions'][0];text=revision['slots']['main']['*']
            params={}
            for k,v in re.findall(r'^\|\s*(主君|氏族|生誕|死没|幕府|藩|官位|改名|別名)\s*=([^\n]*)',text,re.M):
                if k not in params:params[k]=v.strip()
            payload={'external_id':row['external_id'],'name':row['display_name'],'url':'https://ja.wikipedia.org/w/index.php?oldid='+str(revision['revid']),'title':title,'accessed':'2026-09-13','revision':revision['revid'],'sha256':hashlib.sha256(text.encode()).hexdigest(),'license':'Wikipedia CC BY-SA; attributed research cache, not runtime','params':params,'text':text,'format':'wikitext'}
            (OUT/(row['external_id']+'.json')).write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print('batch',start+len(batch),'/',len(titles),flush=True)
        time.sleep(8)
if __name__=='__main__':main()
