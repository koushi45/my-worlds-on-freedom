"""Package every Stage F display region for an explicitly unconfirmed build."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/work/districts/stage_f'
DEST = ROOT / 'data/derived/districts/unconfirmed'


def build():
    index = json.loads((SOURCE / 'index.json').read_text(encoding='utf-8'))
    assert len({p['id'] for p in index['parents']}) == len(index['parents']) == 66
    assert len({r['key'] for r in index['regions']}) == len(index['regions']) == 748
    accepted = ROOT / 'data/derived/districts/accepted/index.json'
    before = accepted.read_bytes()
    old_prefix = 'res://data/work/districts/stage_f/'
    new_prefix = 'res://data/derived/districts/unconfirmed/'
    inventory = {}
    for record, field in [(p, 'file') for p in index['parents']] + [(r, 'mesh_file') for r in index['regions']]:
        original = record[field]
        assert original.startswith(old_prefix)
        relative = Path(original.removeprefix(old_prefix))
        assert '..' not in relative.parts and not relative.is_absolute()
        source, dest = SOURCE / relative, DEST / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        inventory[relative.as_posix()] = hashlib.sha256(dest.read_bytes()).hexdigest()
        record[field] = new_prefix + relative.as_posix()
    index['status'] = 'unconfirmed_preview'
    index['historical_adoption'] = False
    index['notice'] = '未確定版。全郡候補と未確定領域を表示。史料上の採用は保留。'
    for record in index['regions']:
        record['adoption'] = '未確定・保留'
        record['adoption_status'] = 'held'
    (DEST / 'index.json').write_text(json.dumps(index, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')
    inventory['index.json'] = hashlib.sha256((DEST / 'index.json').read_bytes()).hexdigest()
    manifest = dict(status='unconfirmed_preview', parents=66, regions=748,
        source_index_sha256=hashlib.sha256((SOURCE / 'index.json').read_bytes()).hexdigest(),
        accepted_registry_unchanged=before == accepted.read_bytes(), files=inventory)
    assert manifest['accepted_registry_unchanged']
    (DEST / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('UNCONFIRMED PACKAGE: 66 parents, 748 regions; accepted registry unchanged')
    from merge_small_districts import CONFIG, apply_merges
    if CONFIG.exists(): apply_merges(DEST)
    from name_unresolved_districts import apply_names
    apply_names(DEST)


if __name__ == '__main__':
    build()
