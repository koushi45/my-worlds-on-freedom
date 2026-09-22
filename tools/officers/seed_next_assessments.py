"""Append a second editorial cohort without replacing earlier assessments."""
import json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
KEYS=['command','tactics','strategy','politics','trust']
SOURCES={
 'b2_takeda':('長野市・武田方の人物解説（軍記・創作との区別が必要）','https://kawanakajima.nagano.jp/character/category/co-takeda/'),
 'b2_takeda_lords':('長野市・武田家関連の人物解説','https://kawanakajima.nagano.jp/character/category/takeda/'),
 'b2_kofu':('甲府市・武田三代のまちづくり','https://www.city.kofu.yamanashi.jp/kids/ima/bunka/takeda.html'),
 'b2_sanada':('長野市・真田幸隆','https://kawanakajima.nagano.jp/character/sanada-yukitaka/'),
 'b2_nobutsuna':('上田市観光協会・真田三代の郷','https://ueda-kanko.or.jp/special/sanada/'),
 'b2_kansuke':('山梨県・市河家文書（武田晴信書状）','https://www.pref.yamanashi.jp/bunka/bunkazaihogo/bunkazai_data/yamanashinobunkazai_wc0056.html'),
 'b2_nagano':('高崎市・長野氏と箕輪城の歴史解説','https://www.city.takasaki.gunma.jp/uploaded/attachment/5986.pdf'),
 'b2_murakami':('長野市・村上義清','https://kawanakajima.nagano.jp/character/murakami-yoshikiyo/'),
 'b2_hojo':('小田原市・北条氏ゆかりの人物と地域','https://www.city.odawara.kanagawa.jp/global-image/units/486242/1-20210610155430.pdf'),
 'b2_genan':('神奈川県立歴史博物館・北条幻庵覚書ほか','https://ch.kanagawa-museum.jp/souun-ji/plus.html'),
 'b2_uesugi':('長野市・上杉方の人物解説（軍記・創作との区別が必要）','https://kawanakajima.nagano.jp/character/category/co-uesugi/'),
 'b2_norimasa':('長野市・上杉家関連の人物解説','https://kawanakajima.nagano.jp/character/category/uesugi/'),
 'b2_honjo':('福島市・福島城の変遷','https://www.city.fukushima.fukushima.jp/bunka-kyodo/fureai/rekishi/kinse/fureai03-13.html'),
 'b2_amago':('島根県・尼子氏関連年表','https://www3.pref.shimane.jp/houdou/uploads/162123/143734/6160855564c6a458f2715dd5f217917c.pdf'),
 'b2_yamanaka':('安来市・布部山の戦いから450年','https://www.city.yasugi.shimane.jp/shisei/koho/kouhou/dogenakane/r01/r02-4.data/202004_14-15.pdf'),
 'b2_shimizu':('岡山市・清水宗治公自刃の地','https://www.city.okayama.jp/shisei/0000027717.html'),
 'b2_ankokuji':('岡山市・安国寺恵瓊書状への言及','https://www.city.okayama.jp/shisei/0000062968.html'),
 'b2_tadayoshi':('鹿児島県・島津日新斎','https://www.pref.kagoshima.jp/ab23/pr/gaiyou/rekishi/tyuusei/nissinsai.html'),
 'b2_yoshiaki':('大分市・大分の歴史に関わりのある主な人物','https://www.city.oita.oita.jp/o169/rekimachi/documents/1syou.pdf'),
 'b2_ito':('宮崎県立図書館・伊東氏旧領と島津氏の日向支配','https://www2.lib.pref.miyazaki.lg.jp/07_history/040/010/040/44_1.pdf'),
 'b2_omura':('大村市史・長崎開港と領国運営','https://www.city.omura.nagasaki.jp/rekishi/kyoiku/shishi/omurashishi/dai2kan/documents/2-3syou.pdf'),
 'b2_date':('仙台市博物館・伊達家文書と藩主の印章','https://www.city.sendai.jp/museum/tenji/josetsuten/datekemonjo_insho.html'),
 'b2_mogami':('山形県観光情報・最上義光歴史館','https://yamagatakanko.com/attractions/detail_2502.html'),
 'b2_nanbu':('三戸町・三戸城跡の歴史と研究上の留保','https://www.town.sannohe.aomori.jp/soshiki/kyouikuiinkaijimukyoku/3674.html'),
 'b2_ando':('男鹿市・脇本城跡と安東愛季の年表','https://www.city.oga.akita.jp/material/files/group/12/20160407-090547.pdf'),
 'b2_satomi':('館山市・里見義堯の上総経営','https://www.city.tateyama.chiba.jp/satomi/youyaku/4shou/4shou_1/4shou_1min.html'),
 'b2_oda':('つくば市・小田氏治の敗北・奪還と支持','https://www.city.tsukuba.lg.jp/material/files/group/3/20220801NO12-1.pdf'),
 'b2_mori':('大津市・歴史文化／信長の近江支配','https://www.city.otsu.lg.jp/material/files/group/67/rekibun_h_3.pdf'),
 'b2_inaba':('岐阜県・稲葉一鉄の墓と沿革','https://www.pref.gifu.lg.jp/page/7097.html'),
 'b2_morinari':('岐阜県・安東伊賀守守就戦死の地','https://www.pref.gifu.lg.jp/page/6937.html'),
 'b2_shogun':('滋賀県・足利将軍と近江','https://www.pref.shiga.lg.jp/file/attachment/4035616.pdf'),
 'b2_sogo':('高松市・十河城跡','https://www.city.takamatsu.kagawa.jp/smph/kurashi/kosodate/bunka/bunkazai/shiteibunkazai/shiseki/sogojo.html'),
 'b2_honganji':('福岡市博物館・九州真宗の源流展出品リスト','https://museum.city.fukuoka.jp/archives/exhibition/2024/kyushu-shinshu-genryuten/pdf/list.pdf'),
 'b2_rairen':('大谷大学博物館・飛騨真宗の伝流（天正8年下間頼廉書状）','https://www.otani.ac.jp/kyo_kikan/museum/nab3mq000005yqot-att/nab3mq000005yqus.pdf'),
 'b2_araki':('伊丹市・有岡城で織田信長と戦った','https://www.city.itami.lg.jp/mirai/asobu/MURASHIGE/column/48684.html'),
 'b2_horio':('松江市・松江市史史料編の紹介','https://www.city.matsue.lg.jp/kanko_bunka_sports/rekishi_bunkazai/matsueshishi/shishi/8642.html'),
 'b2_mashita':('慶應義塾・増田長盛筆書状','https://objecthub.keio.ac.jp/ja/object/451'),
 'b2_tokugawa':('岡崎市観光協会・徳川十六将（伝承を含む）','https://okazaki-kanko.jp/okazaki-park/feature/history/tokugawa16syo')
}
SOURCES.update({
 'b2_suzuki':('和歌山市・雑賀孫一／鈴木重秀','https://www.city.wakayama.wakayama.jp/shisei/wakayama/1001005/1001031/1001032.html'),
 'b2_anayama':('静岡市歴史博物館・穴山信君書状（1572年11月7日）','https://www.city.shizuoka.lg.jp/documents/55417/20250306002.pdf'),
 'b2_harumune':('仙台市博物館・晴宗公采地下賜録の展示記録','https://www.city.sendai.jp/museum/shisetsuannai/documents/vol38-39.pdf'),
 'b2_makishima':('宇治市・槇島城発掘調査概報／1573年の籠城と落城','https://www.city.uji.kyoto.jp/uploaded/attachment/11635.pdf')
})
# A achievement; M successes and failures; P participation without conspicuous error;
# N no individual evidence in the consulted material; F only failure in this dimension.
ROWS='''武田勝頼|b2_takeda_lords,b2_kofu|高天神城攻略と長篠敗戦、武田領国の維持・崩壊を分けて参照。|M:23:広域軍の運用と敗戦後の維持を評価し末期の崩壊を減点;M:26:高天神城攻略の成功を長篠敗戦だけで消さない;M:13:対外関係の維持と同盟崩壊を比較;P:17:甲府を軸とする領国政務を担った責任を標準遂行として評価;M:9:家臣団の継続運用と末期の有力者離反の両面
武田信虎|b2_takeda_lords,b2_kofu|甲斐統合、甲府の都市基盤と追放を参照。|A:25:甲斐の抗争を収束し軍勢を統合;A:24:領国形成過程の軍事的成功;M:20:領国拡張と家中での失脚の両面;A:25:躑躅ヶ崎への移転と甲府の基盤形成;M:8:家臣団を組織した実績は残し追放による支持喪失を減点
武田信繁|b2_takeda|武田一門の軍事指揮と川中島への参加を参照。後世の名将像をそのまま能力にしない。|P:20:武田中枢の部隊を率いる重要任務を標準的に遂行したと解釈;P:18:川中島の主力部隊での参加を評価し戦死を自動的な失策としない;N:12:独立した外交・戦略の成果と失策は今回未確認;P:16:一門の重臣として家政に携わる責任を評価;P:17:直属部隊をまとめた任務を評価し主君への忠義と分ける
山県昌景|b2_takeda|武田軍の有力部隊と方面任務を参照。赤備えの名声だけで加点しない。|A:26:継続した部隊指揮と方面任務;A:28:前線で直接率いた部隊の戦果;P:18:重要戦域での作戦分担を標準遂行と解釈;P:16:方面の支配・軍政に携わる任務を評価;P:18:主要部隊の継続運用を評価し個別の登用成果は推定しない
馬場信春|b2_takeda|深志の城将、葛山城攻略などを参照。無傷伝説は採点しない。|A:26:北信濃の拠点と部隊を継続運用;A:27:葛山城攻略などの戦術成果;A:23:城の配置を含む地域作戦への寄与;P:17:重要拠点の城将としての管理任務を評価;P:18:部隊を維持して指揮した責任を標準遂行と解釈
内藤昌豊|b2_takeda|武田重臣としての軍事・上野方面の任務を参照。昌秀・昌豊の名乗りの扱いは原台帳を保持。|P:21:主要戦線で部隊を運用する責任を評価;P:19:主力戦役への継続参加を標準遂行と解釈;P:18:上野方面の作戦分担を評価;P:19:重要方面での支配実務への参加を評価;P:17:方面の部隊運用を評価し離反不在だけで最高点にはしない
高坂昌信|b2_takeda|春日虎綱としての海津城・北信濃での役割を参照。逃げ弾正などの称号は数値化しない。|A:25:海津城を軸に重要方面を維持;P:20:上杉と接する主力戦域の部隊指揮を標準遂行と解釈;A:24:北信濃の防備と対外調整;P:19:国境方面の軍政・支配任務を評価;P:18:重要拠点の軍団維持を標準遂行と解釈
秋山信友|b2_takeda|伊那・東美濃方面への出兵と岩村城での役割を参照。信友・虎繁の呼称は別名として扱う。|A:23:伊那から東美濃にわたる部隊運用;M:23:岩村の掌握と落城の両面;M:19:拠点獲得を評価し最終的な孤立を減点;P:16:方面の城将としての支配参加を評価;P:16:方面部隊を率いる任務を標準遂行と解釈
飯富虎昌|b2_takeda|武田の重臣・部隊指揮と義信事件への関与を参照。事件の細部は留保。|P:20:有力部隊の編成・運用を担った責任を評価;P:19:主要戦役への部隊参加を標準遂行と解釈;M:9:重臣としての政治参加を残し義信事件での失脚を減点;P:16:重臣としての家政参加を評価;P:17:部隊の運用を評価し本人の謀反を部下の人望と混同しない
山本勘助|b2_kansuke|市河家文書は山本菅助の実在と武田方の伝達役を支える。啄木鳥戦法や万能軍師像は根拠にしない。|N:12:大軍の独立指揮は今回の史料では確認できない;N:12:個別の戦術的成功・失策は軍記から確証できない;P:15:信濃戦域の使者・情報伝達任務を標準的に遂行したと解釈;N:12:独自の政策実施と失策の記録は今回未確認;N:12:家臣の登用・定着を測る記録は今回未確認
真田幸隆|b2_sanada|信濃での本領回復と城の攻略を参照。昌幸・信繁の後世の業績を混ぜない。|A:23:信濃での部隊編成と拠点回復;A:24:尼巌城などの攻略;A:27:在地関係を生かした攻略と勢力回復;P:16:回復した本領の支配任務を標準遂行と解釈;P:17:家臣を率いた地域軍事の継続を評価
真田信綱|b2_nobutsuna|武田軍への従軍と長篠での戦死を参照。所属軍の敗北を本人の失策に直結させない。|P:17:武田の主要戦役に部隊を率いて参加した責任を評価;P:17:長篠戦域の前線参加を標準遂行と解釈;N:12:独立した戦略・外交の成否は今回未確認;P:14:短期間の家督・領地運営を標準遂行と解釈;P:15:直属部隊をまとめる任務を評価
小山田信茂|b2_takeda|郡内の領主として武田の軍事に参加。終局の対応は伝承と確実な記録を分ける。|P:20:郡内衆を率いる地域軍事の重要性を評価;P:18:武田の主要戦域への参加を標準遂行と解釈;M:8:軍事参加の実績を残し1582年の家の存続失敗を減点;P:18:交通上重要な郡内領の統治任務を標準遂行と解釈;P:16:郡内の部隊運用を評価し主君への離反を人望と直結させない
穴山信君|b2_takeda,b2_anayama|河内領と駿河方面の軍事・政務、三浦元政の帰属を促した書状を参照。徳川への帰属変更は忠義ではなく戦略として扱う。|P:20:武田一門の軍勢と方面任務を評価;P:18:駿河など重要戦線への参加を標準遂行と解釈;M:18:勢力転換による領地確保と直後の死去による限界;P:19:河内と方面拠点の支配実務を評価;A:22:三浦元政を招き武田方へ従属させた人材獲得・活用
長野業正|b2_nagano|箕輪城主・長野氏の支配と家臣の活動を参照。武田軍を何度も単独撃退したという軍記の細部は留保。|P:20:西上野の城と軍勢を統括する重要性を評価;P:18:西上野防衛への参加を標準遂行と解釈;P:17:地域勢力の連携任務を標準遂行と解釈;P:17:箕輪を中心とする在地統治を評価;P:17:家臣をまとめて地域防備を担った責任を評価
村上義清|b2_murakami|武田との戦いでの勝利、葛尾退去と上杉への援助要請を参照。|M:23:信濃の軍勢運用と本領喪失の両面;A:27:上田原などで武田軍を退けた成果;M:19:越後との連携を評価し本拠維持の失敗を減点;P:16:北信濃の在地支配を標準遂行と解釈;P:17:地域部隊を率いる任務を評価
北条綱成|b2_hojo|河越城防衛と北条方の部隊指揮を参照。伝説的な兵数は採点しない。|A:25:重要城の守備と主力部隊運用;A:28:河越防衛など直接の戦術成果;P:18:関東の重要戦域で作戦を分担;P:16:城将としての領地・軍政参加を評価;P:18:主要守備部隊を維持した任務を評価
北条幻庵|b2_genan|北条幻庵覚書と公方家との取次を参照。文化人としての人気は人望点にしない。|P:16:一門として地域の軍事組織に参加する責任を評価;N:12:直接指揮での戦術成果・失策は今回未確認;A:23:公方家などとの交渉・取次;A:22:故実と家政の調整を文書から評価;P:17:一族の後見と組織調整を標準遂行と解釈
北条氏照|b2_hojo|関東方面の軍事・拠点支配と1590年の処分を参照。|A:25:関東の方面軍と城郭網の運用;P:21:重要方面での継続した部隊指揮を評価;M:18:方面戦略の成果を残し対豊臣の終局を減点;A:22:八王子など支配拠点の整備;P:18:方面の家臣・国衆の運用を標準遂行と解釈
上杉憲政|b2_norimasa|北条に敗れて越後へ移り管領職・家名を景虎へ継承した経過を参照。|M:10:関東勢力の動員を評価し統制・領国喪失を減点;F:5:今回確認した直接戦闘の記述は敗北・退去で成功の裏付けなし;M:13:領国維持の失敗と越後への継承・連携の両面;P:16:関東管領としての政務参加を標準遂行と解釈;N:12:本人の部下登用・定着を独立に測る材料は今回未確認
宇佐美定満|b2_uesugi|実在の定満と、軍記上の名軍師・宇佐美定行を区別する。|P:16:越後の在地勢力として軍事に関わる規模を評価;N:12:軍記上の定行の戦果を定満へ移さない;N:12:軍師伝説を除く独立戦略の成否は今回未確認;P:15:在地領主としての支配参加を標準遂行と解釈;N:12:家臣の登用・定着は今回未確認
直江景綱|b2_uesugi|謙信期の奉行・軍事担当を参照。兼続の業績を移さない。|P:20:上杉の重要戦域での軍事担当を評価;P:18:主力戦役への参加を標準遂行と解釈;A:23:取次・交渉を通じ政権を補佐;A:24:奉行として政務を担う実績;P:17:政務・軍事の組織運用を標準遂行と解釈
柿崎景家|b2_uesugi|上杉の部隊指揮と家中での役割を参照。誅殺説など異説だけで人望を下げない。|P:21:主力部隊を率いる重要任務を評価;A:26:前線の戦闘指揮に関する実績を評価し軍記の誇張は除く;P:17:関東・信濃戦域での作戦分担を評価;P:16:領地と家中政務への参加を標準遂行と解釈;P:17:部隊を継続してまとめる責任を評価
本庄繁長|b2_honjo|福島城代としての防備と城下整備を参照。自らの反乱と部下からの人望を分ける。|A:24:上杉の国境拠点で軍勢を運用;A:26:福島方面の防衛を評価;M:19:政局への復帰と対外調整を評価し反乱の失敗も考慮;A:21:福島城下の防備整備;P:17:国境の部隊維持を標準遂行と解釈
尼子義久|b2_amago|月山富田城の抗戦と1566年の降伏を参照。家中粛清の逸話だけで点を付けない。|M:13:抗戦を継続した運用を残し領国喪失を減点;P:16:月山富田城の守備を担った任務を評価し落城を個人の全戦術の失敗としない;F:5:今回の対外戦略の参照記録は包囲・降伏に至る失敗で対抗成功は未確認;P:15:当主としての領国政務参加を標準遂行と解釈;N:12:部下の登用・定着について確かな個別材料は今回未確認
山中幸盛|b2_yamanaka,b2_amago|尼子再興軍の編成・出雲進攻と敗北を参照。七難八苦などの物語は採点しない。|A:23:再興のため離散した戦力を集めて運用;M:24:出雲進攻の成果と布部山などでの敗北;M:19:支援獲得と再興失敗の両面;N:12:独自の継続的な行政成績は今回未確認;A:22:旧臣などを集め軍事組織を再建した成果
清水宗治|b2_shimizu|備中高松城の守備と城兵を救う和睦条件を参照。主君への忠義は人望点の根拠にしない。|A:22:要衝の守備部隊を維持;P:19:中国戦線の重要城での防衛任務を評価;A:19:城兵救済を含む和睦への対応;P:15:城主としての地域管理を標準遂行と解釈;A:22:城兵の救済を伴う組織への配慮を評価
安国寺恵瓊|b2_ankokuji|毛利側の外交僧としての書状・交渉活動を参照。将来を予言したという像では評価しない。|P:16:豊臣期の軍事動員への参加を標準遂行と解釈;P:15:広域遠征への参加を評価し個別戦果は加えない;M:26:継続した外交・折衝を評価し関ヶ原での選択も考慮;P:18:僧・領主としての政務参加の責任を評価;N:12:直属の部下の登用・定着は今回未確認
島津忠良|b2_tadayoshi|島津家の内紛収拾と貴久の権力確立への関与を参照。|A:24:分裂した一族の軍事を統合;A:22:支配確立過程の戦闘成果;A:25:一族関係を調整して支配基盤を確立;A:24:領国形成と教育・規範の整備;A:24:一族・家臣団をまとめた組織形成
大友義鑑|b2_yoshiaki|肥後などへの介入と領国支配、二階崩れを参照。事件の動機の細部には異説がある。|A:23:複数地域の軍事に介入する動員;P:19:北部九州の重要戦域での軍事参加を評価;M:19:勢力拡大と継承対立による失敗;A:23:大友領国支配の基盤強化;F:5:今回の家臣支持に関する具体的記録は重臣の襲撃による破綻で登用成功は未確認
伊東義祐|b2_ito|日向での領国支配、家臣の離反と退去、旧臣の再起への協力を参照。|M:19:日向の軍勢運用と崩壊の両面;M:17:勢力拡張と島津との抗争の敗北;M:11:支援要請を評価し領国回復失敗を減点;P:17:広い日向領の政務を担った責任を標準遂行と解釈;M:9:離反による崩壊を減点し協力を続けた旧臣の存在も残す
大村純忠|b2_omura|長崎開港・町割奉行の配置と周辺勢力への対応を参照。|M:18:地域軍事を維持した実績と他勢力への従属;P:17:肥前の防衛任務を標準遂行と解釈;A:25:海外勢力との交渉と通商経路の確保;A:25:長崎開港と町割の実施;M:18:町割奉行などの人材活用と家中・地域の対立
伊達晴宗|b2_date,b2_harumune|天文の乱後の伊達当主としての支配と家中秩序を参照。|M:22:家中抗争を経て軍事組織を維持;P:18:南奥羽の戦域を担う軍事参加を評価;M:20:家督確立と一族間対立の負担;A:22:知行秩序の再編を評価;M:18:家臣の支持獲得と内紛による分裂の両面
伊達輝宗|b2_date|蘆名盛氏からの起請文など、南奥羽の交渉関係を参照。最期の拉致・死去だけで全項目を下げない。|P:20:南奥羽の有力勢力の軍事運用を評価;P:17:周辺戦域での軍事参加を標準遂行と解釈;A:22:蘆名など周辺勢力との外交関係を維持;P:19:広域領国の当主として政務を標準遂行;P:18:家臣団の継続運用を標準遂行と解釈
最上義光|b2_mogami|長谷堂合戦と山形の領国形成・都市整備を参照。|A:26:出羽の軍勢を拡張し重要方面を運用;A:25:長谷堂合戦などの防衛成果;A:26:他勢力との交渉と領国拡張;A:27:城下と流通基盤の整備;M:21:地域勢力の活用を評価し継承期の家中問題も考慮
蘆名盛氏|b2_date|伊達輝宗への起請文など対外関係と会津の領国運営を参照。|A:24:会津を軸に地域軍を運用し勢力拡張;P:20:南奥羽の重要戦線での指揮を標準遂行と解釈;A:24:周辺大名との盟約・利害調整;P:20:会津の広域支配を担った責任を評価;P:18:領国の家臣・地域勢力の運用を標準遂行と解釈
南部晴政|b2_nanbu|南部氏の拠点形成と幕府との関係を参照。七郡支配を晴政個人の確定領土にしない。|P:21:北奥羽の地域軍を統括する重要性を評価;P:18:地域の戦争・防衛への参加を標準遂行と解釈;P:18:幕府や周辺勢力との関係維持を評価;P:19:三戸を中心とする支配・拠点運営の責任を評価;N:12:家臣放火説など後世の異説を除く個別の定着・離反材料は今回未確認
安東愛季|b2_ando|湊安東氏との統合と脇本城などの拠点を参照。|A:23:複数の安東勢力をまとめ地域軍を運用;P:19:北出羽の戦域での軍事参加を評価;A:24:一族の統合と周辺勢力との関係構築;A:23:脇本城を軸とする支配基盤の形成;M:17:一族の統合を評価し支配内部の対立も考慮
里見義堯|b2_satomi|上総の本拠と東京湾をめぐる北条との抗争を参照。|A:24:房総の軍勢と拠点を運用;M:23:地域での戦果と対北条の敗北の両面;A:24:上総進出と他勢力との対抗関係;A:22:上総支配の拠点形成;P:18:房総の国衆を伴う軍事・支配を標準遂行と解釈
小田氏治|b2_oda|反復した敗戦と居城奪還、支えた家臣を参照。戦国最弱という俗称では査定しない。|M:12:軍の再建と反復した敗北を比較;M:8:敗戦が多いが奪還成功があるため失敗のみの5点にはしない;M:9:勢力維持の失敗と再起の成功の両面;P:16:常陸南部の領主として政務を担った役割を評価;A:24:敗戦後も再起を支えた家臣の維持を評価
森可成|b2_mori|宇佐山城を任され、京都と大津の交通路を守る任務を参照。|P:21:京への交通路を守る重要部隊の指揮を評価;P:20:近江の重要戦域での前線参加を標準遂行と解釈;P:17:京都防衛に関わる地域作戦を分担;P:16:城将としての要地管理を標準遂行と解釈;P:17:直属部隊をまとめる責任を評価
稲葉一鉄|b2_inaba,b2_morinari|西美濃三人衆としての支配と安藤氏旧領の獲得を参照。|A:23:美濃の軍事勢力を継続運用;A:23:地域抗争と領地確保での成果;A:22:政権交代を経た勢力維持;P:18:美濃の領地経営を標準遂行と解釈;P:17:地域の家臣団を維持した任務を評価
氏家卜全|b2_inaba|西美濃三人衆としての地位と織田軍への参加を参照。戦死や子の行動を本人の失策としない。|P:19:西美濃の軍勢を率いる責任を評価;P:18:織田軍の重要戦域への参加を標準遂行と解釈;P:16:美濃勢力の連携・帰属変更への参加を評価;P:17:西美濃での領地運営を標準遂行と解釈;P:16:地域部隊をまとめる任務を標準遂行と解釈
安藤守就|b2_morinari|西美濃での支配、追放と旧領回復の失敗を参照。|M:18:長期の軍勢運用を残し本能寺後の敗死を減点;M:17:従軍の実績と旧領回復戦の失敗;M:10:政権交代への対応と終局の勢力喪失;P:17:北方を軸とする領地運営を標準遂行と解釈;P:16:直属部隊の運用を評価し追放を部下の離反とみなさない
平手政秀|genpuku|信長の守役としての役割を参照。諫死の動機や外交の細部は別途照合が必要。|N:12:大軍指揮の個別成否は今回未確認;N:12:直接率いた部隊の戦果・失策は今回未確認;P:16:織田家の補佐・調整役を標準遂行と解釈;P:17:家政・後継者補佐という重要任務を評価;N:12:本人の忠誠から部下の支持を推定しない
足利義輝|b2_shogun|将軍としての交渉と京都への復帰を参照。最期の剣豪伝説は部隊戦術の点数にしない。|P:17:幕府の軍事行動に関わる責任を評価;N:12:個人剣技の伝説を除く直属部隊の戦術成果は今回未確認;A:24:諸大名との関係調整と政権復帰;P:19:中央政権の政務を担う重要性を評価;N:12:直属家臣の登用・定着を独立に測る材料は今回未確認
足利義昭|b2_shogun,b2_makishima|織田勢力による上洛と追放後の大名間連携を参照。将軍職の権威と本人の実績を分ける。|M:12:軍事的な動員と京都防衛の失敗;F:5:今回の直接戦闘の参照範囲では籠城敗北で戦術成功の裏付けなし;M:24:広域外交・上洛の実現と政権維持の失敗;P:19:幕府の政務参加を重要任務の標準遂行と解釈;M:10:近臣の支持を保つ一方で政治軍事基盤を維持できなかった
六角定頼|b2_shogun|近江で将軍を支えた有力大名としての軍事・政治的役割を参照。|A:25:南近江の軍勢をまとめ畿内へ展開;P:21:畿内の主要戦域での軍事参加を評価;A:26:将軍の保護・復帰を通じ政治的影響力を形成;P:21:南近江の支配と仮幕府を支える実務を標準遂行と解釈;P:19:領国と将軍周辺の組織調整を標準遂行と解釈
十河一存|b2_sogo|三好家から十河家を継ぎ讃岐の有力勢力を率いた役割を参照。鬼十河という異名は採点しない。|P:21:讃岐の軍勢を率いる責任を評価;P:20:三好方の重要戦域での軍事参加を標準遂行と解釈;P:17:四国と畿内の作戦連携を分担;P:16:讃岐の領地支配を標準遂行と解釈;P:17:養子先の軍事組織を率いた役割を評価
本願寺顕如|b2_honganji|宗主の文書と本願寺の抵抗・移転を参照。門徒の動員と本人の直接戦闘を分ける。|A:26:諸地域の寺院・門徒を通じて継戦組織を運用;P:17:石山の防衛に関わる重要任務を評価し現場指揮官の戦果は移さない;A:26:他勢力との連携と和睦;A:24:寺院組織と移転後の再建を運営;M:23:門徒・坊官を長期に活用したが退去方針で分裂も生じた
鈴木重秀|b2_suzuki|雑賀の軍事集団と石山戦線への参加を参照。孫一の名を用いた複数人物の業績を混ぜない。|P:21:雑賀の部隊を率いる重要性を評価;P:21:石山という中央の重要戦域での前線任務を標準遂行と解釈;P:17:紀伊・石山間の軍事連携を分担;N:12:独自の政策成果・失策は今回未確認;P:17:軍事集団を率いる役割を評価し雑賀全体の支持を仮定しない
下間頼廉|b2_rairen,b2_honganji|天正8年・文禄2年の書状など坊官の実務と軍事関与を参照。|P:22:本願寺中枢で重要戦線の運用を担う責任を評価;P:19:石山の防衛参加を標準遂行と解釈;P:20:本山と地方寺院の連絡・調整を担う重要性を評価;A:23:書状を通じた寺院組織の政務;P:18:坊官として組織を運用する任務を標準遂行と解釈
荒木村重|b2_araki|摂津支配と有岡城での抗戦、家臣の離反と処刑に至る経過を参照。|M:21:摂津の軍事組織形成を残し最終的崩壊を減点;M:20:抗戦の維持と敗北を比較;M:10:支配確立と反織田戦略の失敗;A:22:有岡を中心とする支配拠点の形成;M:7:部下を組織した実績と離反・家臣団喪失の重い失敗
中川清秀|b2_araki|摂津の城主としての軍事、村重から信長への帰属変更を参照。|P:20:摂津の部隊を率いる責任を評価;P:21:畿内の主要戦域での前線参加を標準遂行と解釈;M:18:帰属変更で勢力を維持した成果と短い継続期間;P:16:茨木の領地・城の運営を標準遂行と解釈;P:17:直属部隊を維持する任務を評価
堀尾吉晴|b2_horio|出雲・松江の城と城下形成を参照。忠氏・忠晴の寄与を全て吉晴に移さない。|P:22:豊臣の広域戦役で部隊を運用する責任を評価;P:20:主要戦域への継続参加を標準遂行と解釈;A:22:政権交代期の対応と家の支配基盤維持;A:26:松江の城下形成を主導;P:18:転封先での家臣・実務組織を標準的に運用したと解釈
増田長盛|b2_mashita|書状と豊臣政務への参加を参照。政治実務と関ヶ原前後の進退を別項目で扱う。|P:17:広域政権の動員・後方任務を標準遂行と解釈;N:12:直属部隊の突出した戦術成果・失策は今回未確認;M:10:中央での調整役と関ヶ原前後の進退失敗;A:25:豊臣政権の奉行として政務を継続;N:12:個別の部下登用・定着の材料は今回未確認
前田玄以|b2_mashita|豊臣政権の奉行としての政務参加を参照。文官的役割だけを理由に軍事を5点にしない。|N:12:大軍の独立指揮の個別成否は今回未確認;N:12:直接戦術の成功・失敗は今回未確認;P:20:中央政権の政治調整を重要任務の標準遂行と解釈;P:22:豊臣政権の中枢政務を継続して担った責任を評価;N:12:部下の登用・定着に関する個別成否は今回未確認
鳥居元忠|b2_tokugawa|甲斐での戦果・郡代と伏見城防衛を参照。主君への忠義そのものを人望に加点しない。|A:24:領国と重要拠点で部隊を運用;A:26:甲斐での戦果と伏見の防衛継続;P:18:徳川方の重要作戦を分担した責任を評価;P:18:郡代としての地域統治を標準遂行と解釈;A:21:厳しい防衛局面で部隊をまとめた実績
大久保忠世|b2_tokugawa|徳川軍への継続参加と小田原での領地運営を参照。三方原後の夜襲伝承の細部は留保。|P:22:主要戦線で部隊を継続指揮する責任を評価;P:21:重要戦役の前線参加を標準遂行と解釈;P:18:戦域の連携・方面任務を標準遂行と解釈;P:18:小田原の城・領地運営を担う重要性を評価;A:20:一向一揆時に一族を集め組織を維持した成果
服部正成|b2_tokugawa|徳川家の軍事奉公と伊賀者の運用を参照。忍術・超人的戦闘は採点根拠にしない。|P:19:特殊な出自の部隊を運用する責任を評価;P:18:徳川の重要戦域での軍事参加を標準遂行と解釈;P:18:移動・警護・連絡の重要任務を標準遂行と解釈;N:12:独自の政策実施と失策は今回未確認;P:18:伊賀者を率いる任務を評価し後継者の失敗は移さない'''
TYPES={'A':'achievement','M':'mixed','P':'participation_standard','N':'no_record','F':'failure_only'}
def main():
    master=ROOT/'data/master/officers'
    path=master/'assessments.json';assessments=json.loads(path.read_text(encoding='utf-8'))
    roster=json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))['officers']
    by_name={r['display_name']:r for r in roster}
    for r in roster:
        for alias in r['aliases']:by_name.setdefault(alias,r)
    sources=json.loads((master/'sources.json').read_text(encoding='utf-8'));source_map={s['id']:s for s in sources}
    for key,(title,url) in SOURCES.items():source_map[key]={'id':key,'title':title,'url':url,'accessed':'2026-09-12','use':'参照リンクと短い要約。ゲーム評価は編集上の解釈であり、本文・画像を転載しない。'}
    before={q:a for q,a in assessments.items() if a.get('cohort')=='major_60'}
    selection_path=master/'next_60_selection.json'
    if selection_path.exists():
        original_hash=json.loads(selection_path.read_text(encoding='utf-8'))['original_major_60_sha256']
        if hashlib.sha256(json.dumps(before,ensure_ascii=False,sort_keys=True).encode()).hexdigest()!=original_hash:
            raise ValueError('The earlier 60 changed; reconcile the cohort baseline explicitly before regenerating this seed.')
    selected=[]
    for line in ROWS.splitlines():
        name,refs,evidence,items=line.split('|');r=by_name[name];q=r['external_id']
        if q in assessments and assessments[q].get('cohort')!='next_60':raise ValueError('Already assessed: '+name)
        scores={};reasons={};basis={};confidence={}
        for key,item in zip(KEYS,items.split(';'),strict=True):
            kind,value,reason=item.split(':',2);scores[key]=int(value);reasons[key]=reason;basis[key]=TYPES[kind];confidence[key]='limited_evidence' if kind in 'PNF' else 'editorial_estimate'
        assessments[q]={'status':'editorial_draft','cohort':'next_60','basis':'lifetime','scores':scores,'source_refs':refs.split(','),'evidence':evidence,'score_reasons':reasons,'score_basis':basis,'score_confidence':confidence,'confidence':'provisional','score_policy':'participation_standard_v2','caveat':'史料の参照範囲に基づくゲーム上の解釈。参加が確認でき目立つ失策がない任務は標準遂行とみなす。記録なしは調査範囲での未確認であり、実績不存在の断定ではない。失敗のみも項目単位・参照範囲で判定し、敗死だけで全能力を下げない。','score_method':'生涯評価・1〜30点・1点刻み。個別の成否不明は12前後、失敗のみは5前後。参加のみは規模・戦域の重要性・責任に応じ14〜22。確認した成果・失敗は別途加減。'}
        selected.append({'external_id':q,'display_name':name})
    assert len(selected)==60 and len({r['external_id'] for r in selected})==60
    assert before=={q:a for q,a in assessments.items() if a.get('cohort')=='major_60'}
    for filename,value in [('assessments.json',assessments),('sources.json',list(source_map.values())),('next_60_selection.json',{'selection':'元の1,271人の未評価者から、歴史上の役割と一般的な認知を基に編集選定。統計的知名度順位ではない。新規未誕生者は今回の60人に含めない。','original_major_60_sha256':hashlib.sha256(json.dumps(before,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),'officers':selected})]:
        (master/filename).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Appended',len(selected),'officers; assessed total',len(assessments))
if __name__=='__main__':main()
