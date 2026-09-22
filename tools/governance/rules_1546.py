"""Reviewed exceptions and research references. IDs always refer to the existing roster.

Regional rules are GAME approximations, never proof of exclusive district ownership.
Unknown local rulers remain unknown; historical names without roster IDs are references.
"""

SOURCES = {
 'kuwana': ('桑名市・中世桑名のシンポジウム資料', 'https://www.city.kuwana.lg.jp/documents/11574/symposium10.pdf', '十楽の津の自治。郡全体の独立支配とは区別。'),
 'nishio': ('西尾市・吉良義安', 'https://www.city.nishio.aichi.jp/sportskanko/bunkazai/1001485/1001610/1001677/1002828.html', '西条吉良氏の城。1546年1月の当主・城代は継承時期を留保。'),
 'obama_mutsu': ('岩代観光協会・小浜城址', 'https://evergreen-net.jp/小浜城址/', '陸奥小浜城は大内氏の城。山口の大内家や若狭小浜と区別。創築者を1546年城主に流用しない。'),
 'kasama': ('笠間市・笠間氏の資料', 'https://www.city.kasama.lg.jp/data/doc/1317281445_doc_22_4.pdf', '笠間氏の城。後年の当主を1546年に遡及せず個人名は留保。'),
 'shingu': ('新宮市・下本町遺跡発掘調査報告', 'https://www.city.shingu.lg.jp/div/bunka-1/pdf/iseki/shimohonmachi_7.pdf', '堀内氏の勢力と城下の前史。1546年の個人は未確定。'),
 'mihara': ('三原市・三原城跡', 'https://www.city.mihara.hiroshima.jp/soshiki/50/139854.html', '1567年築城とされる。'),
 'shintakayama': ('三原市・新高山城跡', 'https://www.city.mihara.hiroshima.jp/soshiki/50/139862.html', '1552年築城。'),
 'kaizu': ('長野市・松代城の歴史', 'https://www.city.nagano.nagano.jp/n151100/contents/p006083.html', '海津城は1560年築城とされる。'),
 'nagahama': ('長浜市・歴史的風致維持向上計画', 'https://www.city.nagahama.lg.jp/cmsfiles/contents/0000001/1238/R8rekimachikeikaku_1.pdf', '1574年頃から今浜に築城。'),
 'arikoyama': ('豊岡市・有子山城跡', 'https://www.city.toyooka.lg.jp/shisei/1027491/1027495/1029005.html', '1574年山名祐豊が築城。'),
 'miyazu': ('京都府教育委員会・宮津城跡', 'https://www.kyoto-be.ne.jp/bunkazai/cms/?p=2142', '1580年細川氏入国以降の築城。'),
 'shinshiro': ('新城市・市名の由来', 'https://www.city.shinshiro.lg.jp/kurashi/zeikin/gaiyou/gaiyo.files/20161101-100254.pdf', '奥平氏は1576年築城。1532年の別地の新城とは区別。'),
 'sanmaibashi': ('沼津市・三枚橋城跡', 'https://www.city.numazu.shizuoka.jp/shisei/profile/bunkazai/siro/sanmai.htm', '1579年武田勝頼の築城とされる。'),
 'usuki': ('大分県・臼杵城', 'https://www.pref.oita.jp/site/archive/200976.html', '1562年築城。'),
 'gujo': ('郡上八幡城・歴代城主一覧', 'https://www.hachiman-castle.com/history/load/', '1559年に盛数が八幡城の基を築く。'),
 'shibushi': ('志布志市・志布志城の歴史', 'https://www.city.shibushi.lg.jp/soshiki/22/1520.html', '1536年新納氏降伏後、豊州島津氏が入り1562年肝付氏に落とされる。'),
 'katsunoo': ('鳥栖市・勝尾城筑紫氏遺跡', 'https://www.city.tosu.lg.jp/uploaded/attachment/37006.pdf', '惟門は1549年以前に大内方へ転じた。既存の大内家武将設定を優先。'),
 'mito': ('水戸市立博物館・江戸氏', 'https://museum-mito.jp/exhibition/5058.html', '1590年以前の約160年間は江戸氏が水戸城主。1546年の佐竹直轄とはしない。'),
 'makabe': ('桜川市・真壁氏の歴史', 'https://www.city.sakuragawa.lg.jp/temporary/page006693.html', '平安期以降の真壁氏の領域。特定年の当主名は別途留保。'),
 'yamura': ('日本の城がわかる事典・谷村城', 'https://kotobank.jp/word/谷村城-180387', '1532年小山田信有が谷村へ移る。複数世代の信有の区別は留保。'),
 'yahazu': ('岡山県・矢筈城跡', 'https://www.pref.okayama.jp/uploaded/attachment/262251.pdf', '1532～1533年に草苅衡継が築城。'),
 'hakuchi': ('徳島県立博物館・大西覚用', 'https://museum.bunmori.tokushima.jp/museum_documents/museumnews/mnews106/106_5_infobox.html', '白地城主大西氏。主に1576～1578年の記録で1546年の個人は確定できない。'),
 'kannabe': ('ひろしま文化大百科・神辺城跡', 'https://www.hiroshima-bunka.jp/modules/newdb/detail.php?id=705', '山名理興が1549年まで神辺城を守る。1546年に大内直轄へしない。'),
 'yokoyama': ('京都府埋蔵文化財調査研究センター・福知山城跡', 'https://kyotofu-maibun.or.jp/data/kankou/kankou-pdf/jyouhou/kyoutofu-J12.pdf', '横山城は塩見頼勝・頼氏の城と伝える。光秀の本格築城は1579年以後。'),
 'naegi': ('文化庁・苗木城跡', 'https://online.bunka.go.jp/heritages/detail/172145/2', '遠山氏の領域。後年の遠山直廉を1546年城主へ遡及しない。'),
 'kanbe': ('三重県・神戸氏の盛衰', 'https://www.bunka.pref.mie.lg.jp/rekishi/kenshi/asp/Q_A/detail120.html', '神戸氏の城と奉行衆。1546年の当主継承は未確定。'),
 'ouchi': ('山口市・大内氏の領国', 'https://www.city.yamaguchi.lg.jp/uploaded/attachment/45144.pdf', '豊前・筑前・石見・安芸への勢力。郡全域の排他的支配を証明しない。'),
 'shinano': ('長野県立歴史館・信濃史料 巻十一', 'https://adeac.jp/npmh/top/topg/11004.html', '1545年伊那進出、1546年佐久内山城、1548年村上・小笠原の抗争。南北を分離。'),
 'date': ('伊達市・伊達氏天文の乱', 'https://www.city.fukushima-date.lg.jp/soshiki/87/1145.html', '1542～1548年の内戦。1546年は稙宗・晴宗両派。'),
 'satsuma': ('鹿児島県・島津家の内紛と三州統一', 'https://www.pref.kagoshima.jp/ab23/pr/gaiyou/rekishi/tyuusei/sansyu.html', '1550年でも島津領は薩摩の半分程度。北薩・大隅・日向の諸家を区別する。'),
 'iga': ('伊賀市・伊賀衆と惣国', 'https://www.city.iga.lg.jp/cmsfiles/contents/0000000/990/1.pdf', '伊賀衆の自立と六角・北畠の影響。単独の大名による支配に置換しない。'),
 'sakai': ('堺市・堺環濠都市遺跡', 'https://www.city.sakai.lg.jp/kanko/rekishi/bunkazai/bunkazai/isekishokai/kangotoshi.html', '1484年に会合衆が文献に現れる自治都市。'),
 'tochio': ('長岡市・栃尾で旗揚げ', 'https://www.city.nagaoka.niigata.jp/kankou/rekishi/ijin/hataage.html', '景虎は1548年の春日山入城まで栃尾に在城。'),
 'kawagoe': ('川越市・河越夜戦', 'https://www.city.kawagoe.saitama.jp/shisei/mayor/1018956.html', '1537年北条氏が河越城を攻略。1545～1546年の包囲と領有を混同しない。'),
 'azuchi': ('近江八幡観光物産協会・安土城跡', 'https://www.omi8.com/spot/detail_1217.html', '1576年築城開始。1546年の信長の城にはしない。'),
 'sakamoto': ('大津市・坂本城跡', 'https://www.city.otsu.lg.jp/bz/a/03/16/60747.html', '1571年に信長が光秀に命じて築城。'),
 'uchi': ('垂水市・垂水島津家墓所', 'https://www.city.tarumizu.lg.jp/bunka/kurashi/kosodate/roman/tarumzusimadubosyo.html', '1550年に貴久が内城を築城して移転。'),
 'nagasaki': ('大村市・大村純忠と南蛮貿易', 'https://www.city.omura.nagasaki.jp/kankou/kankouspot/kirishitan/nanbanboueki.html', '1571年の長崎開港。1546年の国際貿易港・純忠支配を遡及しない。'),
 'kanazawa': ('石川県・金沢城公園', 'https://www.pref.ishikawa.lg.jp/kouen/siro/kanazawajyo.html', '1546年に金沢御堂創建。同年内の月日未確定。'),
 'honganji': ('京都市考古資料館・第265回文化財講座', 'https://www.kyoto-arc.or.jp/News/s-kouza/kouza265.pdf', '1533年石山を本寺とし1554年に証如没。'),
 'awa': ('勝瑞・阿波守護所関係年表', 'https://syugomati-syouzui.sakuraweb.com/pdf/nenpyou.pdf', '1546年は細川持隆の守護期。三好の後年の統一支配と分離。'),
 'kawachi': ('富田林市史・遊佐長教の動向', 'https://adeac.jp/tondabayashi-city/texthtml/d000020/cp000002/ht000115', '稙長は1545年没。家督継承に異説があるため旧配置台帳の稙長を現役にしない。'),
 'ryuzoji': ('佐賀市・龍造寺村中城調査', 'https://www.city.saga.lg.jp/site_files/file/usefiles/downloads/s36339_20130529100315.pdf', '1546年家兼没。水ヶ江系と村中宗家の継承を区別して留保。'),
}

# Fallbacks apply ONLY where existing district placements / house pools do not decide.
# Multiple houses are retained as competing regional candidates; no nearest-neighbour annexation.
REGIONAL = {
 'aki': ('ouchi','ouchi'), 'bingo': ('ouchi|amago','ouchi'),
 'bitchu': ('amago|mimura',None), 'bizen': ('uragami|amago',None),
 'mimasaka': ('amago|uragami',None), 'izumo': ('amago',None),
 'hoki': ('amago',None), 'inaba': ('yamana_inaba',None),
 'iwami': ('ouchi|amago','ouchi'), 'suo': ('ouchi','ouchi'), 'nagato': ('ouchi','ouchi'),
 'buzen': ('ouchi','ouchi'), 'chikuzen': ('ouchi|otomo','ouchi'),
 'chikugo': ('otomo',None), 'bungo': ('otomo',None),
 'higo': ('otomo|aso|sagara',None), 'hizen': ('shoni|ryuzoji|arima|matsuura',None),
 'satsuma': ('shimazu|shimazu_sasshu','satsuma'), 'osumi': ('kimotsuki|shimazu','satsuma'),
 'hyuga': ('ito|shimazu_hoshu','satsuma'),
 'tosa': ('ichijo|motoyama|chosokabe',None), 'iyo': ('kono|saionji',None),
 'awa_shikoku': ('hosokawa_awa|miyoshi','awa'), 'sanuki': ('hosokawa_awa|kagawa|sogo','awa'),
 'tajima': ('yamana',None), 'tango': ('isshiki',None), 'tanba': ('hosokawa|hatano',None),
 'harima': ('akamatsu',None), 'settsu': ('hosokawa|miyoshi',None),
 'izumi': ('hosokawa_izumi',None), 'kawachi': ('hatakeyama_kawachi','kawachi'),
 'yamashiro': ('ashikaga|hosokawa',None), 'yamato': ('tsutsui|ochi',None),
 'kii': ('local_kii',None), 'iga': ('iga_sokoku','iga'),
 'omi': ('rokkaku|azai',None), 'ise': ('kitabatake|kitashirakawa',None),
 'owari': ('oda_nobuhide|oda_iwakura|oda_kiyosu',None),
 'mikawa': ('matsudaira|imagawa',None), 'totomi': ('imagawa',None), 'suruga': ('imagawa',None),
 'mino': ('saito|toki',None), 'hida': ('miki',None), 'kai': ('takeda',None),
 'shinano': ('takeda|murakami_shinano|ogasawara','shinano'),
 'echizen': ('asakura',None), 'kaga': ('bessho_honganji','kanazawa'),
 'etchu': ('jinbo|shiina',None), 'noto': ('hatakeyama_noto',None),
 'echigo': ('nagao|uesugi_echigo',None), 'izu': ('hojo',None), 'sagami': ('hojo',None),
 'musashi': ('hojo|uesugi_yamanouchi|uesugi_ogigayatsu','kawagoe'),
 'kozuke': ('uesugi_yamanouchi',None), 'shimotsuke': ('utsunomiya|nasu',None),
 'hitachi': ('satake|oda_hitachi',None), 'shimosa': ('chiba|koga',None),
 'kazusa': ('satomi|mariyatsu_shiizu',None), 'honshu-area-30': ('satomi',None),
 'honshu-area-01': ('nanbu',None), 'honshu-area-03': ('ando|onodera|tozawa',None),
 'honshu-area-04': ('local_mutsu',None), 'honshu-area-05': ('osaki|kasai|date','date'),
 'honshu-area-06': ('mogami|daihoji|date','date'), 'honshu-area-08': ('iwaki|soma|date','date'),
 'honshu-area-09': ('ashina|date','date'),
}

# Explicit regional partitions; still provisional game coverage on modern comparison geometry.
PARTITIONS = {
 'shinano': [('西筑摩','kiso'),('東筑摩|南安曇|北安曇','ogasawara'),('下伊那','local_shinano'),('上伊那|諏訪|南佐久','takeda'),('更科|埴科|小県|上水内|上高井','murakami_shinano'),('下高井|下水内','takanashi')],
 'iyo': [('宇和|喜多','saionji'),('越智','murakami_noshima')],
 'higo': [('八代|葦北|球摩','sagara'),('阿蘇|益城','aso')],
 'hyuga': [('臼杵','ito_hyuga_tsuchimochi'),('諸県','ito'),('南那珂','shimazu_hoshu')],
 'osumi': [('肝属','kimotsuki'),('桑原|姶良','local_osumi'),('南大隅','nejime')],
 'satsuma': [('出水','shimazu_sasshu'),('薩摩|伊佐|高城','local_satsuma'),('鹿児島|谿山|給黎|川邊|揖宿|頴娃|阿多|日置','shimazu')],
 'hizen': [('高来','arima'),('彼杵','omura'),('松浦','matsuura')],
 'etchu': [('下新川','shiina'),('婦負|上新川|射水|礪波','jinbo')],
 'omi': [('浅井|伊香|坂田','azai'),('高島','local_omi'),('滋賀|栗太|甲賀|野洲|蒲生|神崎|犬上|愛知','rokkaku')],
 'ise': [('桑名|員弁|朝明|三重|鈴鹿|河曲','local_ise'),('度会','jingu')],
 'honshu-area-04': [('磐井|江刺|胆沢','kasai'),('和賀','waga'),('稗貫','hienuki'),('紫波','shiba_shiwa'),('九戸','kunohe'),('岩手','nanbu')],
 'honshu-area-03': [('飽海','daihoji'),('秋田|山本|河邊','ando'),('仙北','tozawa'),('雄勝|平鹿','onodera')],
 'honshu-area-06': [('置賜','date'),('田川','daihoji'),('村山','mogami'),('最上','onodera')],
 'honshu-area-08': [('白川','shirakawa'),('石川','ishikawa_mutsu'),('菊多|磐前|磐城|楢葉','iwaki'),('標葉|行方|宇多','soma'),('亘理|伊具|刈田','date'),('田村','tamura')],
 'honshu-area-09': [('会津|大沼|河沼|耶麻','ashina'),('岩瀬','nikaido'),('安達','nihonmatsu'),('信夫|伊達','date')],
 'honshu-area-05': [('柴田|名取','date'),('栗原|桃生|牡鹿|気仙|本吉','kasai'),('黒川|加美|玉造|遠田|志田','osaki')],
 'musashi': [('豊島|南葛飾|南足立|荏原|多摩|橘樹|都筑|久良岐','hojo'),('秩父|児玉|那珂|榛沢|幡羅|男衾|大里','uesugi_yamanouchi')],
}

# Explicit scenario ownership requested by the project owner. These take priority
# over officer placement and regional fallback rules without changing geometry.
USER_OWNERSHIP_OVERRIDES = {
 'iga/merged-dff55b62903ec44f': 'rokkaku',  # 阿拝郡・伊賀上野地域
 'ise/candidate-district-candidate-g07013': 'kitabatake',  # 現行区画で志摩地域を含む度会郡
}

EXTRA_HOUSES = {
 'kuwana_council': ('桑名の自治衆',None,'kuwana'),
 'kira_saijo': ('吉良家（西条）',None,'nishio'),
 'ouchi_obama': ('大内家（陸奥小浜）',None,'obama_mutsu'),
 'kasama': ('笠間家',None,'kasama'),
 'horiuchi_shingu': ('堀内家（新宮）',None,'shingu'),
 'local_shima': ('志摩の海領主（帰属未詳）',None,None),
 'edo_mito': ('江戸家（水戸）',None,'mito'),
 'makabe': ('真壁家',None,'makabe'),
 'kusakari': ('草苅家','草苅衡継','yahazu'),
 'onishi_hakuchi': ('大西家（白地）',None,'hakuchi'),
 'yamana_kannabe': ('山名家（神辺）','山名理興','kannabe'),
 'shiomi_yokoyama': ('塩見家（横山）',None,'yokoyama'),
 'toyama_naegi': ('遠山家（苗木）',None,'naegi'),
 'kanbe_ise': ('神戸家（伊勢）',None,'kanbe'),
 'hosokawa_awa': ('細川家（阿波守護）','細川持隆','awa'),
 'iga_sokoku': ('伊賀の国人衆・惣国',None,'iga'),
 'sakai_council': ('堺会合衆',None,'sakai'),
 'jingu': ('伊勢神宮・宇治山田の自治衆',None,None),
 'koyasan': ('高野山寺院衆',None,None),
 'waga': ('和賀家',None,None), 'hienuki': ('稗貫家',None,None),
 'shiba_shiwa': ('斯波家（紫波）',None,None),
 **{'local_'+key: (name+'の在地領主（帰属未詳）',None,None) for key,name in [('kii','紀伊'),('mutsu','陸中'),('shinano','南信濃'),('osumi','大隅'),('satsuma','北薩摩'),('omi','高島'),('ise','北伊勢')]},
}

# Site-house choices grounded in the existing faction setup; exact deputies are separate.
# These are scenario allocations unless an individual source explicitly verifies the office.
SITE_HOUSES = {
 'kuwana_council': '桑名', 'kira_saijo':'西尾城', 'ouchi_obama':'小浜城',
 'kasama':'笠間城', 'horiuchi_shingu':'新宮',
 'ito': '佐土原城|清武城|穆佐城|都於郡城|飯野城|加久藤城',
 'shimazu_hoshu': '飫肥城|油津の港域・調査候補|志布志|志布志津付近', 'hongo': '都城',
 'shimazu': '鹿児島・内城|鹿児島・上町付近|鹿児島の港域付近|坊津付近|知覧城|山川付近',
 'kimotsuki': '高山城|内之浦付近', 'nejime':'根占付近',
 'otomo': '府内・大友館|府内町付近|臼杵|臼杵の港町付近|立花城|柳川城|岡城',
 'sagara': '人吉城・中世城域|古麓城', 'ouchi':'博多|岩石城|馬ヶ岳城|宮島|桜尾城|草津|山口|赤間関|上関',
 'omura':'長崎', 'matsuura':'平戸の港町付近', 'mori':'吉田郡山城',
 'chosokabe':'岡豊城', 'sakai_council':'堺|堺の港域付近', 'ashikaga':'京都|京・下京付近',
 'saika':'雑賀・鷺森付近', 'rokkaku':'安土城|坂本城|大津|日野城',
 'saito':'岐阜城|大垣城|美濃金山城', 'imagawa':'浜松城|掛川城|清水湊|興国寺城|三枚橋城',
 'takeda':'甲府・古府中付近|若神子城|高島古城|岩村城', 'oyamada_gunnai':'谷村城',
 'hojo':'小田原|小田原の城下付近|江戸城|川越城|小机城|玉縄城|三崎城|津久井城|鎌倉|品川湊',
 'nagao':'春日山城|直江津|柏崎|与板城|栃尾城|坂戸城|新発田城',
 'honjo_echigo':'本庄城', 'ashina':'黒川城', 'nanbu':'三戸城|大浦城|堀越城',
 'date':'米沢城付近|白石城|丸森城', 'kakizaki':'勝山館', 'kunohe':'九戸城',
 'shiba_shiwa':'高水寺城', 'hienuki':'鳥谷ヶ崎城', 'kasai':'寺池城', 'soma':'小高城',
 'nikaido':'須賀川城', 'shirakawa':'白河小峰城|赤館城', 'nihonmatsu':'二本松城',
 'mogami':'山形城|上山城|天童城|延沢城', 'daihoji':'尾浦城|酒田',
 'onodera':'鮭延城|横手城', 'ando':'檜山城|湊城|大館城', 'tozawa':'角館城',
 'rusu':'塩竈', 'ota':'岩付城', 'narita':'忍城', 'uesugi_yamanouchi':'鉢形城|滝山城|深谷城|厩橋城',
 'uesugi_ogigayatsu':'松山城', 'satomi':'岡本城|久留里城|佐貫城|小田喜城',
 'chiba':'本佐倉城|臼井城', 'koga':'関宿城|古河城', 'yuki':'結城城',
 'satake':'太田城', 'oda_hitachi':'小田城|土浦城', 'utsunomiya':'宇都宮城',
 'sano':'唐沢山城', 'aizu_nagano':'箕輪城', 'yura':'金山城',
 'kiso':'妻籠|木曽福島', 'ogasawara':'深志城', 'murakami_shinano':'海津城|荒砥城|戸石城',
 'takanashi':'飯山城', 'asakura':'北ノ庄城|府中城|敦賀',
 'bessho_honganji':'金沢城|大聖寺城|小松城|松任城|石山本願寺',
 'jinbo':'富山城|増山城|守山城|木舟城|城生城|放生津', 'shiina':'魚津城|松倉城',
 'hatakeyama_noto':'輪島', 'takeda_wakasa':'小浜', 'oda_kiyosu':'清洲城',
 'oda_iwakura':'犬山城', 'kitashirakawa':'安濃津城', 'kitabatake':'松ヶ島城|鳥羽', 'jingu':'宇治山田',
 'miki':'桜洞城', 'matsudaira':'岡崎城', 'mizuno':'刈谷城', 'toda_tahara':'吉田城',
 'oda_nobuhide':'熱田', 'hosokawa':'高槻城|茨木城|尼崎|兵庫津|勝龍寺城|淀古城',
 'bessho':'三木城', 'kodera':'姫路城', 'akamatsu':'龍野城|利神城', 'yamana':'有子山城|竹田城',
 'hatano':'亀山城@tanba', 'ogino_kuroi':'黒井城', 'isshiki':'宮津城|弓木城',
 'tsutsui':'奈良|郡山城|筒井城', 'koyasan':'高野山', 'negoro':'根来寺', 'azai':'長浜城',
 'amago':'月山富田城|三刀屋城|赤穴城|岩屋城|林野城|羽衣石城|打吹城|尾高城',
 'misawa_izumo':'三沢城', 'kobayakawa_numata':'新高山城', 'kobayakawa':'竹原|三原城',
 'mimura':'備中松山城|備中高松城', 'uragami':'岡山城', 'miura_mimasaka':'高田城',
 'yamana_inaba':'鳥取城|鹿野城|若桜鬼ヶ城', 'masuda':'七尾城', 'tsuwano':'三本松城',
 'kikkawa':'日野山城', 'kono':'湯築城|川之江城|金子城', 'saionji':'大洲城|黒瀬城|板島丸串城',
 'hosokawa_awa':'勝瑞城|撫養城|引田城', 'sogo':'十河城', 'kagawa':'天霧城', 'ichijo':'中村',
 'ryuzoji':'村中城', 'aso':'隈本城', 'akizuki':'古処山城', 'arima':'日野江城',
 'hosokawa_izumi':'岸和田城', 'hatakeyama_kawachi':'高屋城',
 'edo_mito':'水戸城', 'makabe':'真壁城', 'kusakari':'矢筈城',
 'onishi_hakuchi':'白地城', 'yamana_kannabe':'神辺城', 'shiomi_yokoyama':'福知山城',
 'toyama_naegi':'苗木城', 'kanbe_ise':'神戸城',
}

# Use explicit existing descriptions, never text-match a later-life biography automatically.
OFFICE_OVERRIDES = {
 '岩村城': ('遠山景前','scenario_appointment','既存武将設定の武田家所属を優先して任命。史実上の1546年の武田家への従属時期は留保。',None),
 '勝尾': ('筑紫惟門','scenario_appointment','現行の大内家武将設定を優先。鳥栖市資料も1549年以前の大内方への転属を述べるが、1546年の月日は未確定。','katsunoo'),
 '栃尾城': ('上杉謙信','existing_office','既存設定が長尾景虎の栃尾城主を明記。長岡市資料でも確認。','tochio'),
 '黒井城': ('荻野秋清','existing_office','既存設定の1544年寄進・在城記事を優先。赤井直正への継承は1554年。',None),
 '刈谷城': ('水野信元','scenario_direct','既存設定が信近の1546年城主説を留保するため信元の直轄とする。',None),
 '石山本願寺': ('証如','historical_office','1546年の門主。顕如の継承は1554年。','honganji'),
 '筒井城': ('筒井順昭','scenario_direct','既存設定の筒井家当主に本拠の統治を設定。',None),
 '川越城': ('北条綱成','scenario_appointment','北条家領と包囲側の上杉家を区別。守備担当は北条家武将からゲーム任命。','kawagoe'),
 '日野城': ('蒲生定秀','scenario_appointment','六角家所属の既存武将から任命。郡全域の領有確定ではない。',None),
 '高屋城': ('遊佐長教','scenario_appointment','畠山家所属を維持し守護代を統治担当に設定。家督諸説は別記。','kawachi'),
}

FUTURE = {
 '安土城': (1576,'azuchi'), '坂本城': (1571,'sakamoto'),
 '鹿児島・内城': (1550,'uchi'), '臼杵': (1562,'usuki'), '長崎': (1571,'nagasaki'),
 '海津城': (1560,'kaizu'), '長浜城': (1574,'nagahama'), '三原城': (1567,'mihara'),
 '新高山城': (1552,'shintakayama'), '有子山城': (1574,'arikoyama'), '宮津城': (1580,'miyazu'),
 '新城城': (1576,'shinshiro'), '三枚橋城': (1579,'sanmaibashi'), '郡上八幡城': (1559,'gujo'),
}

ALIASES_1546 = {'岐阜城':'稲葉山城（現表示：岐阜城）','浜松城':'引間城周辺（現表示：浜松城）','金沢城':'金沢御堂予定地（年内創建・月日未詳）','福知山城':'横山城（現表示：福知山城）'}

SEATS = set('府内・大友館|吉田郡山城|岡豊城|岐阜城|甲府・古府中付近|小田原|春日山城|黒川城|三戸城|勝山館|二本松城|山形城|檜山城|小田城|太田城|結城城|古河城|深志城|木曽福島|桜洞城|岡崎城|筒井城|月山富田城|三沢城|高田城|七尾城|三本松城|日野山城|湯築城|十河城|天霧城|中村|日野江城|都於郡城|都城|人吉城・中世城域|黒井城'.split('|'))

SITE_RESEARCH = {'志布志':'shibushi','勝尾':'katsunoo','水戸城':'mito','真壁城':'makabe','谷村城':'yamura','矢筈城':'yahazu','白地城':'hakuchi','神辺城':'kannabe','福知山城':'yokoyama','苗木城':'naegi','神戸城':'kanbe'}
