"""Game settings layered over historical research; unknown employer can have a location."""
import collections
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'
ROLES = {'大名', '大名家一門', '武将', '浪人', '元服前'}


def read(p):
    return json.loads(p.read_text(encoding='utf-8'))


def write(p, value):
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def classify(a):
    old = a['role']
    if any(w in old for w in ('幼少', '元服前', '未誕生', '若年')):
        return '元服前'
    if not a['house_id']:
        return '浪人'
    if any(w in old for w in ('一門', '後継者', '領主の子')):
        return '大名家一門'
    if any(w in old for w in ('大名', '領主・当主', '国人領主', '領主（', '守護', '将軍')):
        return '大名'
    return '武将'


def apply(master, house_list, districts, roster):
    write(MASTER/'affiliation_historical_1546.json', master)
    data = copy.deepcopy(master)
    profiles = data['officers']
    houses = {h['id']: copy.deepcopy(h) for h in house_list}
    by_name = {r['display_name']: r for r in roster}
    by_key = {d['key']: d for d in districts}

    def district(country, name):
        matches = [d for d in districts if d['country'] == country and d['name'] == name]
        assert len(matches) == 1, (country, name)
        return matches[0]['key']

    key = district('尾張国', '海東郡')
    source = 'https://ja.wikipedia.org/wiki/%E7%B9%94%E7%94%B0%E4%BF%A1%E6%AC%A1'
    houses['oda_nobutsugu'] = dict(id='oda_nobutsugu', display_name='織田家（信次）', head_reference='織田信次',
        pool=[key], district_names=['尾張国・海東郡'], basis='ユーザー指定の独立家中。初期の深田城を位置の手掛かりとするゲーム設定。',
        note='信次は信秀の弟。深田城の記録は1552年、守山入城は1555年。1546年への領地設定はゲーム上の採用で、同年支配の確証ではない。',
        source_urls=[source], status='user_scenario_setting', parent_house_id='oda_nobuhide')
    for q, a in profiles.items():
        a['historical_role'] = a['role']
        a['historical_reason'] = a['reason']
        a['role'] = classify(a)
        a['historical_status'] = a['status']
        a['availability'] = 'not_born' if a['status']=='unborn' else 'deceased' if a['status']=='deceased' else 'uncertain' if a['status'] in ('same_year_ambiguous','unresolved') else 'available'
        a['placement_house_id'] = a['house_id'] if a['district_key'] else None
        a['placement_policy'] = 'existing_house_pool' if a['district_key'] else 'none'
        if a['role']=='元服前' or a['availability'] in ('not_born','deceased'):
            a['can_serve_at_start'] = False
    def p(name):
        q = by_name[name]['external_id']
        return q, profiles[q]

    def choose(q, pool):
        return min(pool, key=lambda k: hashlib.sha256(('scenario-1546-v1:'+q+':'+k).encode()).hexdigest())

    def place(a, key, basis, placement_house=None):
        d = by_key[key]
        a.update(district_key=key, district_display=d['country']+'・'+d['name'],
            district_geometry_status=d['adoption'], assignment_kind='gameplay_distributed_not_historical_residence',
            placement_house_id=placement_house, placement_policy='user_scenario_location', placement_reason=basis,
            scenario_override=True)

    for name, fid in [('市橋長利','saito'), ('丹羽氏勝','oda_nobutsugu')]:
        q, a = p(name)
        a.update(house_id=fid, house_display=houses[fid]['display_name'], role='武将', status='scenario',
                 reason='ユーザー指定のゲーム設定：'+houses[fid]['display_name']+'に武将として所属。史料上の判断は別途記録。',
                 can_serve_at_start=bool(by_name[name]['start_present']))
        counts = collections.Counter(v['district_key'] for other, v in profiles.items() if other != q and v['house_id']==fid and v['district_key'])
        pool = houses[fid]['pool']
        least = min(counts[k] for k in pool)
        place(a, choose(q,[k for k in pool if counts[k]==least]), houses[fid]['note'], fid)
        if name=='丹羽氏勝':
            a['source_urls'] = list(dict.fromkeys(a['source_urls']+[source]))
    for name, country, dname, basis in read(Path(__file__).with_name('affiliation_scenario_locations.json')):
        q, a = p(name)
        assert a['availability'] not in ('not_born','deceased'), name
        fid = country[1:] if country.startswith('@') else None
        key = choose(q,houses[fid]['pool']) if fid else district(country,dname)
        a.update(house_id=None, house_display='不明', role='浪人', status='scenario',
                 reason='所属は不明。地域情報からのゲーム配置。史料上の立場：'+a['historical_role'])
        place(a,key,basis,fid)
        # Placement does not settle conflicting identities, dates, or imprisonment.
        a['can_serve_at_start'] = bool(by_name[name]['start_present']) and name not in ('大井貞隆','小早川弘景 (二代)','国分盛顕','水野近守','須田永秀','一柳宣高','仁木義広','細川通政','山中氏頼','長野賢忠','牧野成敏','清田鎮忠')
    from apply_affiliation_batch2 import apply as apply_batch2
    apply_batch2(data, houses, districts, by_name)
    from apply_affiliation_batch3 import apply as apply_batch3
    apply_batch3(data, houses, districts, by_name)
    from apply_affiliation_batch4 import apply as apply_batch4
    apply_batch4(data, houses, districts, by_name)
    from apply_affiliation_batch5 import apply as apply_batch5
    apply_batch5(data, houses, districts, by_name)
    from apply_affiliation_batch6 import apply as apply_batch6
    apply_batch6(data, houses, districts, by_name)
    from apply_affiliation_batch7 import apply as apply_batch7
    apply_batch7(data, houses, districts, by_name)
    from apply_affiliation_batch8 import apply as apply_batch8
    apply_batch8(data, houses, districts, by_name)
    from apply_affiliation_batch9 import apply as apply_batch9
    apply_batch9(data, houses, districts, by_name)
    from apply_affiliation_batch10 import apply as apply_batch10
    apply_batch10(data, houses, districts, by_name)
    from apply_affiliation_batch11 import apply as apply_batch11
    apply_batch11(data, houses, districts, by_name)
    for a in profiles.values():
        assert a['role'] in ROLES
    data['schema_version'] = 2
    data['policy'] = '所属家と配置先は独立。立場は5種。所属不明でも地縁・後年記録を手掛かりに浪人配置できる。史料判断とユーザー指定のゲーム設定は分離。出生前の承認済み仮配置は将来用予約として保存し、出生前・故人は開始時未配置。'
    data['stats'] = dict(collections.Counter(a['status'] for a in profiles.values()))
    data['stats'].update(total=len(profiles),with_house=sum(bool(a['house_id']) for a in profiles.values()),placed=sum(bool(a['district_key']) for a in profiles.values()))
    write(MASTER/'affiliations_1546.json', data)
    write(MASTER/'house_placement_pools_1546.json', dict(schema_version=2,year=1546,houses=list(houses.values())))
    return data, houses
