"""Ingest the user crop without altering it; reproduce a separate review run."""
import json
import shutil
from pathlib import Path
from datetime import datetime,timezone
import cv2
import numpy as np
from PIL import Image
import build_kinki_chubu_border_review as review

ROOT=review.ROOT
OUT=ROOT/'data/work/political/kinki_uploaded_crop'
UPLOAD=Path('C:/Users/nanoa/AppData/Local/Temp/codex-clipboard-64936944-8396-4365-8a38-dc525775446f.png')

def run():
    OUT.mkdir(parents=True,exist_ok=True)
    target=OUT/'source_original.png'
    if target.exists():
        assert review.core.digest(target)==review.core.digest(UPLOAD),'Do not overwrite a different input'
    else:shutil.copyfile(UPLOAD,target)
    image=np.array(Image.open(target).convert('RGBA'))
    original=np.array(Image.open(ROOT/'data/work/political/coast_alignment_v2/source_rgba.png').convert('RGBA'))
    scores=cv2.matchTemplate(original[:,:,:3],image[:,:,:3],cv2.TM_SQDIFF_NORMED)
    score,_,offset,_=cv2.minMaxLoc(scores)
    x,y=offset;h,w=image.shape[:2];matched=original[y:y+h,x:x+w]
    assert np.array_equal(matched[:,:,:3],image[:,:,:3]),'Crop position must be verified, not assumed'
    manifest={'source':'user upload','received_filename':UPLOAD.name,'recorded_at_utc':datetime.now(timezone.utc).isoformat(),
        'sha256':review.core.digest(target),'width':w,'height':h,'mode':'RGBA',
        'parent_rgb_match':{'offset':list(offset),'normalized_squared_difference':score,'exact_rgb_match':True},
        'alpha_equal_to_parent':bool(np.array_equal(matched[:,:,3],image[:,:,3])),
        'alpha_handling':'Use the uploaded alpha as supplied; do not substitute parent alpha. No image regeneration.',
        'approval':'input supplied, not output approval'}
    review.core.save_json(OUT/'source_manifest.json',manifest)
    spec=json.loads((ROOT/'data/work/political/kinki_chubu_registration/spec.json').read_text(encoding='utf-8'))
    spec['source']=str(target.relative_to(ROOT)).replace('\\','/')
    spec['source_offset']=list(offset)
    spec['coordinate_canvas_size']=[original.shape[1],original.shape[0]]
    spec['notes']='User-supplied Kinki crop. Pixel coordinates retain verified parent offset. Alpha is taken only from this crop.'
    review.core.save_json(OUT/'spec.json',spec)
    review.WORK=OUT
    review.registration.WORK=OUT
    review.registration.SPEC=OUT/'spec.json'
    review.build('kinki')

if __name__=='__main__':run()
