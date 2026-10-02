import json,sys,hashlib
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1];mp=root/'docs/portraits_history_modern_20261002_55.json'
rows=json.loads(mp.read_text(encoding='utf-8'));i=int(sys.argv[1]);source=Path(sys.argv[2]);r=rows[i]
im=Image.open(source).convert('RGBA');assert im.width==im.height,im.size
if im.size!=(512,512):im=im.convert('RGBa').resize((512,512),Image.Resampling.LANCZOS).convert('RGBA')
assert im.getchannel('A').getextrema()==(0,255)
path=root/r['path'].removeprefix('res://');im.save(path)
path.with_suffix('.prompt.txt').write_text(r['prompt']+'\n',encoding='utf-8')
r.update(status='generated',generated_original=str(source),size=list(im.size),mode=im.mode,alpha_extrema=list(im.getchannel('A').getextrema()),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),generator='built-in image_gen; one tool call per officer; alpha-preserving 512px production resize')
mp.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(i,r['name'].encode('unicode_escape').decode(),r['status'],r['size'],r['alpha_extrema'])
