from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'data/work/political/kinki_chubu_registration'
OUT.mkdir(parents=True,exist_ok=True)
raw=Image.open(ROOT/'data/work/political/coast_alignment_v2/source_rgba.png').getchannel('A')
raw=Image.eval(raw,lambda x:255-x).convert('RGB')
for name,box in [('kinki',(650,625,810,790)),('chubu',(755,500,955,720)),('echigo',(870,420,1030,580))]:
    factor=5;im=raw.crop(box).resize(((box[2]-box[0])*factor,(box[3]-box[1])*factor));d=ImageDraw.Draw(im)
    for x in range(box[0],box[2],10):
        d.line(((x-box[0])*factor,0,(x-box[0])*factor,im.height),fill='#ebcccc');d.text(((x-box[0])*factor+2,1),str(x),fill='red')
    for y in range(box[1],box[3],10):
        d.line((0,(y-box[1])*factor,im.width,(y-box[1])*factor),fill='#ebcccc');d.text((1,(y-box[1])*factor+1),str(y),fill='red')
    im.save(OUT/f'{name}_source_grid.png')
