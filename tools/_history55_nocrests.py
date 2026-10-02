import json
from pathlib import Path
p=Path('docs/portraits_history_modern_20261002_55.json');rows=json.loads(p.read_text(encoding='utf-8'))
for r in rows:r['prompt']+=' Clothing has NO family crests, NO circular emblems, NO heraldic badges or symbolic designs. Use plain woven cloth unless the historical reference explicitly has an all-over textile pattern; never add a discrete crest.'
p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
