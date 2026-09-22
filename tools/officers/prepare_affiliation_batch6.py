"""Freeze the pre-sixth-batch input and create the new overlay once."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
MASTER = ROOT / 'data/master/officers'
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def write(p, v): p.write_text(json.dumps(v, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    assert not (MASTER / 'affiliation_batch6_baseline.json').exists(), 'Already frozen'
    roster = read(ROOT / 'data/derived/officers/officers_1546.json')['officers']
    names = {r['display_name']: r for r in roster}
    decisions = [l.split('|', 5) for l in (HERE / 'affiliation_batch6_decisions.txt').read_text(encoding='utf-8').splitlines() if l and not l.startswith('#')]
    selected = [dict(id=names[d[0]]['external_id'], name=d[0]) for d in decisions]
    assert len(selected) == len({s['id'] for s in selected}) == 100
    profiles = read(MASTER / 'affiliations_1546.json')['officers']
    assert all(not profiles[s['id']]['district_key'] for s in selected)
    assert sum(profiles[s['id']]['availability'] == 'not_born' for s in selected) == 80
    write(HERE / 'affiliation_batch6_selection.json', selected)
    write(MASTER / 'affiliation_batch6_baseline.json', dict(
        selected_ids=[s['id'] for s in selected], officers=profiles,
        protected_sha256={f: hashlib.sha256((MASTER / f).read_bytes()).hexdigest() for f in ['assessments.json', 'lineages.json', 'relationships.json']},
        lineages_baseline=read(MASTER / 'lineages_baseline.json'),
        selection_exclusions=['既存配置・調査済みの人物は除外', '死亡済み・明らかな別時代の人物は除外', '未誕生80人はユーザー承認済みの将来用仮配置。1546年には登場・出仕させない', '対馬など現在の郡地図にない地域のみが根拠の人物は今回対象外']))
    text = (HERE / 'apply_affiliation_batch5.py').read_text(encoding='utf-8')
    text = text.replace('Fifth 100-person placement overlay, after the four existing research batches.', 'Sixth 100-person overlay, including explicitly authorized future reservations.')
    text = text.replace('batch5', 'batch6').replace('batch 5', 'batch 6').replace('第5組', '第6組').replace('fifth_100', 'sixth_100')
    text = text.replace("assert a['availability'] not in ('not_born', 'deceased')", "assert a['availability'] != 'deceased'\n        if a['availability'] == 'not_born':\n            assert decision['role'] == '元服前'")
    start = text.index('    family_snapshot =')
    end = text.index('    rows = []', start)
    text = text[:start] + '''    relationships = read(MASTER / 'relationships.json')['officers']
    father_checks = {}
    selected_by_id = {s['id']: s for s in selected}

    def resolve_father(qid, visiting):
        if qid not in selected_by_id or profiles[qid]['role'] != '元服前':
            return profiles[qid]['house_id']
        if qid in visiting:
            raise AssertionError('Father cycle: ' + qid)
        if qid in father_checks:
            return profiles[qid]['house_id']
        decision = decisions[selected_by_id[qid]['name']]
        father_name = decision['father']
        if father_name:
            father_id = by_name.get(father_name, {}).get('external_id')
            basis = '人物紹介の実父表記を個別照合（養父・諸説は区別）'
        else:
            fathers = relationships[qid]['father']
            father_id = fathers[0]['external_id'] if len(fathers) == 1 and not fathers[0].get('qualifier_labels') else None
            basis = '既存の父子関係台帳を照合'
        if father_id not in profiles:
            father_id = None
        fid = resolve_father(father_id, visiting | {qid}) if father_id else None
        check = dict(father_name=father_name, father_id=father_id, basis=basis,
                     status='inherited' if fid else 'father_house_unknown' if father_id else 'father_unregistered_or_unresolved')
        if fid:
            profiles[qid]['house_id'] = fid
            check['house_id'] = fid
        father_checks[qid] = check
        return fid

    for s in selected:
        if profiles[s['id']]['role'] == '元服前':
            resolve_father(s['id'], set())

''' + text[end:]
    start = text.index('        supplements = {')
    end = text.index('        if name in supplements:', start)
    text = text[:start] + '''        supplements = {
            '伊達政宗': ('仙台市博物館・伊達政宗と戦国の世', 'https://www.city.sendai.jp/museum/kidscorner/kids-08/kidscorner/index.html', '1567年米沢出生、父伊達輝宗・母義姫の説明'),
            '井伊直虎': ('浜松市博物館・井伊直虎と湖北の戦国時代', 'https://www.city.hamamatsu.shizuoka.jp/hamahaku/02tenji/theme/iinaotora.html', '井伊谷の地縁と展示史料。出生年や1546年の身分確定には用いない'),
        }
''' + text[end:]
    start = text.index('        uncertain =')
    end = text.index('        a.update(', start)
    text = text[:start] + '''        reserved = before[qid]['availability'] == 'not_born'
        uncertain = by_name[name]['temporal_status'] != 'alive'
        if reserved:
            note += ' 未誕生の将来用仮配置。1546年には登場・出仕・開始時所属への組み込みを行わない。'
            a['future_placement_reserved'] = True
''' + text[end:]
    text = text.replace("availability='uncertain' if uncertain else 'available'", "availability='not_born' if reserved else 'uncertain' if uncertain else 'available'")
    text = text.replace("can_serve_at_start=bool(by_name[name]['start_present']) and not uncertain", "can_serve_at_start=bool(by_name[name]['start_present']) and not reserved and not uncertain")
    text = text.replace("stats=dict(total=100, placed=100,", "stats=dict(total=100, placed=100, future_reserved=sum(bool(r['after'].get('future_placement_reserved')) for r in rows),")
    text = text.replace('{"未確定" if a["availability"] == "uncertain" else "配置対象"}', '{"未誕生・将来用仮配置" if a.get("future_placement_reserved") else "未確定" if a["availability"] == "uncertain" else "配置対象"}')
    text = text.replace('未配置だった別の100人全員に、立場と配置郡を設定。', '未配置だった別の100人全員に、立場と配置郡を設定。うち{stats["future_reserved"]}人は未誕生の将来用仮配置で、1546年には登場・出仕させません。')
    text = text.replace('現在の地図に配置できる人物を選び、', '未誕生の仮配置は開始時配置と分けて保存します。現在の地図に配置できる人物を選び、')
    (HERE / 'apply_affiliation_batch6.py').write_text(text, encoding='utf-8')
