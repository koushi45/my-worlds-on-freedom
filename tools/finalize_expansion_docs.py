"""Refresh documentation for the adopted 250-place edition."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def run():
    summary='城・主要集落・港を合計250拠点に拡張しました。地方別の比率を維持し、同じ都市・城下の9件を統合して別の場所を204件追加しています。上部の「1582年・250拠点」と「城」「集落」「港」で表示を切り替え、「拠点一覧・検索」から地域・名称で探せます。平面・立体の両表示に対応。年代・位置は推定を含む地域代表点で、全史料の網羅調査・精密比定は未完了です。'
    for rel in ['README.md','builds/windows-latest/README.md']:
        p=ROOT/rel;lines=p.read_text(encoding='utf-8').splitlines()
        lines=[summary+(' [配分と統合方針](docs/settlements/EXPANSION_250.md)・[配置台帳](docs/settlements/PLACEMENT_1582.md)・[検証記録](docs/settlements/QA_1582.md)。' if rel=='README.md' else ' 配分と統合方針は SETTLEMENTS-250.md、全台帳は SETTLEMENTS-1582.md、検証は SETTLEMENTS-QA.md。') if x.startswith('城・主要集落・港の独立レイヤーを追加しました。') else x.replace('176拠点','道路用176地点') for x in lines]
        p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    p=ROOT/'docs/ROAD_CONNECTIONS_1582_WORK_INSTRUCTIONS.md';s=p.read_text(encoding='utf-8').replace('採用55、保留3、対象外2','採用250、保留3、非表示11（年代除外2・統合9）').replace('55地点','250地点').replace('最初は250地点を対象とし','現在は250の独立拠点を対象とし');p.write_text(s,encoding='utf-8')
    p=ROOT/'docs/SETTLEMENTS_1582_WORK_INSTRUCTIONS.md';s=p.read_text(encoding='utf-8');s=s.replace('状態：配置作業のための手順書。新規拠点データ・表示機能は本書作成時点では未実装。','状態：配置機能と全国250拠点版を実装済み。\n\n更新方針：後続のユーザー指定に従い、地方別比率を維持して約250拠点を選定する。同じ都市・城下の城・町・港は構成要素として統合し、複数拠点として水増ししない。初期手順の件数・分割方針より、この指定を優先する。配分・統合と推定の扱いは [全国250拠点版](settlements/EXPANSION_250.md) を参照。');p.write_text(s,encoding='utf-8')
    # Keep source discovery metadata, not long copyrighted search excerpts.
    folder=ROOT/'data/editorial/settlements/expansion_250'
    for p in list(folder.glob('research_*.json'))+list(folder.glob('refinement_*.json')):
        records=json.loads(p.read_text(encoding='utf-8'))
        for r in records:
            raw=r.pop('raw',None);r.pop('selected',None)
            if raw:
                r['discovered_urls']=list(dict.fromkeys(re.findall(r'\((https?://[^\s)]+)\)',raw)))
                r['scope']='検索結果の候補URL。採用根拠は正本sources.jsonの選定済み資料のみ。本文抜粋は再配布しない。'
        p.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    master=json.loads((ROOT/'data/editorial/settlements/settlements_1582.json').read_text(encoding='utf-8'))
    lookup={s['id']:s for s in master['sites']}
    p=folder/'adopted_additions.json';rows=json.loads(p.read_text(encoding='utf-8'))
    for r in rows:
        id=f'site_1582_{r["province"]}_{r["index"]:03}';s=lookup[id]
        r['final_master_id']=id;r['final_lonlat']=s['lonlat'];r['final_location_note']=s['location_note']
        r['scope']='追加時の転記記録。最終座標はfinal_lonlat、以後の編集は拠点正本を参照。'
    p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':run()
