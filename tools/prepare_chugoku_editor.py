"""Package pre-repair Chugoku lines as a mutable, unapproved editor draft."""
import json
import shutil
from prepare_kinki_editor import ROOT, digest


def run():
    master = ROOT / 'data/master/political/chugoku/1.0.0/political_registry_master.json'
    work = ROOT / 'data/work/political/chugoku_shikoku_registration/chugoku'
    out = ROOT / 'data/derived/editor/chugoku'
    aligned = ROOT / 'data/work/political/chugoku_user_edits/aligned_draft.json'
    if aligned.exists():
        data = json.loads(aligned.read_text(encoding='utf-8'))
        assert data['status'] == 'editor_draft_only'
        out.mkdir(parents=True, exist_ok=True)
        (out / 'editor_draft.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        shutil.copyfile(work / 'warped_raster.png', out / 'reference.png')
        print('Packaged aligned user-edited Chugoku draft:', out)
        return
    data = json.loads(master.read_text(encoding='utf-8'))
    data.update(status='editor_draft_only', scope='chugoku', schema_version=1)
    data.pop('regions', None)
    data.pop('coastline_references', None)
    for boundary in data['boundaries']:
        boundary['review_status'] = 'pending_polygonization'
    data['reference_hashes'] = {p: digest(ROOT / p) for p in [
        'data/base/japan_land.gpkg', 'data/derived/coastline/coastline_master.gpkg',
        'data/derived/political/approved_western/political_registry.json']}
    data['source_draft_sha256'] = digest(master)
    data['coordinate_system'] = {'name': 'japan_land_master_8192', 'axes': 'x_right_y_down',
        'units': 'game_pixel', 'size': [8192, 8192], 'display_transform_applied': False}
    data['raster_georeference'] = json.loads((work / 'raster_georeference.json').read_text(encoding='utf-8'))
    out.mkdir(parents=True, exist_ok=True)
    (out / 'editor_draft.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    shutil.copyfile(work / 'warped_raster.png', out / 'reference.png')
    print('Packaged unconfirmed Chugoku editor draft:', out)


if __name__ == '__main__':
    run()
