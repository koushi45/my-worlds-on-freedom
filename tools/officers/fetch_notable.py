"""Archive notable officers across birth years, retaining identity and date provenance."""
import json, time, urllib.parse, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'data/sources/officers'
NAMES='''本多忠勝 伊達政宗 井伊直政 榊原康政 真田昌幸 真田信之 真田信繁 直江兼続 上杉景勝 上杉景虎 島津家久 立花宗茂 立花誾千代 高橋紹運 毛利輝元 吉川広家 小早川秀秋 長宗我部盛親 長宗我部信親 織田信忠 織田信雄 織田信孝 豊臣秀次 豊臣秀頼 徳川秀忠 松平信康 結城秀康 松平忠吉 藤堂高虎 脇坂安治 加藤嘉明 加藤清正 福島正則 石田三成 大谷吉継 黒田長政 細川忠興 蒲生氏郷 浅野長政 浅野幸長 池田輝政 堀秀政 堀直政 森長可 森成利 九鬼嘉隆 高山右近 小西行長 大友義統 龍造寺政家 鍋島勝茂 島津忠恒 北条氏直 北条氏邦 佐竹義重_(十八代当主) 佐竹義宣_(右京大夫) 最上義康 最上家親 津軽為信 南部信直 片倉景綱 伊達成実 鬼庭綱元 片倉重長 後藤基次 塙直之 明石全登 尼子勝久 筒井順慶 斎藤龍興 別所長治 宇喜多秀家 仙石秀久 前田利益 前田利長 前田利常 真田昌輝 大久保忠隣 本多正純 酒井家次 鳥居忠政 長束正家 田中吉政 蜂須賀家政 山内忠義 有馬晴信 大村喜前 宗義智 松前慶広 秋田実季 蘆名盛隆 小野鎮幸 立花直次'''.split()
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    index=json.loads((OUT/'candidate_index.json').read_text(encoding='utf-8'))
    supplement=json.loads((OUT/'supplemental_index.json').read_text(encoding='utf-8'))
    decisions_path=ROOT/'data/master/officers/decisions.json'
    decisions=json.loads(decisions_path.read_text(encoding='utf-8'))
    roster_ids={r['external_id'] for r in json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))['officers']}
    manifest_path=ROOT/'data/master/officers/notable_registration.json'
    previous={r['external_id']:r for r in json.loads(manifest_path.read_text(encoding='utf-8'))['officers']} if manifest_path.exists() else {}
    additions=[];missing=[]
    for offset in range(0,len(NAMES),30):
        titles=[n.replace('_',' ') for n in NAMES[offset:offset+30]]
        archive=OUT/f'notable_across_years_{offset//30+1}{"_v2" if "秋田実季" in titles or "佐竹義重 (十八代当主)" in titles else ""}.json'
        if archive.exists():data=json.loads(archive.read_text(encoding='utf-8'))
        else:
            url='https://www.wikidata.org/w/api.php?'+urllib.parse.urlencode({'action':'wbgetentities','sites':'jawiki','titles':'|'.join(titles),'props':'info|labels|aliases|descriptions|claims|sitelinks','languages':'ja|en','format':'json'})
            with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'MyWorldsOnFreedom-HistoricalRoster/0.2'}),timeout=50) as response:data=json.load(response)
            write(archive,data)
        for q,e in data['entities'].items():
            if 'missing' in e:missing.append(e);continue
            if any(c.get('mainsnak',{}).get('datavalue',{}).get('value',{}).get('id')=='Q4167410' for c in e.get('claims',{}).get('P31',[])): raise ValueError('Disambiguation: '+q)
            name=e.get('labels',{}).get('ja',{}).get('value',q)
            title=e.get('sitelinks',{}).get('jawiki',{}).get('title','')
            if q not in index:
                entry={'id':q,'name':name,'description':e.get('descriptions',{}).get('ja',{}).get('value',''),'discovery':[archive.name],'rows':[]}
                index[q]=entry;supplement[q]=entry
                write(OUT/'entities'/f'{q}.json',{'retrieved_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'license':'CC0-1.0','entity':e})
            d=decisions.setdefault(q,{})
            d['register_across_start_year']=True
            d['registration_reason']='ユーザー指定により著名な戦国期の人物を開始年の出生前後にかかわらず名簿へ収録。存命・未誕生・年代保留は別判定。'
            d.setdefault('aliases',[])
            if title and title not in d['aliases']:d['aliases'].append(title)
            if title=='本多忠勝':d['aliases'].append('本田忠勝')
            d['aliases']=sorted(set(d['aliases']))
            additions.append({'external_id':q,'display_name':name,'wikipedia_title':title,'previously_in_roster':previous.get(q,{}).get('previously_in_roster',q in roster_ids),'source_archive':archive.name})
        print(offset+len(titles),'/',len(NAMES),'checked',flush=True)
    write(OUT/'candidate_index.json',index);write(OUT/'supplemental_index.json',supplement);write(decisions_path,decisions)
    previous.update({r['external_id']:r for r in additions})
    write(ROOT/'data/master/officers/notable_registration.json',{'selection':'全国の主要大名、著名家臣、統一戦・関ヶ原・大坂の陣の主要人物を対象とする編集選定。知名度の統計順位や史実人物全員の網羅ではない。','officers':list(previous.values()),'missing':missing})
    print('Registered',len(additions),'missing',missing)
if __name__=='__main__':main()
