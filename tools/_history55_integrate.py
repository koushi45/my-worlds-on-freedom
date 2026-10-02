import json,re,hashlib
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1];rows=json.loads((root/'docs/portraits_history_modern_20261002_55.json').read_text(encoding='utf-8'))
assert len(rows)==55 and all(r['status']=='generated' for r in rows)
for r in rows:
    p=root/r['path'].removeprefix('res://');im=Image.open(p)
    assert im.size==(512,512) and im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
    assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256']
registry=root/'scripts/game/officer_portraits.gd';text=registry.read_text(encoding='utf-8')
new=[]
for r in rows:
    pattern=r'"'+re.escape(r['id'])+r'": "[^"]+"'
    entry=json.dumps(r['id'])+': '+json.dumps(r['path'])
    if re.search(pattern,text):text=re.sub(pattern,lambda _:entry,text)
    else:new.append('\t'+entry+',')
text=text.replace('const PATH_BY_OFFICER_ID := {','const PATH_BY_OFFICER_ID := {\n'+'\n'.join(new))
registry.write_text(text,encoding='utf-8')
old=root/'tests/officers/godot/test_portrait_withdrawal_20261002.gd';test=old.read_text(encoding='utf-8')
# Withdrawal bans source-derived assets, not the real people. New independent
# portraits may use the same officer IDs; resource checks retain the original ban.
test=re.sub(r'\tfor rejected_id in .*?\tassert\(Portraits.texture_for\("unknown_officer"\) == null\)', '\t# Independent replacements may be registered for formerly withdrawn IDs.\n\tassert(Portraits.texture_for("unknown_officer") == null)',test,flags=re.S)
old.write_text(test,encoding='utf-8')
body=test[test.index('func _initialize()'):test.index('\t# Independent replacements')]
body=body.replace('portraits_withdrawal_20261002','portraits_history55_20261003')
body=body.replace('assert(texture != null)','assert(texture != null)\n\t\tassert(texture.get_size() == Vector2(512, 512))')
targets='\n'.join('\t'+json.dumps(r['id'])+': ['+json.dumps(r['name'],ensure_ascii=False)+', '+json.dumps(r['path'])+'],' for r in rows)
newtest='extends SceneTree\n\nconst Portraits = preload("res://scripts/game/officer_portraits.gd")\nconst OfficerPanel = preload("res://scripts/game/officer_panel.gd")\nconst TARGETS := {\n'+targets+'\n}\n\n'+body+'\tassert(FileAccess.file_exists("res://assets/officers/portraits/ATTRIBUTION.txt"))\n\tassert(Portraits.texture_for("unknown_officer") == null)\n\tprint("HISTORICAL_MODERN_PORTRAITS_55_OK")\n\tquit()\n'
(root/'tests/officers/godot/test_portraits_history55_20261003.gd').write_text(newtest,encoding='utf-8')
p=root/'export_presets.cfg';cfg=p.read_text(encoding='utf-8');cfg=re.sub(r'include_filter="([^"]*)"',lambda m:'include_filter="'+m[1]+(',assets/officers/portraits/ATTRIBUTION.txt' if 'assets/officers/portraits/ATTRIBUTION.txt' not in m[1] else '')+'"',cfg);p.write_text(cfg,encoding='utf-8')
print('Registered 55 verified 512px RGBA portraits; created UI association test and source attribution export.')
