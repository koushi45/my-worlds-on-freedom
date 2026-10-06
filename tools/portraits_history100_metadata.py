import json,re,html
from portraits_history100_refs import DEST,LOG
rows=json.loads(LOG.read_text(encoding='utf-8'))
for r in sorted(rows,key=lambda x:x['index']):
    t=(DEST/f"{r['index']:03d}_metadata.html").read_text(encoding='utf-8')
    t=re.sub(r'<(script|style)\b[^>]*>.*?</\1>','',t,flags=re.S)
    raw=html.unescape(re.sub(r'\s+',' ',re.sub('<[^>]+>',' ',t)))
    start=raw.find('Original file');end=raw.find('File history',start)
    r['metadata']=raw[start:end]
    print(json.dumps(dict(index=r['index'],metadata=r['metadata'][:2100]),ensure_ascii=True))
LOG.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
