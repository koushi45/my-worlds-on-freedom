"""Independent name-based discovery; returned entity identity is retained for review."""
import json, time, urllib.parse, urllib.request
from fetch_entities import OUT, candidate_rows

NAMES = '南部晴政 最上義守 里見義堯 寿桂尼 井伊直虎 山名祐豊 一条兼定 土岐頼芸 赤松晴政 細川晴元 足利義晴 上杉朝定_(扇谷上杉家) 上杉憲政 北畠晴具 北畠具教 蠣崎季広 相良晴広 伊東義祐 肝付兼続 松浦隆信 大村純忠 有馬晴純 有馬義貞 秋月種実 城井鎮房 阿蘇惟豊 甲斐宗運 高橋鑑種 高橋紹運 村上義清 伊達輝宗 百地丹波 藤林長門守 服部保長 山本勘助 筒井順昭 遊佐長教 安見宗房 三好長逸 長尾晴景 斎藤利三 織田信勝 山内一豊 朝倉孝景_(10代当主) 赤井直正 波多野秀治 佐竹義昭 宇都宮広綱 織田信秀'.split()

def main():
    url = 'https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode({'action':'wbgetentities','sites':'jawiki','titles':'|'.join(n.replace('_',' ') for n in NAMES),'props':'info|labels|aliases|descriptions|claims|sitelinks','languages':'ja|en','format':'json'})
    req=urllib.request.Request(url,headers={'User-Agent':'MyWorldsOnFreedom-HistoricalRoster/0.1'})
    with urllib.request.urlopen(req,timeout=60) as response: data=json.load(response)
    (OUT/'supplement_response.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    index=json.loads((OUT/'supplemental_index.json').read_text(encoding='utf-8')) if (OUT/'supplemental_index.json').exists() else {}
    existing=candidate_rows()
    for q,e in data['entities'].items():
        if 'missing' in e: print('MISSING',e);continue
        if q in existing: continue
        name=e.get('labels',{}).get('ja',{}).get('value',q)
        index[q]={'id':q,'name':name,'description':e.get('descriptions',{}).get('ja',{}).get('value',''),'discovery':['supplement_response.json'],'rows':[]}
        (OUT/'entities'/f'{q}.json').write_text(json.dumps({'retrieved_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'license':'CC0-1.0','entity':e},ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'supplemental_index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2),encoding='utf-8')
    existing.update(index)
    (OUT/'candidate_index.json').write_text(json.dumps(existing,ensure_ascii=False,indent=2),encoding='utf-8')
    print('supplement:',[(q,r['name']) for q,r in index.items()])

if __name__=='__main__': main()
