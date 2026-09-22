"""Real-package integration in an isolated project; never adopts production data."""
import unittest, tempfile, shutil, sys, subprocess, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
import manage_district_stage_g as g

def decision(packet,ref='test-only-v1'):
    return dict(parent=packet['parent'],revision=packet['revision'],status='accepted',reason='TEST ONLY simulated decision',
        decision_ref=ref,mapping_decision='TEST ONLY retain current partition',temporal_decision='TEST ONLY game estimate',
        distribution_scope='noncommercial',region_decisions={r:'accepted_unresolved_area' if packet['region_kinds'][r]=='unresolved' else 'accepted_game_estimate' for r in packet['region_ids']})

class ReleaseTests(unittest.TestCase):
    def test_country_isolation_and_fail_closed(self):
        production_before=g.sha(g.RUNTIME/'index.json')
        with tempfile.TemporaryDirectory(prefix='district-g-',dir=g.ROOT/'data/work/districts/stage_g') as temp:
            root=Path(temp);runtime=root/'data/derived/districts/accepted';master=root/'archive'
            def package(pid):
                pointer=g.read(g.EDITOR/'countries'/f'{pid}.json');path=g.ROOT/pointer['package']
                return path,g.read(path/'packet.json')
            path,p=package('izumi');other_path,q=package('kawachi')
            g.initialize(runtime);baseline=g.sha(runtime/'index.json')
            for bad in [dict(decision(p),status='held'),dict(decision(p),revision='stale'),dict(decision(p),region_decisions={}),dict(decision(p),mapping_decision='')]:
                with self.assertRaises(ValueError): g.integrate('izumi',bad,path,runtime,master)
                self.assertEqual(baseline,g.sha(runtime/'index.json'))
            a=g.integrate('izumi',decision(p),path,runtime,master)
            b=g.integrate('kawachi',decision(q),other_path,runtime,master)
            before={p.relative_to(runtime).as_posix():g.sha(p) for p in (runtime/'releases/kawachi').rglob('*') if p.is_file()}
            bmeta=[r for r in g.read(runtime/'index.json')['regions'] if r['parent']=='kawachi']
            a2=g.integrate('izumi',decision(p,'test-only-v2'),path,runtime,master)
            self.assertNotEqual(a['release_id'],a2['release_id'])
            g.rollback('izumi',a['release_id'],runtime,master)
            self.assertEqual(g.verify(runtime)['accepted_parents'],2)
            self.assertEqual(bmeta,[r for r in g.read(runtime/'index.json')['regions'] if r['parent']=='kawachi'])
            self.assertEqual(before,{p.relative_to(runtime).as_posix():g.sha(p) for p in (runtime/'releases/kawachi').rglob('*') if p.is_file()})
            # Accepted-only layer actually loads in a temporary Godot project.
            (root/'scripts/map').mkdir(parents=True)
            shutil.copyfile(g.ROOT/'scripts/map/district_layer.gd',root/'scripts/map/district_layer.gd')
            for name in ['line_mesh_batch.gd','line_mesh.gdshader']:
                shutil.copyfile(g.ROOT/'scripts/map'/name,root/'scripts/map'/name)
            shutil.copyfile(g.ROOT/'tests/base_map/godot/test_district_release.gd',root/'test.gd')
            (root/'project.godot').write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
            result=subprocess.run([shutil.which('godot_console'),'--headless','--path',str(root),'--script','res://test.gd'],capture_output=True,text=True,encoding='utf-8',timeout=45)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('ACCEPTED DISTRICT RUNTIME: PASS',result.stdout)
            g.rollback('izumi','none',runtime,master)
            self.assertEqual(g.verify(runtime)['accepted_parents'],1)
            self.assertEqual(before,{p.relative_to(runtime).as_posix():g.sha(p) for p in (runtime/'releases/kawachi').rglob('*') if p.is_file()})
            self.assertFalse(any(r['parent']=='izumi' for r in g.read(runtime/'index.json')['regions']))
            # Stored release edits cannot silently change a rollback target.
            file=master/'izumi'/a['release_id']/'geometry.json';file.write_text('{}',encoding='utf-8')
            with self.assertRaises(ValueError): g.rollback('izumi',a['release_id'],runtime,master)
            # Packet metadata cannot be amended under an old decision hash.
            altered=root/'tampered';shutil.copytree(path,altered)
            packet=g.read(altered/'packet.json');packet['metadata'][0]['name']='tampered'
            g.write(altered/'packet.json',packet)
            with self.assertRaises(ValueError): g.integrate('izumi',decision(p),altered,runtime,master)
        self.assertEqual(production_before,g.sha(g.RUNTIME/'index.json'))

if __name__=='__main__': unittest.main()
