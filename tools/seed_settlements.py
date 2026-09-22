"""One-time editorial transcription. Runtime data is built from the JSON masters.
Do not rerun over an edited master. Every coordinate is a manually chosen area anchor.
"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'data/editorial/settlements'
SOURCE_ROWS = '''
sadowara|宮崎県文化財情報・佐土原城|https://www.miyazaki-archive.jp/d-museum/mch/details/view/1837|佐土原城の沿革|1577年の伊東氏退去後の島津氏居城。山上部の概略位置を採用。
miyazaki_national|宮崎市・国指定史跡|https://www.city.miyazaki.miyazaki.jp/culture/art/2134.html|13佐土原城・15穆佐城|中世山城と所在地。近世の下の城を中世主郭と混同しない。
kiyotake|宮崎市・市指定史跡|https://www.city.miyazaki.miyazaki.jp/culture/art/2162.html|133清武城・天ヶ城の項|清武は1577～1587年の島津氏支配。天ヶ城の成立は1600年。
tonokori|西都市・都於郡城跡|https://www.city.saito.lg.jp/post_278.html|西都市史資料編・中世山城21の紹介|所在地と五城郭を確認。1582年の利用継続は本文だけでは未確認。
obi|日南市・飫肥城跡|https://www.city.nichinan.lg.jp/museum/shishiteibunnkazai/iseki_shiseki/5/3785.html|飫肥城跡本文|戦国期からの城。旧本丸は17世紀の地震後に移転。現存建築を遡及しない。
miyakonojo|都城市・都城跡|https://www.city.miyakonojo.miyazaki.jp/site/jidaibunkazai/4044.html|都城跡の沿革|1375年築城伝承から1615年廃城までの地域支配拠点。
ebino|えびの市・市指定文化財|https://www.city.ebino.lg.jp/kanko/rekishi_bunka/3188.html|飯野城・加久藤城|飯野は1564年から26年間義弘の居城。原文の和暦表記に誤記があり西暦と年数を参照。加久藤は義弘の改修記事。
uchi|鹿児島市中世城館跡調査報告書|https://www.city.kagoshima.lg.jp/kyoiku/kanri/bunkazai/documents/documents/06kagoshimashichuseijokanatoall.pdf|内城・紙面44～45頁付近|1550年築造の居館。大龍小学校敷地付近を示す。近世鶴丸城と分離。
kanmachi|鹿児島市・計画地の現況等|https://www.city.kagoshima.lg.jp/kensetu/toshikeikaku/shimatiduku/machizukuri/machizukuri/ekishuhen/documents/2014320113553.pdf|3計画地の現況等・上町地区|1602年以前の城下・港湾一体の都市形成を説明。港の正確な岸壁は特定しない。
shibushi|志布志市・志布志城の概要|https://www.city.shibushi.lg.jp/soshiki/22/1567.html|志布志城の概要・前川河口と島津荘の港|中世城郭群と海上交通拠点。内城と河口の港町を別の代表点として登録。
bonotsu|南さつま市・坊津の風土|https://www.city.minamisatsuma.lg.jp/bounotsuhospital/hospitalannai/e027658.html|坊津の風土|中世後期の対外貿易港町。個別の1582年記録ではなく継続利用を推定。
chiran|文化庁日本遺産・知覧城跡|https://japan-heritage.bunka.go.jp/ja/culturalproperties/result/4698/|知覧城跡の解説|15世紀以降の佐多氏の本拠。近世麓の町割を配置しない。
koyama|肝付町・高山城跡|https://kimotsuki-town.jp/soshiki/rekishiminzoku/1/2/1651.html|高山城跡の解説|肝付氏が1580年に移封されたことを確認。その後の城利用は保留。
aburatsu|日南市・文化遺産データベース|https://www.city.nichinan.lg.jp/material/files/group/115/yamaumi_07.pdf|第7章・港町油津と堀川運河|港町の調査入口。掲載文化財は近世近代も含み1582年の港域は未確定。
funai|大分市・大友氏遺跡事業|https://www.city.oita.oita.jp/o204/bunkasports/rekishi/1118118836045.html|大友氏館跡・中世府内町|館と府内町を分離。顕徳町の遺跡区域を位置参照。
funai_garden|大分市・大友氏館跡庭園|https://www.city.oita.oita.jp/o204/20200605teienopen/2000605teienopen.html|調査研究と庭園の改修年代|16世紀後半の宗麟・義統期の改修を発掘成果で確認。
usuki|臼杵市・歴史|https://www.city.usuki.oita.jp/docs/2014021300153/|戦国時代の丹生島城と商業都市|1562年の築城と宗麟期の国際商業都市。現在の陸続き形状を当時のものとしない。
hitoyoshi|人吉市・史跡人吉城跡整備基本計画第2版|https://www.city.hitoyoshi.lg.jp/resource.php?e=cadfeace2bcd47d96b1d28e14f49722a60f7a8e2bdd470a6e04aa78aaed8378525cc3502d721fce997c84fb6c28bd665|紙面20頁・2-2歴史的環境|中世人吉城と古麓城の二拠点体制。中世城は近世城背後の丘陵。
hakata|福岡市・博多旧市街|https://www.city.fukuoka.lg.jp/keizai/c_kanko/shisei/hakataoldtown.html|博多部の歴史|中世貿易港湾都市。現在の大型埠頭ではなく博多部の代表位置。
tachibana|福岡市博物館・戦国時代の博多展|https://museum.city.fukuoka.jp/archives/leaflet/087/index.html|戸次道雪と立花城|1571年の立花城督就任と博多周辺の軍事拠点。
yanagawa|柳川市・柳川城本丸跡|https://www.city.yanagawa.fukuoka.jp/rekishibunka/bunkazai/yanagawabunkazai/yanagawabunkazai_yanagawajyo.html|柳川城本丸跡|1581年以後の龍造寺氏による筑後支配拠点。
katsunoo|鳥栖市・勝尾城筑紫氏遺跡|https://www.city.tosu.lg.jp/soshiki/26/1806.html|城と城下町の解説|戦国後期の山城・館・城下町を別の代表点で登録。
nagasaki|長崎税関・長崎港開港の碑|https://www.customs.go.jp/nagasaki/annai/tanbou/tanbou_kaikounohi.html|歴史探訪本文|1570年町造り、1571年ポルトガル船入港。出島は配置しない。
hirado|平戸城公式・平戸の歴史|https://hirado-castle.jp/history/|1550年のポルトガル船入港|港町の根拠に使用。後代の平戸城を1582年に置かない。
akizuki|朝倉市・秋月城跡|https://www.city.asakura.lg.jp/soshiki/33/3507.html|秋月城跡の沿革|近世城は戦国期の古処山城と別。近世秋月城は除外。
koriyama|安芸高田市・郡山城跡|https://www.akitakata.jp/ja/shisei/section/kyouiku/shisekibunkazai/cultural_asset/siseki_kuni/mourisisiroato/kouriyamajyouato/|郡山城跡解説|毛利氏が一貫して本拠とした山城。広島城は代用しない。
okou|高知県立埋蔵文化財センター・岡豊城跡|https://www.kochi-maibun.jp/kochi_prefecture_historical_ruins_detail7.html|遺跡情報・発掘調査成果|長宗我部氏の居城と城郭の変遷。高知城は代用しない。
ichinomiya|徳島市・一宮城跡|https://www.city.tokushima.tokushima.jp/kankou/bunkazai/ichinomiya2018.html|一宮城跡の沿革|戦国期の軍事拠点。各城主の具体的在城日付は未確定。
sakai|堺市・堺環濠都市遺跡|https://www.city.sakai.lg.jp/kanko/rekishi/bunkazai/bunkazai/isekishokai/kangotoshi.html|堺環濠都市遺跡本文|中世の自治・貿易都市。1615年の焼失以前の都市を対象。
sakai_port|堺市・中世の貿易都市|https://www.city.sakai.lg.jp/shisei/toshi/rinkai/rinkaitoshi/kyukoshuhen/sakaikyumukashi/hitomono/index.html|堺港の変遷|江戸期に港形状が変化。中世港域の概略点に限定。
kyoto|京都市・上京と下京|https://www2.city.kyoto.lg.jp/somu/rekishi/fm/nenpyou/htmlsheet/toshi13.html|都市史13・上京と下京|御所周辺の上京と商業街区の下京。現代行政区とは異なる。
saika|和歌山市のあゆみ|https://www.city.wakayama.wakayama.jp/shisei/wakayama/1001005/1001031/1001030.html|中世の雑賀と鷺森|石山退去後の教団を迎えた雑賀の市街。近世和歌山城は置かない。
azuchi|滋賀県・安土城跡の調査と整備|https://www.pref.shiga.lg.jp/sd00/2591.html|築城と調査成果|1576年築城開始。対象は本能寺の変以前、焼失後ではない。
sakamoto|大津市・坂本城跡|https://www.city.otsu.lg.jp/bz/a/03/16/60747.html|坂本城跡|1571年の湖岸築城。城域・湖岸の精密復元ではない。
otsu|大津市・大津の歴史|https://www.city.otsu.lg.jp/sc/c/h/2566.html|中世と近世の歴史|京都の外港・門前町から港町への変遷。大津城と区別。
gifu|岐阜市・岐阜城天守閣|https://www.city.gifu.lg.jp/kankoubunka/kankou/1013051/1005097/1005098.html|岐阜城の歴史|織田信長の攻略と改称。現代復興天守の形状は採用しない。
hamamatsu|浜松市・浜松城の変遷|https://www.city.hamamatsu.shizuoka.jp/kouen/hennsen1.html|浜松城の変遷|1570年の拠点移転と改称。
kofu|甲府市・武田三代のまちづくり|https://www.city.kofu.yamanashi.jp/kids/ima/bunka/takeda.html|城下町の形成|1519年以後の館南側の城下。1582年の武田滅亡後の利用細部は未確定。
odawara|小田原市・小田原城|https://www.city.odawara.kanagawa.jp/kanko/corridor/castle/p09978.html|小田原城の歴史|北条氏の関東支配拠点。1590年の総構を1582年の輪郭として描かない。
odawara_town|小田原市・北条五代が残したもの|https://www.city.odawara.kanagawa.jp/encycl/neohojo5/012/|戦国城下町の発展|北条氏の継続した本拠による城下町形成。
kasugayama|上越市・春日山城跡|https://www.city.joetsu.niigata.jp/site/cultural-property/cultural-property-jpn002.html|春日山城跡・形成過程|上杉氏の山城。完成時の総構を対象年へ一括遡及しない。
kurokawa|会津若松観光ビューロー・鶴ヶ城|https://www.tsurugajo.com/tsurugajo/tensyukaku/|沿革年表|1384年の東黒川館から1593年鶴ヶ城命名以前の城を対象。
sannohe|三戸町・三戸城の歴史|https://www.town.sannohe.aomori.jp/soshiki/kyouikuiinkaijimukyoku/rekishi_bunka/1/1780.html|三戸城の沿革|1539年以降の築城伝承と1591年の居城移転。築城年の伝承性を保持。
yonezawa|米沢市・市勢要覧2025|https://www.city.yonezawa.yamagata.jp/material/files/group/45/shiseiyouran2025.pdf|歴史年表1567・1591年|伊達期の米沢城。天正期の正確な城域は未確認。
katsuyama|上ノ国町・文化財マップ|https://www.town.kaminokuni.lg.jp/contents/bunkazai_map/bunkazai_map1.pdf|勝山館の解説|1470年頃成立し16世紀に機能。和人・アイヌの地域交流を含む調査は未完了。
'''
sources=[]
for row in SOURCE_ROWS.strip().splitlines():
    i,title,url,locator,note=row.split('|')
    sources.append(dict(id=i,title=title,url=url,publisher=title.split('・')[0],publication_year=None,
        accessed='2026-09-11',locator=locator,observation=note,read_status='partial',
        scope='該当するウェブ本文・検索提供本文を確認。原典全体の精査ではない。',redistribute_original=False))

# id | name | roles | province | region | lon | lat | source ids | temporal | reason | old road node
ROWS='''
sadowara_castle|佐土原城|castle|hyuga|south_kyushu|131.425|32.052|sadowara miyazaki_national|inferred|1577年以後の居城利用から対象時点の継続を推定。山上部の代表点。|sadowara
kiyotake_castle|清武城|castle|hyuga|south_kyushu|131.397|31.862|kiyotake|inferred|1577～1587年の支配記事から利用を推定。既存清武点とは別の城域代表点。|kiyotake
mukasa_castle|穆佐城|castle|hyuga|south_kyushu|131.315|31.946|miyazaki_national|inferred|中世の地域支配城として採用。1582年の曲輪構成は未確定。|
tonokori_castle|都於郡城|castle|hyuga|south_kyushu|131.364|32.062|tonokori|unresolved|所在地は確認できるが伊東氏退去後の対象時点の利用を追加調査。|
obi_castle|飫肥城|castle|hyuga|south_kyushu|131.350|31.634|obi|inferred|戦国期の城として採用。地震後の新本丸を避け旧本丸側の地域代表位置。|obi
miyakonojo_castle|都城|castle|hyuga|south_kyushu|131.050|31.716|miyakonojo|inferred|地域支配の本拠。1375年の成立伝承と1615年の廃城の間の利用を推定。|miyakonojo
iino_castle|飯野城|castle|hyuga|south_kyushu|130.866|32.045|ebino|inferred|義弘の1564年から26年間の在城記事に対象年が含まれる。|
kakuto_castle|加久藤城|castle|hyuga|south_kyushu|130.804|32.057|ebino|inferred|義弘期の城館として採用。改修・廃絶の細かい年次は未確認。|
uchi_castle|内城|castle|satsuma|south_kyushu|130.558|31.611|uchi|inferred|島津氏の居館。大龍小学校付近は史料に示された旧居館位置の参照であり学校を城に転用したものではない。|kagoshima
kanmachi_town|鹿児島・上町付近|settlement|satsuma|south_kyushu|130.561|31.605|kanmachi|inferred|内城時代の城下・交通交易中心。町の面積は復元しない。|kagoshima
kagoshima_port|鹿児島の港域付近|port|satsuma|south_kyushu|130.568|31.606|kanmachi|inferred|港湾と城下の一体形成記事から地域港を選定。1582年の泊地・上陸点は未確定。|kagoshima
shibushi_castle|志布志城・内城|castle|hyuga|south_kyushu|131.099|31.479|shibushi|inferred|志布志津を抑える中世城郭群の代表点。志布志は旧日向国として記録。|
shibushi_port|志布志津付近|port settlement|hyuga|south_kyushu|131.100|31.470|shibushi|inferred|島津荘の港として発展した交易拠点。前川河口の港町を概略表示。|
bonotsu_port|坊津付近|port settlement|satsuma|south_kyushu|130.222|31.266|bonotsu|inferred|中世後期の対外貿易港町として選定。個別の1582年記事と岸壁位置は未確認。|
chiran_castle|知覧城|castle|satsuma|south_kyushu|130.447|31.364|chiran|inferred|15世紀以降の佐多氏本拠。近世の武家屋敷群とは別位置。|
koyama_castle|高山城|castle|osumi|south_kyushu|130.950|31.328|koyama|unresolved|1580年の肝付氏移封後の利用継続を確認するまで保留。|
aburatsu_port|油津の港域・調査候補|port settlement|hyuga|south_kyushu|131.405|31.584|aburatsu|unresolved|近世近代資料と区別し1582年の港域・機能の根拠を調査中。|
takaoka_castle_late|天ヶ城（対象外）|castle|hyuga|south_kyushu|131.301|31.958|kiyotake|out_of_period|1600年以降の天ヶ城を1582年の城として配置しない。|takaoka_hyuga
otomo_yakata|大友氏館|castle|bungo|kyushu|131.616|33.228|funai funai_garden|inferred|16世紀後半の館・庭園遺構を確認。近世府内城とは別。|funai
funai_town|府内町付近|settlement|bungo|kyushu|131.612|33.230|funai|inferred|中世府内町の代表点。館と町を別IDで関連付ける。|funai
usuki_castle|丹生島城|castle|bungo|kyushu|131.808|33.125|usuki|inferred|1562年築城の宗麟の拠点。現代の陸続き形状を歴史的接続としない。|
usuki_port|臼杵の港町付近|port settlement|bungo|kyushu|131.801|33.123|usuki|inferred|宗麟期の国際商業都市。舟着場は未確定。|
hitoyoshi_castle|人吉城・中世城域|castle|higo|kyushu|130.762|32.204|hitoyoshi|inferred|近世城背後の中世丘陵城を地域代表点として置く。|hitoyoshi
furufumoto_castle|古麓城|castle|higo|kyushu|130.638|32.490|hitoyoshi|inferred|相良氏の八代側本拠として選定。1581年以後の支配者を自動設定しない。|yatsushiro
hakata_port|博多|port settlement|chikuzen|kyushu|130.411|33.599|hakata|inferred|中世の国際貿易港湾都市。近代埠頭へ移動しない。|hakata
tachibana_castle|立花城|castle|chikuzen|kyushu|130.464|33.668|tachibana|inferred|道雪の城督就任後の博多防衛拠点として選定。|
yanagawa_castle|柳川城|castle|chikugo|kyushu|130.398|33.157|yanagawa|inferred|1581年以後の龍造寺氏の筑後支配拠点として選定。|
katsunoo_castle|勝尾城|castle|hizen|kyushu|130.469|33.417|katsunoo|inferred|戦国後期の筑紫氏の本城。山麓の城下町と別の地点。|
katsunoo_town|勝尾城下付近|settlement|hizen|kyushu|130.478|33.402|katsunoo|inferred|城下町遺跡として確認できる地域を概略点で表示。|
nagasaki_port|長崎|port settlement|hizen|kyushu|129.874|32.744|nagasaki|inferred|1571年開港後の貿易拠点。江戸町・旧岬側の概略地域。|nagasaki
hirado_port|平戸の港町付近|port settlement|hizen|kyushu|129.554|33.369|hirado|inferred|1550年以降の貿易港町。オランダ商館・近世城郭は含めない。|
akizuki_castle_late|近世秋月城（対象外）|castle|chikuzen|kyushu|130.694|33.468|akizuki|out_of_period|近世の城。戦国期の古処山城は別途調査。|
koriyama_castle|吉田郡山城|castle|aki|chugoku|132.706|34.674|koriyama|inferred|毛利氏の継続した本拠として選定。|yoshida_aki
okou_castle|岡豊城|castle|tosa|shikoku|133.612|33.593|okou|inferred|長宗我部氏の居城と発掘成果から対象時点の利用を推定。|
ichinomiya_castle|阿波一宮城|castle|awa|shikoku|134.461|34.031|ichinomiya|inferred|阿波の軍事拠点。長宗我部氏への移行日付は本データでは断定しない。|
sakai_town|堺|settlement|izumi|kinki|135.475|34.582|sakai|inferred|中世環濠都市として選定。町割・都市面積は未復元。|sakai
sakai_port|堺の港域付近|port|izumi|kinki|135.465|34.585|sakai_port|inferred|中世港域の地域代表点。江戸期以後の旧港形状とは分離。|sakai
kyoto_kamigyo|京・上京付近|settlement|yamashiro|kinki|135.754|35.031|kyoto|inferred|御所周辺の都市域を代表。現在の上京区中心とは定義が異なる。|kyoto
kyoto_shimogyo|京・下京付近|settlement|yamashiro|kinki|135.756|35.005|kyoto|inferred|三条・四条周辺の商業街区を代表。|kyoto
saika_town|雑賀・鷺森付近|settlement|kii|kinki|135.168|34.239|saika|inferred|石山退去後の本願寺教団を迎えた町の地域代表点。|saika
azuchi_castle|安土城|castle|omi|kinki|136.139|35.156|azuchi|inferred|本能寺の変直前の城。焼失後の状態を混在させない。|azuchi
sakamoto_castle|坂本城|castle|omi|kinki|135.880|35.060|sakamoto|inferred|1571年築城の湖岸城郭。最新の精密城域への照合は未完了。|sakamoto
otsu_port|大津|port settlement|omi|kinki|135.865|35.013|otsu|inferred|京都の外港・門前町の継続を推定。湖港として分類。|otsu
gifu_castle|岐阜城|castle|mino|tokai|136.782|35.434|gifu|inferred|織田期の山城。山麓居館と天守の模型は作らない。|gifu
hamamatsu_castle|浜松城|castle|totomi|tokai|137.725|34.712|hamamatsu|inferred|1570年移転後の徳川氏本拠。|hamamatsu
kofu_town|甲府・古府中付近|settlement|kai|koshin|138.577|35.680|kofu|inferred|武田期に形成された都市の継続を推定。武田氏の存続や館の継続利用とは分ける。|kofu
odawara_castle|小田原城|castle|sagami|kanto|139.150|35.250|odawara|inferred|北条氏の関東支配拠点。1582年の主郭の精密比定ではない。|odawara
odawara_town|小田原の城下付近|settlement|sagami|kanto|139.157|35.252|odawara_town|inferred|北条氏の戦国城下町。近世の町割を描かない。|odawara
kasugayama_castle|春日山城|castle|echigo|hokuriku|138.206|37.148|kasugayama|inferred|上杉氏の本拠の継続を推定。御館の乱後の細部は未復元。|kasugayama
kurokawa_castle|黒川城|castle|mutsu|tohoku|139.930|37.487|kurokawa|inferred|鶴ヶ城への改称前の城館。後代天守を表示しない。|kurokawa
sannohe_castle|三戸城|castle|mutsu|tohoku|141.262|40.379|sannohe|inferred|南部氏の居城。所在地と年代は町の沿革を参照し伝承性を保持。|sannohe
yonezawa_castle|米沢城付近|castle|dewa|tohoku|140.105|37.910|yonezawa|inferred|伊達期の城域の概略位置。近世遺構をそのまま採用しない。|yonezawa
katsuyama_tate|勝山館|castle settlement|ezo|hokkaido|140.103|41.798|katsuyama|inferred|16世紀の館・集住域。北方交易の拠点として選定し、他のアイヌ集落は未調査として残す。|katsuyama
'''
sites=[]
for row in ROWS.strip().splitlines():
    i,name,roles,province,region,lon,lat,refs,temporal,reason,old=row.split('|')
    refs=refs.split(); roles=roles.split()
    status='deferred' if temporal=='unresolved' else 'excluded' if temporal=='out_of_period' else 'accepted'
    group={'sadowara_castle':'sadowara','uchi_castle':'kagoshima','kanmachi_town':'kagoshima','kagoshima_port':'kagoshima',
        'shibushi_castle':'shibushi','shibushi_port':'shibushi','otomo_yakata':'funai','funai_town':'funai',
        'usuki_castle':'usuki','usuki_port':'usuki','katsunoo_castle':'katsunoo','katsunoo_town':'katsunoo',
        'sakai_town':'sakai','sakai_port':'sakai','kyoto_kamigyo':'kyoto','kyoto_shimogyo':'kyoto',
        'odawara_castle':'odawara','odawara_town':'odawara'}.get(i,i)
    sites.append(dict(id=i,name_1582=None,display_name=name,aliases=[old] if old else [],roles=roles,
        site_group_id=group,province_id=province,region_id=region,temporal_status=temporal,temporal_note=reason,
        name_status='reference_name',name_note='出典で用いられる歴史地名を表示。1582年の表記そのものの原文照合は未完了。',
        validity_evidence=[dict(source_ref=s,locator=next(x['locator'] for x in sources if x['id']==s),note=reason) for s in refs],
        lonlat=[float(lon),float(lat)],location_status='area_estimate',location_note='出典の所在地・地域説明を参照した手動の地域代表点。原図の位置補正・主郭や岸壁の測量照合は未実施。',
        uncertainty_m=None,display_anchor=None,importance=1 if region!='south_kyushu' else 2,
        selection_reason=reason,adoption_status=status,adoption_reason='史料にある拠点の地域代表表示として採用。' if status=='accepted' else reason,
        source_refs=refs,claims={k:[dict(source_ref=s,locator=next(x['locator'] for x in sources if x['id']==s),assessment='reference_or_inference') for s in refs] for k in ['name','temporal','location','function']},
        connection_anchors=[],review_notes=['対象時点の判定は各資料からの推定を含む。城主・人口・石高は未設定。','更新：2026-09-11'],
        port_type=('lake' if i=='otsu_port' else 'sea_or_estuary') if 'port' in roles else None))
if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    path=OUT/'settlements_1582.json'
    if path.exists(): raise SystemExit('Refusing to overwrite the editorial master; edit JSON directly.')
    (OUT/'sources.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    path.write_text(json.dumps(dict(schema_version=1,target_year=1582,temporal_scope='本能寺の変の直前',
        coverage='全国の代表拠点初版。全旧国・全主要候補の網羅調査は未完了。南九州を優先。',sites=sites),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Editorial candidates:',len(sites))
