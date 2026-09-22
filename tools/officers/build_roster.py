"""Rebuild the roster offline from immutable discovery snapshots and editorial decisions."""
import collections, hashlib, html, json, re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'data/sources/officers'
MASTER=ROOT/'data/master/officers'
OUTPUT=ROOT/'data/derived/officers'
DOCS=ROOT/'docs/officers'
YEAR=1546
ATTRS={'command':'統率','tactics':'武勇','strategy':'知略','politics':'政治','trust':'人望'}
STATUS={'alive':'年代上対象','same_year_ambiguous':'1546年内の前後不明','unresolved':'年代要調査','excluded':'対象外','unborn':'開始時は未誕生'}

def read(path): return json.loads(path.read_text(encoding='utf-8'))
def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def date_claims(entity,prop):
    all_claims=entity.get('claims',{}).get(prop,[])
    usable=[x for x in all_claims if x.get('rank')!='deprecated']
    preferred=[x for x in usable if x.get('rank')=='preferred']
    used_ids={x['id'] for x in preferred or usable}
    result=[]
    for c in all_claims:
        snak=c.get('mainsnak',{}); v=snak.get('datavalue',{}).get('value',{})
        result.append({'claim_id':c.get('id'),'rank':c.get('rank'),'used':c.get('id') in used_ids,
            'snaktype':snak.get('snaktype'),'value':v,'references':c.get('references',[]),'qualifiers':c.get('qualifiers',{})})
    return result

def year_range(claims):
    ranges=[]
    for c in claims:
        if not c['used']: continue
        value=c['value']; match=re.match(r'^([+-]\d+)-',value.get('time',''))
        if not match or value.get('precision',0)<6: return None
        year=int(match[1]); precision=int(value['precision'])
        if precision>=9: low=high=year
        elif precision==8: low=year//10*10; high=low+9
        else:
            width=100 if precision==7 else 1000
            low=(year-1)//width*width+1; high=low+width-1
        # Explicit uncertainty attached to a statement must not become an exact birth year.
        if value.get('before') or value.get('after'): return None
        if set(c.get('qualifiers',{})) & {'P1480','P1319','P1326'}: return None
        ranges.append((low,high))
    return [min(x[0] for x in ranges),max(x[1] for x in ranges)] if ranges else None

def classify(birth,death):
    if birth and birth[0]>YEAR: return 'excluded','開始年より後の出生。'
    if death and death[1]<YEAR: return 'excluded','開始年より前に没。'
    if birth and death and birth[0]>death[1]: return 'unresolved','生年と没年の記録が矛盾。'
    if not birth or not death: return 'unresolved','生没年の一方以上が不詳、または精度・限定句の確認待ち。'
    if death[1]-birth[0]>105: return 'unresolved','105年を超える生涯幅。誤登録・伝承・日付精度の個別確認待ち。'
    if birth[1]<YEAR and death[0]>YEAR: return 'alive','採用した生没年の範囲が1546年を含む。外部台帳の年代判定であり史料照合完了を意味しない。'
    if birth[0]==birth[1]==YEAR or death[0]==death[1]==YEAR: return 'same_year_ambiguous','元服の月日を固定していないため、1546年内の出生・死亡との前後は未確定。'
    return 'unresolved','年代幅が開始年をまたぐため、1546年の存命を確定できない。'

def military_scope(row,entity):
    if any(c.get('mainsnak',{}).get('datavalue',{}).get('value',{}).get('id')=='Q4167410' for c in entity.get('claims',{}).get('P31',[])):
        return False,'人物ではなく同名人物の曖昧さ回避項目。原台帳に保存し人物として登録しない。'
    description=row['description']+' '+entity.get('descriptions',{}).get('ja',{}).get('value','')
    if re.search(r'平安時代|鎌倉時代|南北朝(?:時代|・室町時代)|室町時代前期|幕末|江戸時代(?:中|後)期|mid-Heian|古代日本',description,re.I) and not re.search(r'戦国|安土桃山',description):
        return False,'探索記述が1546年とは異なる時代の人物を指しているため対象外。元データは除外台帳に保存。'
    birth=year_range(date_claims(entity,'P569'))
    if birth and birth[1]<1400:
        return False,'記録された出生年代が14世紀以前。1546年の対象人物とは異なる時代として除外台帳に保存。'
    occupations={c.get('mainsnak',{}).get('datavalue',{}).get('value',{}).get('id') for c in entity.get('claims',{}).get('P106',[]) if c.get('rank')!='deprecated'}
    if row['id'] in {'Q10931686','Q1045296','Q6606602','Q11161448','Q11554626','Q60685870'}:
        return True,'領主・宗教勢力指導者・武家の政治軍事担当を個別に対象へ追加。'
    if occupations & {'Q38142','Q61982','Q5384684','Q11545923','Q1402561'}:
        return True,'武士・大名・軍事指揮者として登録された候補。'
    if re.search(r'武将|武士|大名|国人|城主|領主|samurai|daimy|military commander',description,re.I):
        return True,'紹介記述に政治軍事主体としての役割がある候補。'
    return False,'武将・領主等への該当根拠が今回の探索情報にない。親族・僧・文化人を一律に武将化しない。'

def dates_text(bounds):
    if not bounds: return '不詳・要照合'
    return str(bounds[0]) if bounds[0]==bounds[1] else f'{bounds[0]}〜{bounds[1]}'

def stable_number(key, modulo):
    """Return a reproducible pseudo-random value without depending on Python's hash seed."""
    return int(hashlib.sha256(key.encode('utf-8')).hexdigest()[:8],16)%modulo

def selected_year(bounds, prefer):
    """Collapse a documented range using the game rule: birth=low, death=high."""
    if not bounds:return None
    return int(bounds[0] if prefer=='low' else bounds[1])

def explicit_birth_year(*texts):
    """Reuse only statements that explicitly describe a birth; do not treat activity years as births."""
    patterns=(r'(?<!\d)(1[3-6]\d{2})年(?:生まれ|出生|誕生|生)(?!\d)',
        r'生年(?:は|：|:)?\s*(1[3-6]\d{2})(?:年)?')
    for text in texts:
        for pattern in patterns:
            match=re.search(pattern,text or '')
            if match:return int(match.group(1))
    return None

def complete_years(q,birth_range,death_range,assignment):
    """Produce exact game years while preserving documented inputs and estimation provenance."""
    ref_birth=assignment.get('birth_reference')
    ref_death=assignment.get('death_reference')
    birth=selected_year(birth_range,'low')
    death=selected_year(death_range,'high')
    birth_basis='source_lower_bound' if birth_range else None
    death_basis='source_upper_bound' if death_range else None
    if birth is None and ref_birth:
        birth=selected_year(ref_birth,'low');birth_basis='affiliation_reference_lower_bound'
    if death is None and ref_death:
        death=selected_year(ref_death,'high');death_basis='affiliation_reference_upper_bound'
    lifespan=55+stable_number(q+':lifespan',16)
    if birth is None:
        birth=explicit_birth_year(assignment.get('reason'),assignment.get('historical_reason'),assignment.get('placement_reason'))
        if birth is not None:birth_basis='explicit_birth_year_in_biography_note'
    if birth is None and death is not None:
        birth=death-lifespan;birth_basis='estimated_from_death_and_lifespan'
    if birth is None:
        availability=assignment.get('availability')
        role=assignment.get('role') or ''
        if availability=='not_born' or assignment.get('future_placement_reserved'):
            birth=YEAR+1+stable_number(q+':future_birth',35)
            birth_basis='estimated_after_scenario_start'
        elif availability=='deceased':
            birth=YEAR-lifespan-1-stable_number(q+':pre_start_death',20)
            birth_basis='estimated_before_scenario_start'
        elif role=='元服前':
            birth=YEAR-(5+stable_number(q+':child_age',10))
            birth_basis='estimated_from_scenario_child_role'
        else:
            minimum_age,span=((28,18) if role=='大名' else (20,21) if role in ('武将','大名家一門') else (18,23))
            birth=YEAR-(minimum_age+stable_number(q+':adult_age',span))
            birth_basis='estimated_from_scenario_role'
    if death is None:
        death=birth+lifespan;death_basis='estimated_from_birth_and_lifespan'
    return {
        'birth_year_range':[birth,birth],'death_year_range':[death,death],
        'birth_year_estimated':birth_basis.startswith('estimated_'),
        'death_year_estimated':death_basis.startswith('estimated_'),
        'birth_year_basis':birth_basis,'death_year_basis':death_basis,
        'estimated_lifespan_years':lifespan if 'lifespan' in birth_basis or 'lifespan' in death_basis else None,
        'source_birth_year_range':birth_range,'source_death_year_range':death_range,
    }

def total_ability(scores):
    values=[scores.get(k) for k in ATTRS]
    return sum(values) if all(type(v) is int and 1<=v<=30 for v in values) else None

def main():
    index=read(SOURCE/'candidate_index.json'); assessments=read(MASTER/'assessments.json'); sources=read(MASTER/'sources.json')
    overrides=read(MASTER/'decisions.json')
    affiliation_path=MASTER/'affiliations_1546.json'
    affiliation_data=read(affiliation_path) if affiliation_path.exists() else {'officers':{},'stats':{}}
    relationship_path=MASTER/'relationships.json'
    relationship_data=read(relationship_path) if relationship_path.exists() else {'officers':{},'stats':{}}
    lineage_path=MASTER/'lineages.json'
    lineage_data=read(lineage_path) if lineage_path.exists() else {'officers':{},'stats':{}}
    records=[]; excluded=[]; provenance=[]
    for q,row in sorted(index.items()):
        path=SOURCE/'entities'/f'{q}.json'; archived=read(path); entity=archived['entity']; decision=overrides.get(q,{})
        birth_claims=date_claims(entity,'P569'); death_claims=date_claims(entity,'P570')
        source_birth=year_range(birth_claims); source_death=year_range(death_claims)
        if 'birth_range' in decision: source_birth=decision['birth_range']
        if 'death_range' in decision: source_death=decision['death_range']
        temporal,note=classify(source_birth,source_death)
        if 'temporal_status' in decision: temporal=decision['temporal_status']; note=decision['reason']
        in_scope,scope_reason=military_scope(row,entity)
        if 'in_scope' in decision: in_scope=decision['in_scope']; scope_reason=decision['reason']
        if decision.get('register_across_start_year') and in_scope and source_birth and source_birth[0]>YEAR:
            temporal='unborn';note='著名人物として名簿へ登録。開始年1546年には未誕生で、開始時の出仕・配属対象にはしない。'
        if not in_scope: temporal='excluded';note=scope_reason
        assignment=affiliation_data['officers'].get(q,{})
        completed=complete_years(q,source_birth,source_death,assignment)
        birth=completed['birth_year_range'];death=completed['death_year_range']
        aliases=sorted({a['value'] for lang in ['ja','en'] for a in entity.get('aliases',{}).get(lang,[])})
        aliases+=decision.get('aliases',[])
        rating=assessments.get(q,{'status':'unrated','basis':'lifetime','scores':dict.fromkeys(ATTRS),'source_refs':[],
            'evidence':'能力を比較するための個別業績・家臣団資料をまだ照合できていない。',
            'caveat':'未評価は低能力を意味しない。ゲーム計算に数値0や平均値として渡さない。','confidence':'unreviewed','score_method':'未評価'})
        age=None
        if birth and birth[0]<=YEAR and temporal!='unborn' and not decision.get('suppress_start_age'): age=[max(0,YEAR-birth[1]-1),max(0,YEAR-birth[0])]
        life_stage='unborn' if temporal=='unborn' else 'unknown'
        if temporal in ['alive','same_year_ambiguous'] and age:
            life_stage='child' if age[1]<15 else ('age_threshold_ambiguous' if age[0]<15 else 'age_15_or_more')
        life_stage=decision.get('life_stage',life_stage)
        refs=[f'https://www.wikidata.org/wiki/Special:EntityData/{q}.json?revision={entity.get("lastrevid",0)}']
        record={'id':'officer_'+q.lower(),'external_id':q,'display_name':decision.get('display_name',row['name']),
            'aliases':sorted(set(aliases)),'birth_year_range':birth,'death_year_range':death,
            'source_birth_year_range':completed['source_birth_year_range'],'source_death_year_range':completed['source_death_year_range'],
            'birth_year_estimated':completed['birth_year_estimated'],'death_year_estimated':completed['death_year_estimated'],
            'birth_year_basis':completed['birth_year_basis'],'death_year_basis':completed['death_year_basis'],
            'estimated_lifespan_years':completed['estimated_lifespan_years'],
            'birth_display':dates_text(birth),'death_display':dates_text(death),'age_range_at_start':age,
            'life_stage':life_stage,'temporal_status':temporal,'temporal_note':note,
            'start_present':temporal=='alive','start_service_status':'not_born' if temporal=='unborn' else 'unassigned',
            'start_affiliation':None,'start_settlement_id':None,
            'notable_registration':bool(decision.get('register_across_start_year')),'registration_note':decision.get('registration_reason',''),
            'identity_confidence':'editorial_review' if decision.get('source_urls') else 'external_catalog_unverified',
            'total_ability':total_ability(rating['scores']),'scope_reason':scope_reason,'assessment':rating,'identity_sources':refs,
            'decision':decision,'discovery':row['discovery']}
        if temporal!='excluded' and q in affiliation_data['officers']:
            assignment=affiliation_data['officers'][q]
            record['affiliation_1546']=assignment
            record['start_affiliation']=assignment['house_id']
            record['start_district_id']=assignment['district_key']
            record['start_role']=assignment['role']
            if assignment.get('future_placement_reserved'):
                assert (temporal == 'unborn' or (temporal == 'unresolved' and assignment.get('scenario_batch') in ('affiliation_batch9_100', 'affiliation_batch10_100', 'affiliation_batch11_65') and assignment.get('future_chronology_basis') == 'biography_or_family_inference_raw_dates_preserved')) and not assignment['can_serve_at_start']
                record['start_service_status'] = 'not_born'
                record['reserved_affiliation']=assignment['house_id']
                record['reserved_district_id']=assignment['district_key']
                record['reserved_role']=assignment['role']
                record['start_affiliation']=None
                record['start_district_id']=None
                record['start_role']=None
            if assignment.get('reference_placement_only'):
                assert assignment.get('scenario_batch') == 'affiliation_batch11_65' and not assignment['can_serve_at_start']
                record['reference_affiliation'] = assignment['house_id']
                record['reference_district_id'] = assignment['district_key']
                record['reference_role'] = assignment['role']
                record['start_affiliation'] = None
                record['start_district_id'] = None
                record['start_role'] = None
        if temporal!='excluded' and q in lineage_data['officers']:
            record['lineage']=lineage_data['officers'][q]
        if temporal!='excluded' and q in relationship_data['officers']:
            record['relationships']=relationship_data['officers'][q]
        (excluded if temporal=='excluded' else records).append(record)
        provenance.append({'external_id':q,'name':row['name'],'revision':entity.get('lastrevid'),
            'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'birth_claims':birth_claims,'death_claims':death_claims,
            'result':temporal,'reason':note,'editorial_decision':decision})
    # Stable order independent of SPARQL result ordering.
    records.sort(key=lambda r:(r['display_name'],r['id'])); excluded.sort(key=lambda r:(r['display_name'],r['id']))
    stats=dict(collections.Counter(r['temporal_status'] for r in records+excluded))
    stats.update({'candidate_count':len(index),'roster_count':len(records),
        'assessed_people':sum(any(v is not None for v in r['assessment']['scores'].values()) for r in records),
        'fully_assessed_people':sum(all(v is not None for v in r['assessment']['scores'].values()) for r in records),
        'notable_registered':sum(r['notable_registration'] for r in records),
        'unrated_people':sum(all(v is None for v in r['assessment']['scores'].values()) for r in records)})
    data={'schema_version':1,'scenario_id':'nobunaga_genpuku_1546','start_year':YEAR,'map_reference_year':1582,
        'assessment_basis':'lifetime','completeness':'open_catalog_not_complete_census',
        'coverage_note':'今回の収集台帳内の対象を全件登録。史実上の全武将の網羅は未保証。生年は幅の下限、没年は上限をゲーム値に採用し、欠落値は参照台帳または再現可能な推定で補完。原値と推定フラグを併記。',
        'attribute_names':ATTRS,'score_scale':{'min':1,'max':30,'step':1,'unknown':None},
        'total_scale':{'min':5,'max':150,'method':'sum_of_five','unknown':None},'stats':stats,'sources':sources,'officers':records,
        'affiliation_stats':affiliation_data['stats'],'lineage_stats':lineage_data['stats'],'relationship_stats':relationship_data['stats']}
    write(OUTPUT/'officers_1546.json',data)
    write(DOCS/'excluded_candidates.json',excluded)
    write(DOCS/'date_provenance.json',provenance)
    scenario={'schema_version':1,'id':data['scenario_id'],'display_name':'信長元服（1546年）','start_year':1546,
        'start_month':None,'start_day':None,'date_precision':'year','map_reference_year':1582,
        'officer_registry':'res://data/derived/officers/officers_1546.json','assessment_basis':'lifetime',
        'start_policy':'年代上対象だけを存命扱い。同年内の前後不明・年代要調査は保留。幼少者も登録し、出仕・部隊配置は別判定。',
        'source_refs':['genpuku'],'faction_setup_status':'affiliation_draft','officer_assignment_status':'district_placement_draft_no_units'}
    write(ROOT/'data/derived/scenarios/default_scenario.json',scenario)
    render_html(data,excluded)
    render_markdown(data)
    render_major_sixty(data)
    render_major_sixty(data, "next_60", "NEXT_60.md", "追加の著名武将60人・生涯能力評価（第2組）")
    render_major_sixty(data, "third_60", "THIRD_60.md", "追加の著名武将60人・生涯能力評価（第3組）")
    render_major_sixty(data, "fourth_100", "FOURTH_100.md", "追加の著名武将100人・生涯能力評価（第4組）")
    render_major_sixty(data, "fifth_100", "FIFTH_100.md", "追加の著名武将100人・生涯能力評価（第5組）")
    render_major_sixty(data, "sixth_100", "SIXTH_100.md", "追加の著名武将100人・生涯能力評価（第6組）")
    render_major_sixty(data, "seventh_100", "SEVENTH_100.md", "追加の著名武将100人・生涯能力評価（第7組）")
    render_major_sixty(data, "eighth_100", "EIGHTH_100.md", "追加の著名武将100人・生涯能力評価（第8組）")
    render_major_sixty(data, "ninth_100", "NINTH_100.md", "追加の著名武将100人・生涯能力評価（第9組）")
    render_major_sixty(data, "tenth_100", "TENTH_100.md", "追加の著名武将100人・生涯能力評価（第10組）")
    render_major_sixty(data, "eleventh_100", "ELEVENTH_100.md", "追加の著名武将100人・生涯能力評価（第11組）")
    render_major_sixty(data, "twelfth_100", "TWELFTH_100.md", "追加の著名武将100人・生涯能力評価（第12組）")
    render_major_sixty(data, "thirteenth_100", "THIRTEENTH_100.md", "追加の著名武将100人・生涯能力評価（第13組）")
    render_major_sixty(data, "fourteenth_100", "FOURTEENTH_100.md", "追加の著名武将100人・生涯能力評価（第14組）")
    render_major_sixty(data, "fifteenth_100", "FIFTEENTH_100.md", "追加の著名武将100人・生涯能力評価（第15組）")
    render_major_sixty(data, "sixteenth_100", "SIXTEENTH_100.md", "追加の著名武将100人・生涯能力評価（第16組）")
    render_major_sixty(data, "seventeenth_100", "SEVENTEENTH_100.md", "未評価から選定した100人・生涯能力評価（第17組）")
    render_notable(data)
    write(DOCS/'validation_summary.json',{'stats':stats,'all_candidates_classified':len(records)+len(excluded)==len(index),
        'unique_ids':len({r['id'] for r in records})==len(records),'scoring_is_editorial':True,
        'missing_assessment_ids':sorted(set(assessments)-{r['external_id'] for r in records+excluded}),
        'all_roster_dates_complete':all(r['birth_year_range'] and r['death_year_range'] for r in records),
        'all_roster_dates_exact':all(r['birth_year_range'][0]==r['birth_year_range'][1] and r['death_year_range'][0]==r['death_year_range'][1] for r in records),
        'reference_assessment_ids':sorted(r['external_id'] for r in excluded if r['total_ability'] is not None),
        'unresolved_affiliations':len(records),'source_license':'Wikidata CC0; institutional pages linked, not reproduced'})
    print(json.dumps(stats,ensure_ascii=False))

def render_markdown(data):
    s=data['stats']
    lines=['# 1546年開始・武将台帳と生涯能力案','',
        '開始年は織田信長の元服に合わせ1546年。地図・城・道路は1582年基準を維持する。元服の月日は固定していない。',
        '',f'収集候補 {s["candidate_count"]}人／名簿 {s["roster_count"]}人／年代上対象 {s.get("alive",0)}人／同年内の前後不明 {s.get("same_year_ambiguous",0)}人／年代要調査 {s.get("unresolved",0)}人。',
        f'能力案あり {s["assessed_people"]}人（五項目すべて {s["fully_assessed_people"]}人）。残る {s["unrated_people"]}人は未評価。全史実武将の網羅・能力査定の完成を示す数字ではない。','',
        '## 評価方針','',
        '- 統率：軍勢の規模・編成・補給・方面軍の協同を含む運用。単純な兵数だけでは決めない。',
        '- 武勇：自ら率いる部隊での戦術的成果。個人の剣技や決闘伝説と区別する。',
        '- 知略：外交・戦略・状況判断の成果。陰謀や架空の軍師逸話の数では決めない。',
        '- 政治：領国運営・政策の実施と継続。制定しただけの法と実効を区別する。',
        '- 人望：家臣の定着、登用した人材の活用、組織内の支持。本人の主君への忠義や一般的人気と区別する。',
        '', '1〜30点、1点刻みの編集評価。数値は出典の記載ではない。資料の短い要約とゲーム上の推定を別欄に保存した。',
        '第2〜第16組は成否不明12前後・失敗のみ5前後、任務参加のみは標準遂行と解釈して重要性と責任を評価する。既存の評価は保持。',
        '総合能力は5能力の単純合計（最大150）。一項目でも未評価なら総合も未評価。',
        '未評価は `null`。0点・一律の中間値・ランダム値には置き換えない。幼少者も生涯能力案を表示するが、出仕可能とは扱わない。',
        '幼少の絞り込みは満年齢上限15歳未満の便宜的分類であり、一律の元服年齢や出仕年齢ではない。信長は開始の契機となる元服を個別に記録する。',
        '', '## 能力一覧','', '| 武将 | 生年 | 没年 | 開始時 | 統率 | 武勇 | 知略 | 政治 | 人望 | 総合 |', '|---|---|---|---|---:|---:|---:|---:|---:|---:|']
    for r in data['officers']:
        values=[r['display_name'],r['birth_display'],r['death_display'],STATUS[r['temporal_status']]]+[str(v) if v is not None else '未評価' for v in r['assessment']['scores'].values()]+[str(r['total_ability']) if r['total_ability'] is not None else '未評価']
        lines.append('| '+' | '.join(values)+' |')
    lines+=['','## 再生成と残件','',
        '`python -X utf8 tools/officers/build_roster.py` で、保存済みの原データと編集台帳から再生成する。ネットワークへの再問い合わせはしない。',
        '探索は職業ID・日本との関連・個別補足の和集合。元の候補、採否理由、日付精度、出典の版を保持。名前だけで統合せずWikidataの人物IDを使用する。',
        '原台帳の生年不詳・世紀単位・同年生没・資料の矛盾は source_* 欄に残す。ゲーム用値は生年の幅の下限、没年の幅の上限を採用し、欠落年を推定で補完する。年代上対象も外部台帳の照合段階であり、個々の史料を精査済みとはしない。',
        '生年が後の著名人物も未誕生として登録する。全員の所属勢力・所在・出仕年・生涯能力の照合は未完了。1582年の城主情報を1546年の所属として流用しない。',
        'ゲームへの追加範囲は開始設定、人物台帳、検索と詳細表示。人材登用・配属・戦闘・加齢進行は未実装。','', '## 参照資料','']
    lines += [f'- [{s["title"]}]({s["url"]})' for s in data['sources']]
    (DOCS/'OFFICER_ROSTER_1546.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

def render_major_sixty(data, cohort="major_60", filename="MAJOR_60.md", title="主要武将60人・生涯能力評価（30点満点）"):
    people=[r for r in data['officers'] if r['assessment'].get('cohort')==cohort]
    if cohort in ('third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100','fourteenth_100','fifteenth_100','sixteenth_100','seventeenth_100'): people.sort(key=lambda r:r['assessment']['selection_rank'])
    lines=['# '+title,'',
        f'総合能力は5項目の単純合計で最大150。各能力は1〜30点、1点刻み。統率・武勇・知略・政治・人望の全{len(people)*5}項目を評価。数値は生涯の実績を参考にしたゲーム用の暫定判断であり、史料に記された測定値ではありません。',
        ('元の1,271人から前回と重複しない60人を編集選定。知名度の統計順位ではありません。' if cohort=='next_60' else '既存1,360人の未評価者から知名度を目安に追加選定。掲載順は今回60人内の編集上の目安で、統計的な知名度順位ではありません。既存120人の評価を保持。' if cohort=='third_60' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存180人の評価を保持。' if cohort=='fourth_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存280人の評価を保持。' if cohort=='fifth_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存380人の評価を保持。' if cohort=='sixth_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存480人の評価を保持。' if cohort=='seventh_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存580人の評価を保持。' if cohort=='eighth_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存680人の評価を保持。' if cohort=='ninth_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存780人の評価を保持。' if cohort=='tenth_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存880人の評価を保持。' if cohort=='eleventh_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存980人の評価を保持。' if cohort=='twelfth_100' else '既存1,360人の未評価者から知名度を目安に100人を追加選定。掲載順は今回100人内の編集判断であり統計順位ではありません。既存1080人の評価を保持。' if cohort=='thirteenth_100' else '台帳外の著名人物60人と既存未評価者40人を合わせて100人を選定。掲載順は今回100人内の編集上の知名度目安です。既存1180人の評価を保持。' if cohort=='fourteenth_100' else '台帳外の著名人物100人を新規登録して追加評価。掲載順は今回100人内の編集上の知名度目安です。既存1280人の評価を保持。' if cohort=='fifteenth_100' else '台帳外の人物100人を新規登録して追加評価。掲載順は今回100人内の知名度を目安とする編集判断です。既存1380人の全評価を保持。' if cohort=='sixteenth_100' else '既存名簿1620人の未評価140人から100人を選定。新規登録は行わず、旧1480人の評価を保持。掲載順は知名度を目安にした編集判断であり統計順位ではない。実在・同定保留の人物や資料不足項目には暫定値を置き、その理由を個別に記載。' if cohort=='seventeenth_100' else '最初の主要60人の評価を保持。')+'1546年の存命確定・年代保留や幼少の判定は能力評価と別です。家臣の所属・所在・出仕は未設定です。',
        '統率＝大軍の運用、武勇＝直属部隊の戦術成果、知略＝外交・戦略、政治＝統治・政策、人望＝部下の定着と登用人材の活用。',
        '目安：1〜5は非常に限定的、6〜10は限定的、11〜15は小規模・補助的、16〜20は一定の成果、21〜25は有力、26〜29は特に顕著、30は今回の比較で最上位。資料不足の項目には暫定推定を置くため、この目安を歴史的事実の証明には使いません。',
        '', '| 武将 | 統率 | 武勇 | 知略 | 政治 | 人望 | 総合 | 開始時の年代判定 |', '|---|---:|---:|---:|---:|---:|---:|---|']
    if cohort in ('next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100','fourteenth_100','fifteenth_100','sixteenth_100','seventeenth_100'):
        lines[6:6]=['新基準：成否の材料なしは12前後、参照範囲で失敗のみの項目は5前後。任務参加が確認でき目立つ失策が伝わらない場合は標準遂行と解釈し、戦域・規模・責任に応じ14〜24点。成果・失敗の記録があれば個別に加減する。参加から標準遂行への推定はユーザー指定のゲーム上の解釈。既存の評価は再査定していない。','']
        lines=[line for line in lines if not line.startswith('目安：')]
    for r in people:
        a=r['assessment']
        lines.append('| '+' | '.join([r['display_name']]+[str(a['scores'][k]) for k in ATTRS]+[str(r['total_ability']),STATUS[r['temporal_status']]])+' |')
    lines+=['','## 各項目の評価理由','', '「暫定推定」は特に資料の限られる項目。それ以外も史実を手掛かりにした編集評価です。出典は人物ごとの参照事項を支えますが、個々の点数や全ての理由を保証しません。']
    sources={s['id']:s for s in data['sources']}
    for r in people:
        a=r['assessment'];lines+=['', '### '+r['display_name'],'',a['evidence'],'']
        for k,label in ATTRS.items():
            confidence=({'achievement':'功績あり','mixed':'功績・失敗を比較','participation_standard':'参加実績から標準遂行と解釈','no_record':'成否材料なし','failure_only':'参照範囲で失敗のみ'}.get(a.get('score_basis',{}).get(k)) or ('暫定推定' if a['score_confidence'][k]=='limited_evidence' else '編集評価'))
            lines.append(f"- {label} {a['scores'][k]}：{a['score_reasons'][k]}（{confidence}）")
        lines+=['',a['caveat'],'']
        lines += [f"- [{sources[ref]['title']}]({sources[ref]['url']})" for ref in a['source_refs']]
    (DOCS/filename).write_text('\n'.join(lines)+'\n',encoding='utf-8')

def render_notable(data):
    manifest=read(MASTER/'notable_registration.json')
    ids={r['external_id'] for r in manifest['officers']}
    people=[r for r in data['officers'] if r['external_id'] in ids]
    lines=['# 生年にかかわらず登録する著名武将','',manifest['selection'],'',
        '本多忠勝・伊達政宗を含め、開始時に未誕生の人物も検索できる人物台帳へ登録。元の幼少者は引き続き収録する。開始時の存命・出仕判定とは分離し、未誕生者の年齢は0歳でなく未誕生として表示。時間進行による誕生・出仕イベントは今回の対象外。',
        '名簿登録と能力評価は別管理。第3組以降では、この追加登録者も評価対象に含める。未評価者は引き続き未評価として保持する。','',
        '| 人物 | ID | 生年 | 没年 | 開始時 |', '|---|---|---|---|---|']
    for r in people:lines.append('| '+' | '.join([r['display_name'],r['external_id'],r['birth_display'],r['death_display'],STATUS[r['temporal_status']]])+' |')
    lines+=['', '名前だけでは結び付けず、原データの人物IDと日本語記事対応・紹介記述を照合。佐竹氏の同名曖昧さ回避項目は対象外として保存し、十八代義重・右京大夫義宣の人物IDを登録。松平信康は清康の子と家康の嫡男を分ける。', '', '各人物の取得版・生没年の精度・参照元は検索付き台帳の詳細と date_provenance.json に保存。']
    (DOCS/'NOTABLE_REGISTRATION.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

def render_html(data,excluded):
    template=(ROOT/'tools/officers/roster_template.html').read_text(encoding='utf-8')
    payload=json.dumps({**data,'excluded':excluded},ensure_ascii=False).replace('<','\\u003c').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
    (DOCS/'officers_1546.html').write_text(template.replace('/*ROSTER_DATA*/',payload),encoding='utf-8')

if __name__=='__main__':main()
