import json
from PIL import Image
from portraits_history116 import ROOT,read,write

rows=read()
assert len(rows)==116 and all(r['status']=='generated' for r in rows)
jobs=[]
for r in rows:
    image=Image.open(ROOT/r['path'].removeprefix('res://'))
    box=image.getchannel('A').point(lambda a:255 if a>=64 else 0).getbbox()
    if box[1]>=15:continue
    prompt=('Edit this exact finished modern realistic Western oil-painted Japanese Sengoku officer bust. '
        'Preserve this individual face, age, expression, facial hair, hairstyle, complete headgear, exact clothing and colors, pose and natural anatomy. '
        'Only repair framing: pull the camera back slightly and lower the bust in the square canvas so the ENTIRE head, topknot, crown or helmet crest is visible, '
        'with a clear fully transparent band occupying 7 percent of canvas height above the highest headgear or hair tip. '
        'Keep a natural shoulder silhouette and chest-up bust reaching the bottom edge; do not extend to a full-body figure. '
        'Restore any accidentally clipped headgear tip consistently with the existing shape. '
        'Keep the refined realistic oil-painted finish. Clean anti-aliased silhouette, no stray colored edge pixels, no halo or matte. '
        'True transparent alpha background PNG, square 1:1. No text of any language, no watermark, no frame, no scenery or ground. '
        'This is a framing correction to the same production portrait, not a new historical likeness reference.')
    r['framing_edit_prompt']=prompt
    r['framing_before_top_margin_px']=box[1]
    jobs.append(dict(index=r['index'],name=r['name'],prompt=prompt,source=r['generated_original']))
write(rows)
print(json.dumps(jobs,ensure_ascii=True))
