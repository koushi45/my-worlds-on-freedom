"""Read a second map location for reviewed castle identities; never auto-move sites."""
import json,re,urllib.request,concurrent.futures
from pathlib import Path
from pyproj import Geod
ROOT=Path(__file__).resolve().parents[1];DIR=ROOT/'data/editorial/settlements/expansion_250'
def run():
    rows=json.loads((DIR/'coordinate_audit_inputs.json').read_text(encoding='utf-8'))
    adopted=json.loads((DIR/'adopted_additions.json').read_text(encoding='utf-8'))
    # Replaced candidates and modern castles are not evidence for a differently named old site.
    skip={43,64,109,133,199,203}
    jobs=[]
    for r in rows:
        if not r['urls'] or r['index'] in skip or adopted[r['index']]['role']!='castle':continue
        r['url']=r['urls'][1] if r['index'] in [48,102] else r['urls'][0]
        jobs.append(r)
    def fetch(r):
        result={k:r[k] for k in ['index','name','url','lonlat']}
        try:
            content=urllib.request.urlopen(r['url'],timeout=20).read().decode('utf-8')
            m=re.search(r'map\.setView\(\[([0-9.]+),\s*([0-9.]+)\]',content)
            if not m:raise ValueError('map coordinate missing')
            result['reference_lonlat']=[float(m[2]),float(m[1])]
            result['difference_m']=round(Geod(ellps='WGS84').inv(*r['lonlat'],*result['reference_lonlat'])[2],1)
        except Exception as e:result['error']=str(e)
        return result
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:results=list(pool.map(fetch,jobs))
    (DIR/'coordinate_audit_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('\n'.join(str(r) for r in results if r.get('difference_m',0)>600 or r.get('error')))
    print('Read map references:',len(results))
if __name__=='__main__':run()
