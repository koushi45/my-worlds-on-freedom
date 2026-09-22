"""One-time integration of the sixth batch's explicit preservation boundary."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
def edit(relative, transform):
    p = ROOT / relative
    p.write_text(transform(p.read_text(encoding='utf-8')), encoding='utf-8')

if __name__ == '__main__':
    master = ROOT / 'data/master/officers'
    assert not (master / 'affiliation_batch6_migration.json').exists(), 'Already migrated'
    for i in [2, 3, 4]:
        edit(f'tests/officers/test_affiliation_batch{i}.py', lambda s: s.replace(
            "        fifth = read(MASTER / 'affiliation_batch5_baseline.json')",
            "        fifth = read(MASTER / 'affiliation_batch5_baseline.json')\n        sixth = read(MASTER / 'affiliation_batch6_baseline.json')"
        ).replace("set(fifth['selected_ids'])", "set(fifth['selected_ids']) | set(sixth['selected_ids'])"))
    edit('tests/officers/test_affiliation_batch5.py', lambda s: s.replace(
        '        self.assertEqual(selected, {q for q, a in self.profiles.items()',
        "        sixth = read(MASTER / 'affiliation_batch6_baseline.json')\n        self.assertEqual(selected | set(sixth['selected_ids']), {q for q, a in self.profiles.items()"))
    edit('tests/officers/test_affiliations.py', lambda s: s.replace("for n in ['伊達政宗','本多忠勝']:", "for n in ['本多忠勝']:"))
    def template(s):
        s = s.replace('未誕生・故人は開始時の配置対象外です。', '未誕生・故人は開始時の配置対象外です。承認済みの未誕生者の郡は「将来用仮配置」と表示し、開始時配置には使いません。')
        s = s.replace("${esc(r.affiliation_1546?.district_display??'未配置')}</td>", "${esc(r.affiliation_1546?.district_display??'未配置')}${r.affiliation_1546?.future_placement_reserved?'<br><small>将来用仮配置</small>':''}</td>")
        s = s.replace('<h3>1546年の所属と配置</h3>', "<h3>${f.future_placement_reserved?'将来用仮配置（1546年には未登場）':'1546年の所属と配置'}</h3>")
        marker=";for(const url of f.source_urls||[])"
        extra=";if(f.scenario_batch==='affiliation_batch6_100')content+=`<p><b>追加調査・第6組：</b>${esc(f.scenario_confidence)}<br><a href=\"affiliation_research_sixth_100.html#${esc(r.external_id)}\">この人物の判断・父の照合・出典を見る</a></p>`"
        assert marker in s
        return s.replace(marker, extra+marker)
    edit('tools/officers/roster_template.html', template)
    p = master / 'lineages_baseline.json'
    value = json.loads(p.read_text(encoding='utf-8'))
    old = value['affiliations_sha256']
    data = json.loads((master / 'affiliations_1546.json').read_text(encoding='utf-8'))
    value['affiliations_sha256'] = hashlib.sha256(json.dumps(data, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (master / 'affiliation_batch6_migration.json').write_text(json.dumps(dict(
        reason='ユーザー依頼の次の100人。未誕生80人の将来用仮配置を明示承認。既存1498人と能力・家系・親子台帳は保持。',
        previous_affiliations_sha256=old, affiliations_sha256=value['affiliations_sha256'],
        selected_ids=json.loads((master / 'affiliation_batch6_baseline.json').read_text(encoding='utf-8'))['selected_ids']
    ), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
