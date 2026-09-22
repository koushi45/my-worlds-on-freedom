"""Archive the additional notable candidates; rebuilding ratings remains offline."""
import json,time,urllib.parse,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'data/sources/officers'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    names=read(ROOT/'data/master/officers/fourteenth_registration_names.json')
    index=read(OUT/'candidate_index.json');supplement=read(OUT/'supplemental_index.json')
    dp=ROOT/'data/master/officers/decisions.json';decisions=read(dp)
    manifest=ROOT/'data/master/officers/notable_registration.json';m=read(manifest)
    registered={r['external_id'] for r in m['officers']}; additions=[]
    for i in range(0,len(names),20):
        titles=[n.replace('酒井忠勝','酒井忠勝 (小浜藩主)') for n in names[i:i+20]]
        archive=OUT/f'fourteenth_registration_{i//20+1}.json'
        if archive.exists():data=read(archive)
        else:
            url='https://www.wikidata.org/w/api.php?'+urllib.parse.urlencode(dict(action='wbgetentities',sites='jawiki',titles='|'.join(titles),props='info|labels|aliases|descriptions|claims|sitelinks',languages='ja|en',format='json'))
            with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'MyWorldsOnFreedom-HistoricalRoster/0.3'}),timeout=50) as r:data=json.load(r)
            write(archive,data)
        for q,e in data['entities'].items():
            assert 'missing' not in e,e
            assert not any(c.get('mainsnak',{}).get('datavalue',{}).get('value',{}).get('id')=='Q4167410' for c in e.get('claims',{}).get('P31',[])),q
            title=e['sitelinks']['jawiki']['title'];name=e.get('labels',{}).get('ja',{}).get('value',title)
            if q not in index:
                row=dict(id=q,name=name,description=e.get('descriptions',{}).get('ja',{}).get('value',''),discovery=[archive.name],rows=[])
                index[q]=row;supplement[q]=row
                write(OUT/'entities'/f'{q}.json',dict(retrieved_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),license='CC0-1.0',entity=e))
            d=decisions.setdefault(q,{})
            d['register_across_start_year']=True
            d['in_scope']=True
            d['reason']='第14組の人物伝で近世初期の藩主・武家の軍事政務担当または世子として照合。世子の肩書のみでは能力を加点しない。'
            d['registration_reason']='著名人物の追加依頼により登録。生涯評価と1546年の出仕・配置は別に判定。'
            d['aliases']=sorted(set(d.get('aliases',[])+[title,name]))
            d['source_urls']=sorted(set(d.get('source_urls',[])+['https://ja.wikipedia.org/wiki/'+urllib.parse.quote(title.replace(' ','_'))]))
            item=dict(external_id=q,display_name=name,wikipedia_title=title,previously_in_roster=False,source_archive=archive.name)
            if q not in registered:m['officers'].append(item);registered.add(q)
            additions.append(item)
    assert len(additions)==len(names)==60
    write(OUT/'candidate_index.json',index);write(OUT/'supplemental_index.json',supplement);write(dp,decisions);write(manifest,m)
    write(ROOT/'data/master/officers/fourteenth_registration.json',dict(officers=additions,missing=[]))
    print('Registered',len(additions),'additional notable people')
if __name__=='__main__':main()
