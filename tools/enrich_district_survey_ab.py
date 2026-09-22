"""Apply the recorded first-pass editorial findings once, preserving raw names.

This is the initial research migration, not a tool to overwrite later research.
Source HTML must already be cached; all decisions retain their exact locators.
"""
from copy import deepcopy
import prepare_district_ledgers as d


def main():
    target = d.OUT/'review_decisions.json'
    if target.exists():
        raise SystemExit('Initial review already applied; edit later findings explicitly.')
    districts = d.read(d.OUT/'districts.json')
    sources = d.read(d.OUT/'sources.json')
    scope = d.read(d.OUT/'scope.json')
    reviews = d.read(d.OUT/'country_reviews.json')
    mappings = d.read(d.OUT/'province_mapping.json')
    rows = districts['districts']
    log = {r['source_id']:r for r in d.read(d.CACHE/'retrieval_log.json')['records']}
    specs = [
        ('kai-four','山梨県：県民の日とは？','山梨県','甲斐の四郡と現在の山梨県',
         '往古〜1878年の4郡と1878年12月の9郡への分割を説明。現代の回顧解説。',
         '四郡の名称と後世再編。1582年の境界位置の証明ではない。'),
        ('shinano-ten','長野市誌 第十五巻 総集編','長野市（ADEAC公開）','延喜式に基づく信濃10郡の列挙段落',
         '平安期の延喜式を引く現代市誌の説明。対象年より前の区分。',
         '古い郡候補の追加根拠。1582年までの継続や分割時点は未確認。'),
        ('hinenosho','日根荘遺跡とは','泉佐野市文化財課','ページID3676、日根荘遺跡とは／国史跡日根荘遺跡指定地一覧',
         '鎌倉〜戦国期荘園の解説。更新2025-06-10。',
         '九条家文書・日根野村絵図・政基公旅引付と遺跡所在地への調査入口。荘園を郡と同一視しない。'),
        ('kagawa-shiwaku','那珂郡塩飽島見勢家文書（香川県史編纂資料）','香川県立文書館',
         '文書群9188、9188-001「瀬居嶋一件記録 全」、9188-002「干潟一件記録」',
         '目録。9188-002は享和2〜3年。原文書は未閲覧。',
         '塩飽島に機械的に郡を付けないための区画種別確認。目録上の那珂郡表記を1582年に遡及しない。'),
    ]
    for sid,title,publisher,locator,period,use in specs:
        assert log[sid]['status']=='retrieved'
        sources['sources'].append(dict(source_id=sid,title=title,publisher=publisher,url=log[sid]['url'],
            represented_period=period,publication_date='ページの記載範囲で確認。未記載の刊行年月は不明。',
            locator=locator,temporal_basis='earlier_comparison' if sid=='shinano-ten' else 'retrospective',
            retrieval=log[sid],use=use,
            rights=dict(status='individual_reuse_terms_unverified',url=log[sid]['url'],locator='個別転載条件は未確認',
                use_performed=['本文・目録参照','調査用HTML保存'],images_downloaded=False,geometry_downloaded=False,export_allowed=False)))
    sources['sources'].append(dict(source_id='nai-genroku-izumi',title='和泉国（元禄）',publisher='国立公文書館',
        url='https://www.digital.archives.go.jp/gallery/0000000226',
        represented_period='元禄国絵図の模写本。案内本文は1696年作成命令、1702年頃全国完成と説明。模写年は未確認。',
        publication_date=None,temporal_basis='later_comparison',
        locator='ギャラリー0000000226、画像名010_izumi.jp2、IIIF manifest 764247',
        manifest_url='https://www.digital.archives.go.jp/api/iiif/764247/manifest.json',
        retrieval=dict(status='web_reviewed_cache_unavailable',reviewed_on='2026-09-12',
            method='webツールでギャラリー本文を確認。画像・manifest内容は未閲覧。',local_fetch_attempt=log['nai-genroku-izumi']),
        use='郡別の村名色分けを含む模写本の所在。今回の位置証拠には未使用。',
        rights=dict(status='individual_image_reuse_terms_unverified',url='https://www.digital.archives.go.jp/gallery/0000000226',
            locator='個別画像の利用条件未確認',use_performed=['本文参照と図版所在の記録のみ'],
            images_downloaded=False,geometry_downloaded=False,export_allowed=False)))
    decisions=[]
    def decision(key, ids, topic, note, refs):
        decisions.append(dict(decision_id=key,district_entity_ids=ids,topic=topic,decision=note,evidence=refs))
    # Apply a second source to all 42 Osaka / Yamato names it actually lists.
    # The five Hyogo-area Settsu districts are NOT covered by this Osaka article.
    settsu_osaka={'西成','東成','住吉','豊島','能勢','島上','島下'}
    osaka_ids=[]
    for row in rows:
        rid=row['candidate_parent_region_ids'][0]
        if rid in ['izumi','kawachi','yamato'] or (rid=='settsu' and row['source_name'] in settsu_osaka):
            row['source_refs'].append('osaka-archives38')
            loc='p.1 三新法体制下と郡長・郡役所／'+('大和15郡の郡役所列挙' if rid=='yamato' else '摂津・河内・和泉27郡の列挙')
            row['evidence']['name_existence'].append(d.reference('osaka-archives38',loc,
                supports='明治期の名称列挙による照合。名称異同は個別判断を参照。',target_year_supported=False))
            osaka_ids.append(row['district_entity_id'])
    decision('ab-osaka-names',osaka_ids,'later_name_corroboration',
        '大阪府公文書館の明治期27郡＋大和15郡を照合。摂津の兵庫県側5郡にはこの証拠を付与しない。境界も1582年の存在も確定しない。',
        [d.reference('osaka-archives38','p.1 三新法体制下と郡長・郡役所')])
    for row in rows:
        name=row['source_name']; rid=row['candidate_parent_region_ids'][0]
        row['unit_type']='district_candidate'
        if rid=='izumi' and name=='泉':
            row['aliases'].append(dict(name='和泉',status='later_source_variant',source_ref='osaka-archives38',locator='p.1 27郡の列挙「和泉」／郡役所説明「泉」'))
            row['temporal_difference']='後世資料で泉／和泉の両表記を確認。1582年の表記と国境沿いの所属を未確認。'
        if rid=='yamato' and name=='宇蛇':
            row['candidate_display_name']='宇陀郡'
            row['source_refs'].append('uda-history')
            row['name_correction_status']='editorial_preferred_name; source spelling retained, not assumed historical alias'
            row['evidence']['name_existence'].append(d.reference('uda-history','近世・天正13年（1585年）の宇陀郡の記述',supports='宇陀の表記と1585年についての回顧説明',target_year_supported=False))
            row['evidence']['target_period'].append(d.reference('uda-history','近世・1585年段落',supports='対象年の3年後の記述からの候補。1582年の直接確認ではない。',target_year_supported=False))
            row['temporal_difference']='原一覧は宇蛇。大阪府公文書館と宇陀市の宇陀表記を優先する編集案。1585年の回顧記述あり、1582年は未確定。'
            decision('ab-uda-spelling',[row['district_entity_id']],'name_correction',row['temporal_difference'],
                [d.reference('kg-K02','#gun-list G02005 宇蛇'),d.reference('osaka-archives38','p.1 大和15郡列挙'),d.reference('uda-history','近世・1585年')])
        if rid=='izumi' and name=='日根':
            row['source_refs'].extend(['hinenosho','nai-genroku-izumi'])
            row['location_leads'].append(d.reference('hinenosho','ページID3676、九条家文書・日根野村絵図・政基公旅引付の紹介',
                reviewed=True, note='紹介本文を確認。原文書・図版は未判読。日根荘の所在地を日根郡全域の境界証拠に転用しない。'))
        if rid=='sanuki' and name in ['直島','塩飽島']:
            row['unit_type']='source_region_entry_district_type_unconfirmed'
            row['candidate_display_name']=name
            row['temporal_difference']='比較データの旧郡欄にある地域項目。郡の名称・種別は未確定のため「郡」を付加しない。'
            if name=='塩飽島':
                row['source_refs'].append('kagawa-shiwaku')
                row['evidence']['name_existence'].append(d.reference('kagawa-shiwaku','文書群9188「那珂郡塩飽島見勢家文書」',supports='目録の塩飽島表記。塩飽島郡という名称を支持しない。',target_year_supported=False))
            decision('ab-unit-'+row['external_ids']['district_id'],[row['district_entity_id']], 'unit_type',row['temporal_difference'],
                [d.reference('kg-K60','#gun-list '+row['external_ids']['district_id'])])
        # Detection only: do not silently 'correct' names without evidence.
        if (rid,name) in [('bingo','三裕'),('harima','宍栗'),('higo','球摩'),('shinano','更科'),('hizen','神崎')]:
            row['name_review_note']='表記・転記の疑義として要照合。異体字・異称・誤記のいずれかは未確定。原表記を維持。'
            row['unresolved'].insert(0,row['name_review_note'])
        if rid=='kai':
            row['temporal_difference']='山梨県の説明は1878年12月の四郡→九郡再編。これら9分郡を1582年に採用しない。分割前4郡を別候補に追加。'
            row['adoption_status']='excluded'
            row['exclusion_scope']='1582_target_only; keep as later comparison'
            row['source_refs'].append('kai-four')
            row['evidence']['target_period'].append(d.reference('kai-four','甲斐の四郡と現在の山梨県',supports='後世再編のため、この分郡名での1582年採用を除外する根拠',target_year_supported=False))
    # Add pre-division entities separately. No implicit geometry union or identity
    # merge. Candidate IDs are editorial identities, independent of source IDs.
    additions=[('kai',name,'kai-four','甲斐の四郡と現在の山梨県','retrospective') for name in ['山梨','八代','巨摩','都留']]
    additions += [('shinano',name,'shinano-ten','延喜式の信濃10郡を列挙する段落','earlier_comparison') for name in ['伊那','筑摩','安曇','水内','高井','佐久']]
    stable_names={'山梨':'yamanashi','八代':'yatsushiro','巨摩':'koma','都留':'tsuru','伊那':'ina','筑摩':'chikuma','安曇':'azumi','水内':'minochi','高井':'takai','佐久':'saku'}
    for rid,name,sid,loc,temporal in additions:
        template=next(r for r in rows if r['candidate_parent_region_ids']==[rid])
        item=deepcopy(template)
        item.update(district_entity_id='district-candidate-'+rid+'-'+stable_names[name],
            source_name=name,candidate_display_name=name+'郡',aliases=[],reading=None,external_ids={},external_record_url=None,
            source_refs=[sid],temporal_basis=temporal,existence_status='inferred' if rid=='kai' else 'unconfirmed',
            adoption_status='held',unit_type='district_candidate',
            attested_period='1878年以前の四郡区分を回顧' if rid=='kai' else '平安期延喜式の郡名を回顧',
            evidence=dict(name_existence=[d.reference(sid,loc,supports='分割前の名称候補',target_year_supported=False)],location=[],
                target_period=[d.reference(sid,loc,supports='過去からの継続を述べる回顧説明。1582年個別史料は未確認。',target_year_supported=False)] if rid=='kai' else []),
            location_leads=[], temporal_difference='分割前郡の候補。1582年の個別史料・村郷所属・境界は未確認。',
            decision_reason='後世の分郡を遡及させず、別資料で見つかった旧区分を追加。',
            reuse_status='source_terms_unverified_research_only',
            unresolved=['1582年時点の個別史料','郡の成立・改称と継続','旧区分の位置・村郷所属','後世の分郡との対応'])
        for key in ['exclusion_scope','name_review_note']:
            item.pop(key,None)
        rows.append(item)
        decision('ab-add-'+rid+'-'+stable_names[name],[item['district_entity_id']], 'earlier_candidate_added',item['decision_reason'],[d.reference(sid,loc)])
    for review in reviews['reviews']:
        rid=review['parent_region_id']
        review['comparison_candidate_ids']=review.pop('candidate_ids')
        review['supplemental_candidate_ids']=[r['district_entity_id'] for r in rows if rid in r['candidate_parent_region_ids'] and not r['external_ids']]
        review['supplemental_source_refs']=sorted({s for r in rows if rid in r['candidate_parent_region_ids'] for s in r['source_refs'] if not s.startswith('kg-')})
        review['evidence_coverage']='later_comparison_only'
        if review['supplemental_source_refs']:
            review['evidence_coverage']='comparison_plus_individual_crosschecks; target_unresolved'
        if rid=='izumi': review['followups'] += ['hinenosho','nai-genroku-izumi']
        review['temporal_flags']=[dict(candidate_id=r['district_entity_id'],note=r['temporal_difference']) for r in rows if rid in r['candidate_parent_region_ids'] and (r['adoption_status']=='excluded' or r['unit_type']!='district_candidate')]
    for p in scope['parents']:
        candidates=[r for r in rows if p['parent_region_id'] in r['candidate_parent_region_ids']]
        p['comparison_row_count']=p['candidate_count']
        p['candidate_count']=len(candidates)
        p['candidate_ids']=[r['district_entity_id'] for r in candidates]
        p['supplemental_candidate_count']=sum(not bool(r['external_ids']) for r in candidates)
        p['excluded_at_target_count']=sum(r['adoption_status']=='excluded' for r in candidates)
    scope['comparison_row_count']=697
    scope['supplemental_candidate_count']=10
    scope['candidate_inventory_count']=len(rows)
    for m in mappings['mappings']:
        for witness in m['spatial_context']['contained_site_witnesses']:
            witness['evidence']=d.reference('local-settlements','sites[id='+witness['site_id']+']')
        if not m['spatial_context']['contained_site_witnesses']:
            m['mapping_status']='provisional_no_local_site_witness'
        original=next(r for r in d.read(d.REGISTRY)['regions'] if r['region_id']==m['parent_region_id'])
        m['local_registration_metadata']={k:v for k,v in original.items() if k!='polygons'}
    lock=d.read(d.OUT/'input_lock.json')
    path=d.ROOT/'scripts/main/main_map.gd'
    existing_main=next((x for x in lock['files'] if x['path']==path.relative_to(d.ROOT).as_posix()),None)
    if existing_main:
        assert existing_main['sha256']==d.digest(path)
    else:
        lock['files'].append(dict(path=path.relative_to(d.ROOT).as_posix(),bytes=path.stat().st_size,sha256=d.digest(path)))
    lock['files'].sort(key=lambda x:x['path'])
    lock['inventory_correction']='初回検証で、main_map.gdの実配置scripts/mainを固定対象へ補完。既存固定ハッシュは変更していない。'
    versions={'kyushu':'1.0.0','shikoku':'1.0.0','chugoku':'1.1.0','honshu':'1.0.4'}
    origins={}
    master_files=[]
    active=d.read(d.REGISTRY)
    for area,version in versions.items():
        base=d.ROOT/f'data/master/political/{area}/{version}'
        path=base/'political_registry_master.json'
        data=d.read(path)
        master_files += [p for p in base.iterdir() if p.is_file() and p.suffix in ['.json','.gpkg']]
        if (base.parent/'status.json').exists(): master_files.append(base.parent/'status.json')
        for row in data['regions']:
            origins[row['region_id']]=dict(area=area,version=version,file=path.relative_to(d.ROOT).as_posix(),sha256=d.digest(path),row=row)
    for parent in scope['parents']:
        origin=origins[parent['parent_region_id']]
        row=next(r for r in active['regions'] if r['region_id']==parent['parent_region_id'])
        assert origin['row']['polygons']==row['polygons'] and origin['row']['name_ja']==row['name_ja']
        parent['upstream_master']={k:v for k,v in origin.items() if k!='row'}
        parent['upstream_master']['comparison']='region_id, name_ja and full polygon arrays exactly match the active registry'
    paths={r['path'] for r in lock['files']}
    for path in master_files:
        rel=path.relative_to(d.ROOT).as_posix()
        if rel not in paths:
            lock['files'].append(dict(path=rel,bytes=path.stat().st_size,sha256=d.digest(path)))
    lock['files'].sort(key=lambda x:x['path'])
    lock['upstream_provenance']='Regional masters identified by exact current region ID/name/polygon equality; fixed along with their approval/status records.'
    for name,value in [('districts',districts),('sources',sources),('scope',scope),('country_reviews',reviews),('province_mapping',mappings),('input_lock',lock)]:
        d.write(d.OUT/(name+'.json'),value)
    d.write(target,dict(edition=d.EDITION,decisions=decisions))
    print('Applied initial review: '+str(len(rows))+' candidate/comparison items, '+str(len(sources['sources']))+' sources.')


if __name__=='__main__':
    main()
