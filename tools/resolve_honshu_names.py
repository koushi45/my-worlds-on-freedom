"""Record visual label matches from the user-supplied Ryoseikoku map."""
import copy
import shutil
from datetime import datetime, timezone
from finalize_honshu_edits import ROOT, read, save, digest

def run():
    old = ROOT/'data/master/political/honshu/1.0.0'
    target = old.parent/'1.0.1'
    assert not target.exists(), 'Version already frozen'
    reference = ROOT/'data/work/political/honshu_names/reference.png'
    reference.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile('C:/Users/nanoa/Downloads/Ancient_Provinces_of_Japan_Ryoseikoku_Map (1).png', reference)
    data = read(old/'political_registry_master.json')
    before = copy.deepcopy(data)
    # Stable region IDs and every coordinate remain unchanged.
    matches = {
        'honshu-area-01': ('陸奥国', 'G'),
        'honshu-area-03': ('羽後国', 'E'),
        'honshu-area-04': ('陸中国', 'F'),
        'honshu-area-05': ('陸前国', 'D'),
        'honshu-area-06': ('羽前国', 'C'),
        'honshu-area-08': ('磐城国', 'B'),
        'honshu-area-09': ('岩代国', 'A'),
        'honshu-area-30': ('安房国', '59'),
    }
    unresolved = {
        'honshu-area-02': '本州北部の細い領域。参考画像の独立した国との対応を判別できない。',
        'honshu-area-15': '参考画像の上野国（65）と下総国（57）に相当する箇所が同じ領域につながっており、一国に対応しない。',
        'honshu-area-36': '参考画像の摂津国（38）と和泉国（37）に相当する箇所を含み、一国に対応しない。',
    }
    review = []
    for region in data['regions']:
        key = region['region_id']
        if key in matches:
            name, label = matches[key]
            region.update(name_ja=name, name_status='reference_matched', name_reference={'file': str(reference.relative_to(ROOT)), 'label': label, 'method': 'visual position and neighboring province comparison'})
        if key in unresolved:
            assert region['name_status'] == 'unconfirmed'
            review.append({'region_id':key, 'name_ja':region['name_ja'], 'reason':unresolved[key]})
    assert len(review) == 3
    assert [r['polygons'] for r in before['regions']] == [r['polygons'] for r in data['regions']]
    for key in ['boundaries','boundary_references','coastlines','coastline_references']:
        assert before[key] == data[key]
    shutil.copytree(old, target)
    data['version'] = '1.0.1'
    save(target/'political_registry_master.json', data)
    save(target/'name_review.json', review)
    save(target/'name_resolution.json', {'reference_file':str(reference.relative_to(ROOT)), 'reference_sha256':digest(reference), 'matches':matches, 'unresolved':unresolved, 'geometry_unchanged':True})
    manifest = read(old/'political_master_manifest.json')
    manifest.update(version='1.0.1', name_status='8 names resolved from supplied map; 3 unresolved regions shown in red')
    manifest['approval'] = {'approved_by':'user', 'recorded_at_utc':datetime.now(timezone.utc).isoformat(), 'instruction':'この画像で国名を判断できる箇所の国名を埋めて下さい。国名が不明な個所は赤色で塗りつぶして下さい。その後ビルドをお願いします。'}
    manifest['files'] = {p.name:digest(p) for p in target.iterdir() if p.is_file() and p.name != 'political_master_manifest.json'}
    save(target/'political_master_manifest.json', manifest)
    save(target.parent/'status.json', {'status':'approved','current_version':'1.0.1'})
    print('Resolved 8 names; 3 unresolved; all geometry unchanged')

if __name__ == '__main__':
    run()
