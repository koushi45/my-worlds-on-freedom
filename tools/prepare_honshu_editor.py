"""Package the unconfirmed eastern Honshu trace for the border editor."""
import json
import shutil
from prepare_kinki_editor import ROOT

def run():
    work=ROOT/'data/work/political/honshu_remaining'
    out=ROOT/'data/derived/editor/honshu'
    data=json.loads((work/'editor_draft.json').read_text(encoding='utf-8'))
    assert data['status']=='editor_draft_only' and data['scope']=='honshu'
    out.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(work/'editor_draft.json',out/'editor_draft.json')
    shutil.copyfile(work/'source.png',out/'reference.png')
    print('Packaged Honshu pending borders:',len(data['boundaries']))

if __name__=='__main__':run()
