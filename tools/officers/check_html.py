"""Offline structure/payload and JS syntax checks; does not start a browser."""
import json, shutil, subprocess, tempfile
from html.parser import HTMLParser
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

class Parser(HTMLParser):
    def __init__(self):super().__init__();self.scripts=[];self.current=None;self.ids=[]
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if 'id' in attrs:self.ids.append(attrs['id'])
        if tag=='script':self.current={'attrs':attrs,'text':''}
    def handle_data(self,data):
        if self.current is not None:self.current['text']+=data
    def handle_endtag(self,tag):
        if tag=='script' and self.current is not None:self.scripts.append(self.current);self.current=None

def main():
    page=Parser();page.feed((ROOT/'docs/officers/officers_1546.html').read_text(encoding='utf-8'))
    assert len(page.ids)==len(set(page.ids))
    payload=next(s for s in page.scripts if s['attrs'].get('type')=='application/json')
    data=json.loads(payload['text'])
    assert len(data['officers'])==data['stats']['roster_count']
    assert {s['id'] for s in data['officers']}.isdisjoint(s['id'] for s in data['excluded'])
    js=next(s['text'] for s in page.scripts if s['attrs'].get('type')!='application/json')
    node=shutil.which('node');assert node,'Node.js required for syntax check'
    with tempfile.TemporaryDirectory(prefix='officer-html-syntax-') as directory:
        file=Path(directory)/'roster.js';file.write_text(js,encoding='utf-8')
        subprocess.run([node,'--check',str(file)],check=True)
    report={'payload_records':len(data['officers']),'unique_html_ids':True,'js_syntax':'pass',
        'browser_visual_check':'not_performed',
        'browser_interaction_check':'not_performed'}
    (ROOT/'docs/officers/html_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':main()
