import json
from PIL import Image
from portraits_history116 import ROOT,read
out=[]
for r in read():
    if r['status']!='generated':continue
    im=Image.open(ROOT/r['path'].removeprefix('res://'));alpha=im.getchannel('A');bbox=alpha.point(lambda a:255 if a>=64 else 0).getbbox()
    out.append(dict(index=r['index'],name=r['name'],core_bbox=bbox,top_margin=bbox[1],alpha_extrema=alpha.getextrema()))
print(json.dumps(dict(generated=len(out),tight_top=[x for x in out if x['top_margin']<15],all=out),ensure_ascii=True))
