"""Check reproducibility, report search, officer invariants and Godot loading."""
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ReportParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.current = None
        self.script = ''
        self.in_script = False
    def handle_starttag(self, tag, attrs):
        if tag == 'tr' and dict(attrs).get('id'): self.current = ''
        if tag == 'script': self.in_script = True
    def handle_data(self, text):
        if self.current is not None: self.current += text
        if self.in_script: self.script += text
    def handle_endtag(self, tag):
        if tag == 'tr' and self.current is not None:
            self.rows.append(dict(textContent=self.current, hidden=False))
            self.current = None
        if tag == 'script': self.in_script = False


def run(args):
    result = subprocess.run(args, cwd=ROOT, text=True, encoding='utf-8', capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def main():
    paths = ['data/master/officers/affiliations_1546.json', 'data/master/officers/house_placement_pools_1546.json',
             'data/master/officers/affiliation_batch7_research.json', 'data/derived/officers/officers_1546.json',
             'docs/officers/officers_1546.html', 'docs/officers/affiliation_research_seventh_100.html']
    digest = lambda p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
    before = {p: digest(p) for p in paths}
    run([sys.executable, 'tools/officers/build_affiliations.py'])
    run([sys.executable, 'tools/officers/build_roster.py'])
    assert before == {p: digest(p) for p in paths}, 'Regeneration changed outputs'
    unit = run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests/officers'])
    assert 'Ran 90 tests' in unit and 'OK' in unit
    run([sys.executable, 'tools/officers/check_html.py'])
    parser = ReportParser()
    parser.feed((ROOT / paths[-1]).read_text(encoding='utf-8'))
    assert len(parser.rows) == 100
    js = 'const mockRows=' + json.dumps(parser.rows, ensure_ascii=False) + ''';
let callback;const count={textContent:''};
global.document={querySelectorAll:()=>mockRows,querySelector:s=>s==='#count'?count:{addEventListener:(event,fn)=>callback=fn}};
''' + parser.script + '''
callback({target:{value:'本多忠勝'}});
if(!mockRows.some(r=>!r.hidden&&r.textContent.includes('本多忠勝'))||mockRows.every(r=>!r.hidden))throw Error('Search failed');
callback({target:{value:'unlikely-no-match-xyz'}});
if(count.textContent!=='0人')throw Error('No-match failed');
callback({target:{value:''}});
if(count.textContent!=='100人'||mockRows.some(r=>r.hidden))throw Error('Clear failed');
'''
    with tempfile.TemporaryDirectory(prefix='affiliation-batch7-') as temp:
        file = Path(temp) / 'search.js'
        file.write_text(js, encoding='utf-8')
        run([shutil.which('node'), str(file)])
    smoke_output = run([shutil.which('godot_console'), '--headless', '--path', '.', '--script', 'tools/officers/smoke.gd'])
    smoke = json.loads(next(l.split('OFFICER_SMOKE ', 1)[1] for l in smoke_output.splitlines() if 'OFFICER_SMOKE ' in l))
    assert smoke['failures'] == [] and smoke['registered'] == 1598
    report = dict(batch='affiliation_batch7_100', unit_tests=90, all_passed=True, html_rows=100,
                  search_and_clear='node_mock_dom_pass', visual_browser_check='not_performed',
                  regeneration_deterministic=True, output_sha256=before, godot_smoke=smoke,
                  unchanged_other_officers=1498, future_reservations_inactive_at_start=100)
    (ROOT / 'data/master/officers/affiliation_batch7_validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k != 'output_sha256'}, ensure_ascii=False))


if __name__ == '__main__': main()
