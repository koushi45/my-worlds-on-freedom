"""Readable site and route overlay ledgers, including all unresolved results."""
from pathlib import Path
from collections import Counter
from build_district_stage_c import ROOT, read
from build_district_stage_e import WORK, EDITOR

REASONS={
 'outside_current_parent_or_simplified_coast':'現行親領域外・簡略海岸等の照合待ち',
 'inside_unresolved_partition':'未確定区画内',
 'on_boundary_or_multiple_regions':'境界上・複数区画',
 'within_boundary_review_window':'境界付近（500m等の検査幅）',
 'registered_coordinate_inside_comparison_candidate':'比較候補内',
 'area_representative_coordinate_accuracy_unquantified':'地域代表点・誤差幅不明'}

def main():
    candidates={c['district_entity_id']:c['candidate_display_name'] for c in read('data/editorial/districts/districts.json')['districts']}
    regions={}
    for p in (ROOT/'data/work/districts/stage_d').glob('*/partition.json'):
        d=read(p)
        for r in d['regions']:
            regions[d['parent_region_id']+'/'+r['region_id']]=d['parent_region_id']+':'+('未確定' if r['kind']=='unresolved' else '/'.join(candidates.get(c,c) for c in r['candidate_refs']))
    sites=read(WORK/'site_assignments.json')['sites']
    lines=['# 工程E・拠点照合台帳','','判定は登録経緯度から計算。候補の包含と1582年の史料所属は別。境界付近の候補や距離、既存出典は[全件JSON](../../data/work/districts/stage_e/site_assignments.json)を参照。','','|対象|拠点ID・名称|登録座標の包含候補|状態・理由|史料比較|','|---|---|---|---|---|']
    for s in sorted(sites,key=lambda s:(s['scope']!='requested_254',s['site_id'])):
        names='、'.join(regions[r['key']] for r in s.get('containing_regions',[])) or '包含なし'
        compare={'unverified_no_adopted_district_evidence':'所属史料未確認','conflict_requires_individual_review':'文献所属と不一致・保留','consistent_with_comparison_geometry':'比較資料と一致・対象年未確定'}.get(s['historical_comparison'],s['historical_comparison'])
        lines.append(f'|{"254件" if s["scope"]=="requested_254" else "追加枠"}|`{s["site_id"]}` {s.get("display_name","")}|{names}|{s["assignment_status"]}：'+ '／'.join(REASONS.get(x,x) for x in s['reasons'])+f'|{compare}|')
    (ROOT/'docs/districts/STAGE_E_SITES.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    lines=['# 工程E・推定連絡路の通過順','','元の点列順（from_site → to_site）で記録。未確定・表示区画外も省略しない。郡の再訪は順序に残す。道路の出入口は城の郡所属の代わりに使わない。区画名の前は親領域ID。','','|路線|通過区画の順序|境界イベント|派生データ|','|---|---|---:|---|']
    for p in sorted((WORK/'routes').glob('*.json')):
        r=read(p);sequence=[]
        for i in r['intervals']:
            name=' + '.join(regions[k] for k in i['region_keys']) or '表示区画外'
            if i['status']=='boundary_run': name+='（境界沿い）'
            if i['status']=='numeric_contact_interval': name+='（数値接点・通過郡未判定）'
            if not sequence or sequence[-1]!=name: sequence.append(name)
        lines.append(f'|`{r["route_id"]}` {r["name"]}|'+ ' → '.join(sequence)+f'|{len(r["boundary_events"])}|[区間・通過点](../../data/work/districts/stage_e/routes/{p.name})|')
    (ROOT/'docs/districts/STAGE_E_ROADS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('Site and route ledgers generated')

if __name__=='__main__': main()
