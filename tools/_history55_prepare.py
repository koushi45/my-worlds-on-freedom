import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
data=json.loads((root/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))
audit=json.loads((root/'docs/PORTRAIT_REFERENCE_WITHDRAWAL_20261002.json').read_text(encoding='utf-8'))
registry=(root/'scripts/game/officer_portraits.gd').read_text(encoding='utf-8')
paths={r['id']:r['path'] for r in audit['removed_registry_entries']}
paths.update(dict(re.findall(r'"(officer_q[0-9]+)": "([^"]+)"',registry)))
rows=[]
for i,name in enumerate(json.loads((root/'builds/history55_names.json').read_text(encoding='utf-8'))):
    matches=[r for r in data['officers'] if r['display_name']==name];assert len(matches)==1
    r=matches[0];stem=Path(paths[r['id']]).stem
    stem=re.sub(r'[-_]v\d+$','',stem)+'_history_modern_v1'
    rows.append(dict(index=i,name=name,id=r['id'],ability=r['total_ability'],stem=stem,path='res://assets/officers/portraits/'+stem+'.png',status='researching',search_queries=[name+' 肖像 所蔵 史料',name+' 肖像 画像'],basis='not yet verified',reference_paths=[],sources=[]))
(root/'docs/portraits_history_modern_20261002_55.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(root/'assets/officers/portraits/references/history_modern_20261002').mkdir(parents=True,exist_ok=True)
print('Prepared',len(rows),'officers')
print(json.dumps(data['officers'][0],ensure_ascii=True)[:1200])
