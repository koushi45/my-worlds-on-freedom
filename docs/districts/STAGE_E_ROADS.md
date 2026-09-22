# 工程E・推定連絡路の通過順

元の点列順（from_site → to_site）で記録。未確定・表示区画外も省略しない。郡の再訪は順序に残す。道路の出入口は城の郡所属の代わりに使わない。区画名の前は親領域ID。

|路線|通過区画の順序|境界イベント|派生データ|
|---|---|---:|---|
|`link_001` 佐土原城―穆佐城|hyuga:児湯郡 → hyuga:北那珂郡 → hyuga:東諸県郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_001.json)|
|`link_002` 穆佐城―清武城|hyuga:東諸県郡 → hyuga:宮崎郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_002.json)|
|`link_003` 清武城―飫肥城|hyuga:宮崎郡 → hyuga:北那珂郡 → hyuga:南那珂郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_003.json)|
|`link_004` 飫肥城―志布志|hyuga:南那珂郡 → osumi:未確定|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_004.json)|
|`link_005` 穆佐城―都城|hyuga:東諸県郡 → hyuga:北諸県郡 → osumi:未確定|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_005.json)|
|`link_006` 都城―加治木の港域付近|osumi:未確定 → osumi:東囎唹郡 → osumi:西囎唹郡 → osumi:未確定 → osumi:西囎唹郡 → osumi:姶良郡 → satsuma:未確定|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_006.json)|
|`link_007` 加治木の港域付近―鹿児島・内城|satsuma:未確定 → satsuma:鹿児島郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_007.json)|
|`link_008` 都城―飯野城|osumi:未確定 → hyuga:北諸県郡 → hyuga:西諸県郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_008.json)|
|`link_009` 飯野城―加久藤城|hyuga:西諸県郡 → higo:未確定|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_009.json)|
|`link_010` 加久藤城―人吉城・中世城域|higo:未確定 → higo:球摩郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_010.json)|
|`link_011` 鹿児島・内城―知覧城|satsuma:鹿児島郡 → satsuma:谿山郡 → satsuma:未確定 → satsuma:谿山郡 → satsuma:未確定 → satsuma:谿山郡 → satsuma:川邊郡 → satsuma:給黎郡|7|[区間・通過点](../../data/work/districts/stage_e/routes/link_011.json)|
|`link_012` 知覧城―山川付近|satsuma:給黎郡 → satsuma:頴娃郡 → satsuma:揖宿郡 → satsuma:未確定 → satsuma:揖宿郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_012.json)|
|`link_013` 知覧城―坊津付近|satsuma:給黎郡 → satsuma:川邊郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_013.json)|
|`link_014` 鹿児島・内城―阿久根付近|satsuma:鹿児島郡 → satsuma:日置郡 → satsuma:未確定 → satsuma:薩摩郡 → satsuma:高城郡 → satsuma:出水郡 → satsuma:未確定 → satsuma:出水郡 → satsuma:未確定|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_014.json)|
|`link_015` 阿久根付近―古麓城|satsuma:未確定 → satsuma:出水郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:未確定 → higo:葦北郡 → higo:八代郡|26|[区間・通過点](../../data/work/districts/stage_e/routes/link_015.json)|
|`link_016` 古麓城―隈本城|higo:八代郡 → higo:下益城郡 → higo:宇土郡 → higo:下益城郡 → higo:宇土郡 → higo:下益城郡 → higo:宇土郡 → higo:下益城郡 → higo:飽田郡 → higo:託麻郡 → higo:飽田郡|10|[区間・通過点](../../data/work/districts/stage_e/routes/link_016.json)|
|`link_017` 加治木の港域付近―高須付近|satsuma:未確定 → osumi:姶良郡 → osumi:西囎唹郡 → osumi:未確定 → osumi:西囎唹郡 → osumi:東囎唹郡 → osumi:肝属郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_017.json)|
|`link_018` 高須付近―根占付近|osumi:肝属郡 → osumi:南大隅郡 → osumi:未確定 → osumi:南大隅郡 → osumi:未確定 → osumi:南大隅郡 → osumi:未確定 → osumi:南大隅郡 → osumi:未確定 → osumi:南大隅郡 → osumi:未確定 → osumi:南大隅郡 → osumi:未確定|12|[区間・通過点](../../data/work/districts/stage_e/routes/link_018.json)|
|`link_019` 根占付近―内之浦付近|osumi:未確定 → osumi:南大隅郡 → osumi:肝属郡 → osumi:未確定|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_019.json)|
|`link_020` 内之浦付近―志布志|osumi:未確定 → osumi:肝属郡 → osumi:未確定 → osumi:肝属郡 → osumi:未確定|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_020.json)|
|`link_021` 古麓城―人吉城・中世城域|higo:八代郡 → higo:球摩郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_021.json)|
|`link_022` 佐土原城―臼杵|hyuga:児湯郡 → hyuga:未確定 → hyuga:児湯郡 → hyuga:未確定 → hyuga:児湯郡 → hyuga:未確定 → hyuga:児湯郡 → hyuga:未確定 → hyuga:児湯郡 → hyuga:未確定 → hyuga:児湯郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → hyuga:東臼杵郡 → hyuga:未確定 → bungo:大野郡 → bungo:南海部郡 → bungo:大野郡 → bungo:北海部郡|35|[区間・通過点](../../data/work/districts/stage_e/routes/link_022.json)|
|`link_023` 臼杵―府内・大友館|bungo:北海部郡 → bungo:未確定 → bungo:北海部郡 → bungo:大分郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_023.json)|
|`link_024` 府内・大友館―岡城|bungo:大分郡 → bungo:大野郡 → bungo:直入郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_024.json)|
|`link_025` 岡城―隈本城|bungo:直入郡 → higo:未確定 → higo:阿蘇郡 → higo:合志郡 → higo:託麻郡 → higo:飽田郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_025.json)|
|`link_026` 隈本城―柳川城|higo:飽田郡 → higo:山本郡 → higo:玉名郡 → chikugo:未確定 → chikugo:三池郡 → chikugo:山門郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_026.json)|
|`link_027` 柳川城―勝尾|chikugo:山門郡 → chikugo:三瀦郡 → chikugo:未確定 → hizen:三根郡 → hizen:養父郡 → hizen:三根郡 → chikuzen:未確定 + hizen:三根郡（数値接点・通過郡未判定） → chikuzen:未確定|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_027.json)|
|`link_028` 勝尾―博多|chikuzen:未確定 → chikuzen:御笠郡 → chikuzen:那珂郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_028.json)|
|`link_029` 博多―立花城|chikuzen:那珂郡 → chikuzen:粕屋郡 → chikuzen:那珂郡 → chikuzen:粕屋郡 → chikuzen:未確定 → chikuzen:粕屋郡 → chikuzen:未確定 → chikuzen:粕屋郡 → chikuzen:未確定 → chikuzen:粕屋郡|9|[区間・通過点](../../data/work/districts/stage_e/routes/link_029.json)|
|`link_030` 立花城―馬ヶ岳城|chikuzen:粕屋郡 → chikuzen:穂波郡 → chikuzen:嘉麻郡 → chikuzen:未確定 → buzen:田川郡 → buzen:京都郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_030.json)|
|`link_031` 勝尾―古処山城|chikuzen:未確定 → chikuzen:夜須郡 → chikuzen:嘉麻郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_031.json)|
|`link_032` 古処山城―岩石城|chikuzen:嘉麻郡 → buzen:未確定 → buzen:田川郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_032.json)|
|`link_033` 岩石城―馬ヶ岳城|buzen:田川郡 → buzen:仲津郡 → buzen:京都郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_033.json)|
|`link_034` 馬ヶ岳城―府内・大友館|buzen:京都郡 → buzen:仲津郡 → buzen:築城郡 → buzen:上毛郡 → buzen:未確定 → buzen:上毛郡 → buzen:未確定 → buzen:上毛郡 → buzen:未確定 → buzen:上毛郡 → buzen:下毛郡 → buzen:宇佐郡 → buzen:未確定 → bungo:速見郡 → bungo:未確定 → bungo:速見郡 → bungo:未確定 → bungo:速見郡 → bungo:未確定 → bungo:速見郡 → bungo:未確定 → bungo:大分郡|21|[区間・通過点](../../data/work/districts/stage_e/routes/link_034.json)|
|`link_035` 勝尾―村中城|chikuzen:未確定 → chikuzen:未確定 + hizen:三根郡（数値接点・通過郡未判定） → hizen:三根郡 → hizen:神崎郡 → hizen:佐賀郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_035.json)|
|`link_036` 村中城―長崎|hizen:佐賀郡 → hizen:未確定 → hizen:杵島郡 → hizen:未確定 → hizen:藤津郡 → hizen:東彼杵郡 → hizen:北高来郡 → hizen:東彼杵郡 → hizen:未確定 → hizen:東彼杵郡 → hizen:未確定 → hizen:西彼杵郡 → hizen:北高来郡 → hizen:西彼杵郡|13|[区間・通過点](../../data/work/districts/stage_e/routes/link_036.json)|
|`link_037` 長崎―日野江城|hizen:西彼杵郡 → hizen:北高来郡 → hizen:未確定 → hizen:南高来郡 → hizen:未確定 → hizen:南高来郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_037.json)|
|`link_038` 赤間関―山口|nagato:豊浦郡 → nagato:未確定 → nagato:豊浦郡 → nagato:未確定 → nagato:豊浦郡 → nagato:未確定 → nagato:豊浦郡 → nagato:未確定 → nagato:豊浦郡 → nagato:未確定 → nagato:厚狭郡 → nagato:未確定 → suo:吉敷郡|12|[区間・通過点](../../data/work/districts/stage_e/routes/link_038.json)|
|`link_039` 山口―桜尾城|suo:吉敷郡 → suo:佐波郡 → suo:都濃郡 → suo:佐波郡 → suo:都濃郡 → suo:玖珂郡 → suo:未確定 → suo:玖珂郡 → suo:未確定 → suo:玖珂郡 → suo:未確定 → aki:佐伯郡 → aki:未確定 → aki:佐伯郡 → aki:未確定 → aki:佐伯郡 → aki:未確定 → aki:佐伯郡|17|[区間・通過点](../../data/work/districts/stage_e/routes/link_039.json)|
|`link_040` 桜尾城―草津|aki:佐伯郡 → aki:未確定 → aki:佐伯郡 → aki:未確定 → aki:佐伯郡 → aki:未確定 → aki:佐伯郡 → aki:未確定 → aki:佐伯郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_040.json)|
|`link_041` 草津―竹原|aki:佐伯郡 → aki:沼田郡 → aki:安芸郡 → aki:未確定 → aki:安芸郡 → aki:未確定 → aki:安芸郡 → aki:賀茂郡 → aki:未確定 → aki:賀茂郡|9|[区間・通過点](../../data/work/districts/stage_e/routes/link_041.json)|
|`link_042` 竹原―新高山城|aki:賀茂郡 → aki:豊田郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_042.json)|
|`link_043` 新高山城―三原城|aki:豊田郡 → bingo:未確定 → bingo:御調郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_043.json)|
|`link_044` 三原城―神辺城|bingo:御調郡 → bingo:沼隈郡 → bingo:深津郡 → bingo:安那郡 → bitchu:未確定|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_044.json)|
|`link_045` 神辺城―備中高松城|bitchu:未確定 → bitchu:小田郡 → bitchu:後月郡 → bitchu:小田郡 → bitchu:下道郡 → bitchu:窪屋郡 → bitchu:賀陽郡 → bitchu:賀陽郡 + bizen:未確定（数値接点・通過郡未判定） → bizen:未確定|7|[区間・通過点](../../data/work/districts/stage_e/routes/link_045.json)|
|`link_046` 備中高松城―岡山城|bizen:未確定 → bizen:津高郡 → bizen:御野郡 → bizen:上道郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_046.json)|
|`link_047` 岡山城―龍野城|bizen:上道郡 → bizen:邑久郡 → bizen:和気郡 → bizen:未確定 → bizen:和気郡 → bizen:未確定 → bizen:和気郡 → 表示区画外 → harima:未確定 → harima:赤穂郡 → harima:未確定 → harima:赤穂郡 → harima:揖東郡|12|[区間・通過点](../../data/work/districts/stage_e/routes/link_047.json)|
|`link_048` 龍野城―姫路城|harima:揖東郡 → harima:揖西郡 → harima:飾西郡 → harima:飾東郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_048.json)|
|`link_049` 姫路城―兵庫津|harima:飾東郡 → harima:印南郡 → harima:加古郡 → harima:明石郡 → settsu:未確定 → settsu:八部郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_049.json)|
|`link_050` 兵庫津―尼崎|settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:未確定 → settsu:八部郡 → settsu:兎原郡 → settsu:未確定 → settsu:兎原郡 → settsu:未確定 → settsu:兎原郡 → settsu:未確定 → settsu:兎原郡 → settsu:未確定 → settsu:武庫郡 → settsu:川辺郡|32|[区間・通過点](../../data/work/districts/stage_e/routes/link_050.json)|
|`link_051` 神辺城―鞆|bitchu:未確定 → bingo:深津郡 → bingo:沼隈郡 → bingo:未確定 → bingo:沼隈郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_051.json)|
|`link_052` 草津―吉田郡山城|aki:佐伯郡 → aki:沼田郡 → aki:高宮郡 → aki:沼田郡 → aki:高宮郡 → aki:高田郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_052.json)|
|`link_053` 吉田郡山城―日野山城|aki:高田郡 → aki:山縣郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_053.json)|
|`link_054` 日野山城―赤穴城|aki:山縣郡 → iwami:未確定 → iwami:邑智郡 → iwami:未確定|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_054.json)|
|`link_055` 赤穴城―三沢城|iwami:未確定 → izumo:飯石郡 → izumo:仁多郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_055.json)|
|`link_056` 三沢城―三刀屋城|izumo:仁多郡 → izumo:大原郡 → izumo:飯石郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_056.json)|
|`link_057` 三刀屋城―月山富田城|izumo:飯石郡 → izumo:大原郡 → izumo:意宇郡 → izumo:能義郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_057.json)|
|`link_058` 月山富田城―尾高城|izumo:能義郡 → hoki:未確定 → hoki:會見郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_058.json)|
|`link_059` 尾高城―江美城|hoki:會見郡 → hoki:日野郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_059.json)|
|`link_060` 江美城―打吹城|hoki:日野郡 → hoki:未確定 → hoki:久米郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_060.json)|
|`link_061` 打吹城―羽衣石城|hoki:久米郡 → hoki:河村郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_061.json)|
|`link_062` 羽衣石城―鹿野城|hoki:河村郡 → hoki:未確定 → inaba:気多郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_062.json)|
|`link_063` 鹿野城―鳥取城|inaba:気多郡 → inaba:高草郡 → inaba:邑美郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_063.json)|
|`link_064` 山口―三本松城|suo:吉敷郡 → suo:未確定 → nagato:阿武郡 → iwami:未確定 → iwami:鹿足郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_064.json)|
|`link_065` 三本松城―七尾城|iwami:鹿足郡 → iwami:美濃郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_065.json)|
|`link_066` 七尾城―温泉津|iwami:美濃郡 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:未確定 → iwami:那賀郡 → iwami:邇摩郡 → iwami:未確定 → iwami:邇摩郡|24|[区間・通過点](../../data/work/districts/stage_e/routes/link_066.json)|
|`link_067` 温泉津―石見銀山・石銀|iwami:邇摩郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_067.json)|
|`link_068` 石見銀山・石銀―赤穴城|iwami:邇摩郡 → iwami:邑智郡 → iwami:未確定|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_068.json)|
|`link_069` 備中高松城―備中松山城|bizen:未確定 → bitchu:賀陽郡 → bitchu:上房郡 → bitchu:川上郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_069.json)|
|`link_070` 備中松山城―高田城|bitchu:川上郡 → bitchu:上房郡 → bitchu:阿賀郡 → mimasaka:未確定 → mimasaka:眞島郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_070.json)|
|`link_071` 高田城―岩屋城|mimasaka:眞島郡 → mimasaka:大庭郡 → mimasaka:久米北条郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_071.json)|
|`link_072` 岩屋城―林野城|mimasaka:久米北条郡 → mimasaka:久米南条郡 → mimasaka:勝南郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_072.json)|
|`link_073` 林野城―矢筈城|mimasaka:勝南郡 → mimasaka:勝北郡 → mimasaka:東北条郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_073.json)|
|`link_074` 矢筈城―若桜鬼ヶ城|mimasaka:東北条郡 → mimasaka:未確定 → inaba:智頭郡 → inaba:八上郡 → inaba:八東郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_074.json)|
|`link_075` 若桜鬼ヶ城―鳥取城|inaba:八東郡 → inaba:法美郡 → inaba:邑美郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_075.json)|
|`link_076` 江美城―高田城|hoki:日野郡 → hoki:未確定 → mimasaka:眞島郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_076.json)|
|`link_077` 若桜鬼ヶ城―有子山城|inaba:八東郡 → 表示区画外 → tajima:未確定 → tajima:七美郡 → tajima:養父郡 → tajima:出石郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_077.json)|
|`link_078` 有子山城―竹田城|tajima:出石郡 → tajima:養父郡 → tajima:朝来郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_078.json)|
|`link_079` 竹田城―利神城|tajima:朝来郡 → tajima:未確定 → harima:宍栗郡 → harima:佐用郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_079.json)|
|`link_080` 利神城―龍野城|harima:佐用郡 → harima:揖東郡 → harima:揖西郡 → harima:揖東郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_080.json)|
|`link_081` 板島丸串城―黒瀬城|iyo:北宇和郡 → iyo:未確定 → iyo:北宇和郡 → iyo:東宇和郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_081.json)|
|`link_082` 黒瀬城―大洲城|iyo:東宇和郡 → iyo:喜多郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_082.json)|
|`link_083` 大洲城―湯築城|iyo:喜多郡 → iyo:下浮穴郡 → iyo:伊予郡 → iyo:久米郡 → iyo:温泉郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_083.json)|
|`link_084` 湯築城―金子城|iyo:温泉郡 → iyo:久米郡 → iyo:周布郡 → iyo:未確定 → iyo:周布郡 → iyo:新居郡 → iyo:未確定 → iyo:新居郡 → iyo:未確定 → iyo:新居郡 → iyo:未確定 → iyo:新居郡|11|[区間・通過点](../../data/work/districts/stage_e/routes/link_084.json)|
|`link_085` 金子城―川之江城|iyo:新居郡 → iyo:宇摩郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_085.json)|
|`link_086` 川之江城―天霧城|iyo:宇摩郡 → sanuki:未確定 → sanuki:豊田郡 → sanuki:三野郡 → sanuki:多度郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_086.json)|
|`link_087` 天霧城―十河城|sanuki:多度郡 → sanuki:那珂郡 → sanuki:鵜足郡 → sanuki:阿野郡 → sanuki:香川郡 → sanuki:山田郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_087.json)|
|`link_088` 十河城―引田城|sanuki:山田郡 → sanuki:三木郡 → sanuki:寒川郡 → sanuki:大内郡 → sanuki:未確定 → sanuki:大内郡 → sanuki:未確定|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_088.json)|
|`link_089` 引田城―撫養城|sanuki:未確定 → sanuki:大内郡 → sanuki:未確定 → awa_shikoku:板野郡 + sanuki:未確定（数値接点・通過郡未判定） → awa_shikoku:板野郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_089.json)|
|`link_090` 撫養城―勝瑞城|awa_shikoku:板野郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_090.json)|
|`link_091` 勝瑞城―阿波一宮城|awa_shikoku:板野郡 → awa_shikoku:名東郡 → awa_shikoku:板野郡 → awa_shikoku:名東郡 → awa_shikoku:板野郡 → awa_shikoku:名東郡 → awa_shikoku:名西郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_091.json)|
|`link_092` 川之江城―白地城|iyo:宇摩郡 → awa_shikoku:未確定 → sanuki:未確定 → awa_shikoku:三好郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_092.json)|
|`link_093` 白地城―阿波一宮城|awa_shikoku:三好郡 → awa_shikoku:美馬郡 → awa_shikoku:阿波郡 → awa_shikoku:麻植郡 → awa_shikoku:阿波郡 → awa_shikoku:麻植郡 → awa_shikoku:名西郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_093.json)|
|`link_094` 板島丸串城―中村|iyo:北宇和郡 → tosa:未確定 → tosa:幡多郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_094.json)|
|`link_095` 中村―岡豊城|tosa:幡多郡 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:未確定 → tosa:高岡郡 → tosa:吾川郡 → tosa:土佐郡 → tosa:未確定 → tosa:土佐郡 → tosa:未確定 → tosa:土佐郡 → tosa:長岡郡 → tosa:土佐郡 → tosa:長岡郡|42|[区間・通過点](../../data/work/districts/stage_e/routes/link_095.json)|
|`link_096` 岡豊城―白地城|tosa:長岡郡 → tosa:香美郡 → tosa:長岡郡 → tosa:香美郡 → tosa:長岡郡 → awa_shikoku:未確定 → awa_shikoku:三好郡 → awa_shikoku:美馬郡 → awa_shikoku:三好郡 → awa_shikoku:美馬郡 → awa_shikoku:三好郡 → awa_shikoku:美馬郡 → awa_shikoku:三好郡|12|[区間・通過点](../../data/work/districts/stage_e/routes/link_096.json)|
|`link_097` 尼崎―茨木城|settsu:川辺郡 → settsu:豊島郡 → settsu:島下郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_097.json)|
|`link_098` 茨木城―高槻城|settsu:島下郡 → settsu:島上郡 → kawachi:未確定 + settsu:島上郡（数値接点・通過郡未判定） → kawachi:未確定 → yamashiro:未確定|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_098.json)|
|`link_099` 高槻城―勝龍寺城|yamashiro:未確定 → yamashiro:乙訓郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_099.json)|
|`link_100` 勝龍寺城―淀古城|yamashiro:乙訓郡 → yamashiro:紀伊郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_100.json)|
|`link_101` 淀古城―京都|yamashiro:紀伊郡 → yamashiro:葛野郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_101.json)|
|`link_102` 京都―大津|yamashiro:葛野郡 → yamashiro:愛宕郡 → yamashiro:葛野郡 → yamashiro:愛宕郡 → omi:未確定 → omi:滋賀郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_102.json)|
|`link_103` 大津―坂本城|omi:滋賀郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_103.json)|
|`link_104` 大津―安土城|omi:滋賀郡 → omi:栗太郡 → omi:野洲郡 → omi:蒲生郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_104.json)|
|`link_105` 安土城―長浜城|omi:蒲生郡 → omi:神崎郡 → omi:愛知郡 → omi:犬上郡 → omi:坂田郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_105.json)|
|`link_106` 長浜城―敦賀|omi:坂田郡 → omi:東浅井郡 → omi:伊香郡 → omi:西浅井郡 → echizen:未確定 → echizen:敦賀郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_106.json)|
|`link_107` 安土城―日野城|omi:蒲生郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_107.json)|
|`link_108` 日野城―亀山城|omi:蒲生郡 → omi:甲賀郡 → ise:未確定 → ise:鈴鹿郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_108.json)|
|`link_109` 京都―亀山城|yamashiro:葛野郡 → yamashiro:乙訓郡 → yamashiro:葛野郡 → yamashiro:乙訓郡 → yamashiro:未確定|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_109.json)|
|`link_110` 亀山城―黒井城|yamashiro:未確定 → tanba:南桑田郡 → tanba:船井郡 → tanba:多紀郡 → tanba:船井郡 → tanba:多紀郡 → tanba:氷上郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_110.json)|
|`link_111` 黒井城―福知山城|tanba:氷上郡 → tanba:天田郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_111.json)|
|`link_112` 福知山城―宮津城|tanba:天田郡 → tanba:未確定 → tango:加佐郡 → tango:与謝郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_112.json)|
|`link_113` 宮津城―弓木城|tango:与謝郡 → tango:未確定 → tango:与謝郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_113.json)|
|`link_114` 福知山城―有子山城|tanba:天田郡 → tanba:未確定 → tajima:出石郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_114.json)|
|`link_115` 兵庫津―三木城|settsu:八部郡 → settsu:未確定 → harima:明石郡 → harima:美嚢郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_115.json)|
|`link_116` 三木城―黒井城|harima:美嚢郡 → harima:加東郡 → harima:加西郡 → harima:多可郡 → tanba:未確定 → tanba:氷上郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_116.json)|
|`link_117` 尼崎―石山本願寺|settsu:川辺郡 → settsu:豊島郡 → settsu:東成郡 → settsu:西成郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_117.json)|
|`link_118` 堺―高屋城|settsu:未確定 → kawachi:未確定 → kawachi:八上郡 → kawachi:丹北郡 → kawachi:丹南郡 → kawachi:志紀郡 → kawachi:丹南郡 → kawachi:志紀郡 → kawachi:丹南郡 → kawachi:古市郡|9|[区間・通過点](../../data/work/districts/stage_e/routes/link_118.json)|
|`link_119` 郡山城―奈良|yamato:添下郡 → yamato:添上郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_119.json)|
|`link_120` 奈良―淀古城|yamato:添上郡 → yamato:添下郡 → yamashiro:未確定 → yamashiro:相楽郡 → yamashiro:綴喜郡 → yamashiro:久世郡 → yamashiro:綴喜郡 → yamashiro:久世郡 → yamashiro:紀伊郡 → yamashiro:久世郡 → yamashiro:紀伊郡|10|[区間・通過点](../../data/work/districts/stage_e/routes/link_120.json)|
|`link_121` 堺―岸和田城|settsu:未確定 → izumi:大鳥郡 + settsu:未確定（数値接点・通過郡未判定） → izumi:大鳥郡 → izumi:未確定 → izumi:泉郡 → izumi:未確定 → izumi:泉郡 → izumi:未確定 → izumi:泉郡 → izumi:南郡 → izumi:未確定 → izumi:南郡 → izumi:未確定 → izumi:南郡|12|[区間・通過点](../../data/work/districts/stage_e/routes/link_121.json)|
|`link_122` 雑賀・鷺森付近―根来寺|kii:未確定 → kii:名草郡 → kii:那賀郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_122.json)|
|`link_123` 根来寺―高野山|kii:那賀郡 → kii:伊都郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_123.json)|
|`link_124` 高野山―新宮|kii:伊都郡 → yamato:未確定 → yamato:吉野郡 → kii:未確定 → kii:南牟婁郡 → kii:未確定 → kii:南牟婁郡 → kii:未確定 → kii:南牟婁郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_124.json)|
|`link_125` 桑名―熱田|ise:桑名郡 → owari:未確定 → owari:海西郡 → owari:未確定 → owari:海西郡 → owari:未確定 → owari:海西郡 → owari:未確定 → owari:愛知郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_125.json)|
|`link_126` 熱田―刈谷城|owari:愛知郡 → owari:知多郡 → owari:未確定 → mikawa:碧海郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_126.json)|
|`link_127` 刈谷城―岡崎城|mikawa:碧海郡 → mikawa:額田郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_127.json)|
|`link_128` 岡崎城―吉田城|mikawa:額田郡 → mikawa:宝飯郡 → mikawa:渥美郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_128.json)|
|`link_129` 吉田城―浜松城|mikawa:渥美郡 → mikawa:八名郡 → mikawa:未確定 → totomi:敷智郡 → mikawa:未確定 → totomi:敷智郡 → mikawa:未確定 → totomi:引佐郡 → totomi:敷智郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_129.json)|
|`link_130` 浜松城―掛川城|totomi:敷智郡 → totomi:長上郡 → totomi:豊田郡 → totomi:山名郡 → totomi:佐野郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_130.json)|
|`link_131` 掛川城―清水湊|totomi:佐野郡 → totomi:城東郡 → totomi:榛原郡 → totomi:城東郡 → totomi:榛原郡 → suruga:未確定 → suruga:志太郡 → suruga:未確定 → suruga:志太郡 → suruga:未確定 → suruga:志太郡 → suruga:未確定 → suruga:志太郡 → suruga:未確定 → suruga:志太郡 → suruga:未確定 → suruga:志太郡 → suruga:未確定 → suruga:有度郡 → suruga:未確定 → suruga:有度郡 → suruga:未確定 → suruga:有度郡|22|[区間・通過点](../../data/work/districts/stage_e/routes/link_131.json)|
|`link_132` 清水湊―興国寺城|suruga:有度郡 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:富士郡 → suruga:未確定 → suruga:富士郡 → suruga:未確定 → suruga:富士郡 → suruga:駿東郡|21|[区間・通過点](../../data/work/districts/stage_e/routes/link_132.json)|
|`link_133` 興国寺城―三枚橋城|suruga:駿東郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_133.json)|
|`link_134` 三枚橋城―小田原|suruga:駿東郡 → izu:未確定 → izu:君沢郡 → izu:未確定 → izu:君沢郡 → izu:田方郡 → sagami:未確定 → sagami:足柄下郡|7|[区間・通過点](../../data/work/districts/stage_e/routes/link_134.json)|
|`link_135` 桑名―神戸城|ise:桑名郡 → ise:朝明郡 → ise:未確定 → ise:朝明郡 → ise:未確定 → ise:朝明郡 → ise:未確定 → ise:朝明郡 → ise:未確定 → ise:朝明郡 → ise:未確定 → ise:朝明郡 → ise:三重郡 → ise:河曲郡|13|[区間・通過点](../../data/work/districts/stage_e/routes/link_135.json)|
|`link_136` 神戸城―亀山城|ise:河曲郡 → ise:鈴鹿郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_136.json)|
|`link_137` 亀山城―安濃津城|ise:鈴鹿郡 → ise:安芸郡 → ise:安濃郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_137.json)|
|`link_138` 安濃津城―松ヶ島城|ise:安濃郡 → ise:一志郡 → ise:未確定 → ise:一志郡 → ise:飯高郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_138.json)|
|`link_139` 松ヶ島城―宇治山田|ise:飯高郡 → ise:飯野郡 → ise:多気郡 → ise:度会郡 → ise:多気郡 → ise:度会郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_139.json)|
|`link_140` 宇治山田―鳥羽|ise:度会郡 → ise:未確定|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_140.json)|
|`link_141` 熱田―清洲城|owari:愛知郡 → owari:海東郡 → owari:西春日井郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_141.json)|
|`link_142` 清洲城―犬山城|owari:西春日井郡 → owari:丹羽郡 → mino:未確定|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_142.json)|
|`link_143` 犬山城―美濃金山城|mino:未確定 → mino:可児郡 → mino:加茂郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_143.json)|
|`link_144` 美濃金山城―苗木城|mino:加茂郡 → mino:可児郡 → mino:土岐郡 → mino:加茂郡 → mino:恵那郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_144.json)|
|`link_145` 苗木城―妻籠|mino:恵那郡 → mino:未確定 → shinano:西筑摩郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_145.json)|
|`link_146` 清洲城―岐阜城|owari:西春日井郡 → owari:丹羽郡 → owari:羽栗郡 → mino:未確定 → mino:羽栗郡 → mino:各務郡 → mino:厚見郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_146.json)|
|`link_147` 岐阜城―大垣城|mino:厚見郡 → mino:安八郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_147.json)|
|`link_148` 大垣城―長島城|mino:安八郡 → mino:下石津郡 → mino:未確定 → mino:下石津郡 → mino:未確定 → owari:海西郡 → owari:未確定 → owari:海西郡 → owari:未確定|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_148.json)|
|`link_149` 長島城―桑名|owari:未確定 → ise:桑名郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_149.json)|
|`link_150` 大垣城―長浜城|mino:安八郡 → mino:不破郡 → mino:未確定 → omi:坂田郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_150.json)|
|`link_151` 刈谷城―西尾城|mikawa:碧海郡 → mikawa:未確定 → mikawa:碧海郡 → mikawa:幡豆郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_151.json)|
|`link_152` 西尾城―吉田城|mikawa:幡豆郡 → mikawa:額田郡 → mikawa:宝飯郡 → mikawa:未確定 → mikawa:宝飯郡 → mikawa:渥美郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_152.json)|
|`link_153` 吉田城―新城城|mikawa:渥美郡 → mikawa:八名郡 → mikawa:宝飯郡 → mikawa:八名郡 → mikawa:宝飯郡 → mikawa:八名郡 → mikawa:宝飯郡 → mikawa:八名郡 → mikawa:南設楽郡 → mikawa:八名郡|9|[区間・通過点](../../data/work/districts/stage_e/routes/link_153.json)|
|`link_154` 新城城―岩村城|mikawa:八名郡 → mikawa:南設楽郡 → mikawa:八名郡 → mikawa:南設楽郡 → mikawa:北設楽郡 → mino:未確定 → mino:恵那郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_154.json)|
|`link_155` 岩村城―苗木城|mino:恵那郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_155.json)|
|`link_156` 美濃金山城―郡上八幡城|mino:加茂郡 → mino:武儀郡 → mino:郡上郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_156.json)|
|`link_157` 郡上八幡城―桜洞城|mino:郡上郡 → hida:未確定 → hida:益田郡 → hida:未確定 → hida:益田郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_157.json)|
|`link_158` 桜洞城―帰雲城|hida:益田郡 → hida:大野郡 → hida:益田郡 → hida:大野郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_158.json)|
|`link_159` 帰雲城―金沢城|hida:大野郡 → etchu:未確定 → etchu:礪波郡 → etchu:未確定 → etchu:礪波郡 → kaga:未確定 → kaga:石川郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_159.json)|
|`link_160` 妻籠―木曽福島|shinano:西筑摩郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_160.json)|
|`link_161` 木曽福島―深志城|shinano:西筑摩郡 → shinano:東筑摩郡 → shinano:西筑摩郡 → shinano:東筑摩郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_161.json)|
|`link_162` 深志城―荒砥城|shinano:東筑摩郡 → shinano:小県郡 → shinano:東筑摩郡 → shinano:小県郡 → shinano:更科郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_162.json)|
|`link_163` 荒砥城―海津城|shinano:更科郡 → shinano:埴科郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_163.json)|
|`link_164` 海津城―飯山城|shinano:埴科郡 → shinano:更科郡 → shinano:埴科郡 → shinano:更科郡 → shinano:埴科郡 → shinano:更科郡 → shinano:埴科郡 → shinano:更科郡 → shinano:埴科郡 → shinano:更科郡 → shinano:埴科郡 → shinano:更科郡 → shinano:埴科郡 → shinano:上高井郡 → shinano:下高井郡 → shinano:下水内郡 → shinano:下高井郡 → shinano:下水内郡|17|[区間・通過点](../../data/work/districts/stage_e/routes/link_164.json)|
|`link_165` 飯山城―春日山城|shinano:下水内郡 → shinano:未確定 → echigo:中頸城郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_165.json)|
|`link_166` 新城城―飯田城|mikawa:八名郡 → mikawa:南設楽郡 → mikawa:八名郡 → mikawa:南設楽郡 → mikawa:北設楽郡 → mikawa:未確定 → shinano:下伊那郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_166.json)|
|`link_167` 飯田城―高島古城|shinano:下伊那郡 → shinano:上伊那郡 → shinano:諏訪郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_167.json)|
|`link_168` 高島古城―深志城|shinano:諏訪郡 → shinano:東筑摩郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_168.json)|
|`link_169` 高島古城―若神子城|shinano:諏訪郡 → kai:未確定|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_169.json)|
|`link_170` 若神子城―甲府・古府中付近|kai:未確定|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_170.json)|
|`link_171` 甲府・古府中付近―谷村城|kai:未確定|9|[区間・通過点](../../data/work/districts/stage_e/routes/link_171.json)|
|`link_172` 谷村城―津久井城|kai:未確定 → sagami:津久井郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_172.json)|
|`link_173` 若神子城―小諸城|kai:未確定 → shinano:未確定 → shinano:南佐久郡 → shinano:北佐久郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_173.json)|
|`link_174` 小諸城―戸石城|shinano:北佐久郡 → shinano:小県郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_174.json)|
|`link_175` 戸石城―荒砥城|shinano:小県郡 → shinano:更科郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_175.json)|
|`link_176` 甲府・古府中付近―清水湊|kai:未確定 → kai:未確定 + suruga:未確定（数値接点・通過郡未判定） → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:未確定 → suruga:庵原郡 → suruga:有度郡|22|[区間・通過点](../../data/work/districts/stage_e/routes/link_176.json)|
|`link_177` 小田原―玉縄城|sagami:足柄下郡 → sagami:足柄上郡 → sagami:未確定 → sagami:足柄上郡 → sagami:淘綾郡 → sagami:未確定 → sagami:大住郡 → sagami:未確定 → sagami:高座郡 → sagami:未確定 → sagami:高座郡 → sagami:鎌倉郡 → sagami:高座郡 → sagami:鎌倉郡|13|[区間・通過点](../../data/work/districts/stage_e/routes/link_177.json)|
|`link_178` 玉縄城―鎌倉|sagami:鎌倉郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_178.json)|
|`link_179` 鎌倉―三崎城|sagami:鎌倉郡 → sagami:三浦郡 → sagami:未確定 → sagami:三浦郡 → sagami:未確定 → sagami:三浦郡 → sagami:未確定 → sagami:三浦郡 → sagami:未確定 → sagami:三浦郡 → sagami:未確定 → sagami:三浦郡|11|[区間・通過点](../../data/work/districts/stage_e/routes/link_179.json)|
|`link_180` 玉縄城―小机城|sagami:鎌倉郡 → sagami:未確定 → musashi:橘樹郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_180.json)|
|`link_181` 小机城―品川湊|musashi:橘樹郡 → musashi:荏原郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_181.json)|
|`link_182` 品川湊―江戸城|musashi:荏原郡 → musashi:未確定 → musashi:豊島郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_182.json)|
|`link_183` 江戸城―岩付城|musashi:豊島郡 → musashi:南足立郡 → musashi:北足立郡 → musashi:南埼玉郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_183.json)|
|`link_184` 岩付城―関宿城|musashi:南埼玉郡 → musashi:北葛飾郡 → shimosa:未確定 → shimosa:東葛飾郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_184.json)|
|`link_185` 関宿城―古河城|shimosa:東葛飾郡 → shimosa:西葛飾郡 → musashi:未確定|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_185.json)|
|`link_186` 古河城―結城城|musashi:未確定 → shimosa:西葛飾郡 → shimosa:未確定 → shimosa:結城郡 → hitachi:未確定|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_186.json)|
|`link_187` 結城城―宇都宮城|hitachi:未確定 → shimotsuke:下都賀郡 → shimotsuke:河内郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_187.json)|
|`link_188` 小机城―滝山城|musashi:橘樹郡 → musashi:都筑郡 → musashi:南多摩郡 → musashi:都筑郡 → musashi:南多摩郡 → musashi:都筑郡 → musashi:南多摩郡 → musashi:北多摩郡 → musashi:南多摩郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_188.json)|
|`link_189` 滝山城―津久井城|musashi:南多摩郡 → musashi:未確定 → sagami:津久井郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_189.json)|
|`link_190` 江戸城―川越城|musashi:豊島郡 → musashi:新座郡 → musashi:入間郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_190.json)|
|`link_191` 川越城―松山城|musashi:入間郡 → musashi:比企郡 → musashi:横見郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_191.json)|
|`link_192` 松山城―鉢形城|musashi:横見郡 → musashi:比企郡 → musashi:男衾郡 → musashi:比企郡 → musashi:男衾郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_192.json)|
|`link_193` 鉢形城―深谷城|musashi:男衾郡 → musashi:榛沢郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_193.json)|
|`link_194` 深谷城―忍城|musashi:榛沢郡 → musashi:幡羅郡 → musashi:北埼玉郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_194.json)|
|`link_195` 忍城―騎西城|musashi:北埼玉郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_195.json)|
|`link_196` 騎西城―岩付城|musashi:北埼玉郡 → musashi:南埼玉郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_196.json)|
|`link_197` 深谷城―箕輪城|musashi:榛沢郡 → musashi:児玉郡 → musashi:賀美郡 → kozuke:未確定 → kozuke:那波郡 → kozuke:未確定 → kozuke:緑野郡 → kozuke:那波郡 → kozuke:緑野郡 → kozuke:那波郡 → kozuke:緑野郡 → kozuke:那波郡 → kozuke:西群馬郡|12|[区間・通過点](../../data/work/districts/stage_e/routes/link_197.json)|
|`link_198` 箕輪城―厩橋城|kozuke:西群馬郡 → kozuke:東群馬郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_198.json)|
|`link_199` 厩橋城―金山城|kozuke:東群馬郡 → kozuke:那波郡 → kozuke:佐位郡 → kozuke:新田郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_199.json)|
|`link_200` 金山城―館林城|kozuke:新田郡 → kozuke:山田郡 → shimotsuke:未確定 → kozuke:山田郡 → kozuke:邑楽郡 → shimotsuke:未確定 → kozuke:邑楽郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_200.json)|
|`link_201` 館林城―唐沢山城|kozuke:邑楽郡 → kozuke:未確定 → shimotsuke:安蘇郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_201.json)|
|`link_202` 唐沢山城―宇都宮城|shimotsuke:安蘇郡 → shimotsuke:下都賀郡 → shimotsuke:上都賀郡 → shimotsuke:下都賀郡 → shimotsuke:上都賀郡 → shimotsuke:下都賀郡 → shimotsuke:河内郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_202.json)|
|`link_203` 小諸城―箕輪城|shinano:北佐久郡 → shinano:未確定 → kozuke:碓氷郡 → kozuke:西群馬郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_203.json)|
|`link_204` 江戸城―臼井城|musashi:豊島郡 → musashi:南足立郡 → musashi:南葛飾郡 → musashi:南足立郡 → musashi:南葛飾郡 → musashi:未確定 → shimosa:東葛飾郡 → shimosa:千葉郡 → shimosa:印旛郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_204.json)|
|`link_205` 臼井城―本佐倉城|shimosa:印旛郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_205.json)|
|`link_206` 本佐倉城―小田喜城|shimosa:印旛郡 → shimosa:千葉郡 → kazusa:未確定 → kazusa:山辺郡 → kazusa:市原郡 → kazusa:山辺郡 → kazusa:市原郡 → kazusa:長柄郡 → kazusa:上埴生郡 → kazusa:夷隅郡|9|[区間・通過点](../../data/work/districts/stage_e/routes/link_206.json)|
|`link_207` 小田喜城―久留里城|kazusa:夷隅郡 → kazusa:市原郡 → kazusa:望陀郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_207.json)|
|`link_208` 久留里城―佐貫城|kazusa:望陀郡 → kazusa:周淮郡 → kazusa:天羽郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_208.json)|
|`link_209` 佐貫城―岡本城|kazusa:天羽郡 → kazusa:未確定 → kazusa:天羽郡 → honshu-area-30:未確定 → honshu-area-30:平郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_209.json)|
|`link_210` 本佐倉城―土浦城|shimosa:印旛郡 → shimosa:下埴生郡 → shimosa:印旛郡 → shimosa:未確定 → hitachi:河内郡 → hitachi:信太郡 → hitachi:新治郡|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_210.json)|
|`link_211` 土浦城―小田城|hitachi:新治郡 → hitachi:信太郡 → hitachi:新治郡 → hitachi:信太郡 → hitachi:新治郡 → hitachi:筑波郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_211.json)|
|`link_212` 小田城―真壁城|hitachi:筑波郡 → hitachi:新治郡 → hitachi:筑波郡 → hitachi:真壁郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_212.json)|
|`link_213` 真壁城―笠間城|hitachi:真壁郡 → hitachi:西茨城郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_213.json)|
|`link_214` 笠間城―水戸城|hitachi:西茨城郡 → hitachi:東茨城郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_214.json)|
|`link_215` 水戸城―太田城|hitachi:東茨城郡 → hitachi:那珂郡 → hitachi:久慈郡 → hitachi:那珂郡 → hitachi:久慈郡 → hitachi:那珂郡 → hitachi:久慈郡 → hitachi:那珂郡 → hitachi:久慈郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_215.json)|
|`link_216` 結城城―真壁城|hitachi:未確定 → hitachi:真壁郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_216.json)|
|`link_217` 小浜―敦賀|echizen:未確定 → echizen:敦賀郡 → echizen:未確定 → echizen:敦賀郡 → echizen:未確定 → echizen:敦賀郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_217.json)|
|`link_218` 敦賀―府中城|echizen:敦賀郡 → echizen:未確定 → echizen:敦賀郡 → echizen:未確定 → echizen:敦賀郡 → echizen:南條郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_218.json)|
|`link_219` 府中城―北ノ庄城|echizen:南條郡 → echizen:丹生郡 → echizen:足羽郡 → echizen:丹生郡 → echizen:足羽郡 → echizen:吉田郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_219.json)|
|`link_220` 北ノ庄城―大聖寺城|echizen:吉田郡 → echizen:坂井郡 → echizen:未確定 → kaga:江沼郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_220.json)|
|`link_221` 大聖寺城―小松城|kaga:江沼郡 → kaga:能美郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_221.json)|
|`link_222` 小松城―松任城|kaga:能美郡 → kaga:石川郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_222.json)|
|`link_223` 松任城―金沢城|kaga:石川郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_223.json)|
|`link_224` 金沢城―木舟城|kaga:石川郡 → kaga:河北郡 → kaga:未確定 → etchu:礪波郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_224.json)|
|`link_225` 木舟城―増山城|etchu:礪波郡 → etchu:射水郡 → etchu:礪波郡 → etchu:射水郡 → etchu:礪波郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_225.json)|
|`link_226` 増山城―富山城|etchu:礪波郡 → etchu:射水郡 → etchu:婦負郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_226.json)|
|`link_227` 富山城―魚津城|etchu:婦負郡 → etchu:上新川郡 → etchu:下新川郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_227.json)|
|`link_228` 魚津城―春日山城|etchu:下新川郡 → etchu:未確定 → echigo:西頸城郡 → echigo:未確定 → echigo:西頸城郡 → echigo:未確定 → echigo:西頸城郡 → echigo:未確定 → echigo:西頸城郡 → echigo:未確定 → echigo:西頸城郡 → echigo:未確定 → echigo:西頸城郡 → echigo:未確定 → echigo:西頸城郡 → echigo:中頸城郡|15|[区間・通過点](../../data/work/districts/stage_e/routes/link_228.json)|
|`link_229` 春日山城―直江津|echigo:中頸城郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_229.json)|
|`link_230` 直江津―柏崎|echigo:中頸城郡 → echigo:未確定 → echigo:中頸城郡 → echigo:未確定 → echigo:中頸城郡 → echigo:刈羽郡 → echigo:未確定 → echigo:刈羽郡 → echigo:未確定 → echigo:刈羽郡 → echigo:未確定 → echigo:刈羽郡 → echigo:未確定 → echigo:刈羽郡|13|[区間・通過点](../../data/work/districts/stage_e/routes/link_230.json)|
|`link_231` 柏崎―与板城|echigo:刈羽郡 → echigo:三嶋郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_231.json)|
|`link_232` 与板城―新発田城|echigo:三嶋郡 → echigo:南蒲原郡 → echigo:西蒲原郡 → echigo:南蒲原郡 → echigo:西蒲原郡 → echigo:南蒲原郡 → echigo:西蒲原郡 → echigo:南蒲原郡 → echigo:西蒲原郡 → echigo:南蒲原郡 → echigo:西蒲原郡 → echigo:中蒲原郡 → echigo:北蒲原郡 → echigo:中蒲原郡 → echigo:北蒲原郡|14|[区間・通過点](../../data/work/districts/stage_e/routes/link_232.json)|
|`link_233` 新発田城―本庄城|echigo:北蒲原郡 → echigo:岩舩郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_233.json)|
|`link_234` 増山城―守山城|etchu:礪波郡 → etchu:射水郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_234.json)|
|`link_235` 守山城―放生津|etchu:射水郡 → etchu:未確定 → etchu:射水郡 → etchu:未確定 → etchu:射水郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_235.json)|
|`link_236` 放生津―富山城|etchu:射水郡 → etchu:未確定 → etchu:射水郡 → etchu:未確定 → etchu:射水郡 → etchu:婦負郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_236.json)|
|`link_237` 富山城―城生城|etchu:婦負郡 → etchu:上新川郡 → etchu:婦負郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_237.json)|
|`link_238` 魚津城―松倉城|etchu:下新川郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_238.json)|
|`link_239` 金沢城―輪島|kaga:石川郡 → kaga:河北郡 → kaga:未確定 → kaga:未確定 + noto:未確定（数値接点・通過郡未判定） → noto:未確定 → noto:羽咋郡 → noto:未確定 → noto:羽咋郡 → noto:未確定 → noto:羽咋郡 → noto:未確定 → noto:羽咋郡 → noto:未確定 → noto:羽咋郡 → noto:鹿島郡 → noto:未確定 → noto:鹿島郡 → noto:未確定 → noto:鹿島郡 → noto:未確定 → noto:鹿島郡 → noto:未確定 → noto:鹿島郡 → noto:未確定 → noto:鹿島郡 → noto:鳳至郡|24|[区間・通過点](../../data/work/districts/stage_e/routes/link_239.json)|
|`link_240` 与板城―栃尾城|echigo:三嶋郡 → echigo:南蒲原郡 → echigo:古志郡 → echigo:南蒲原郡 → echigo:古志郡 → echigo:南蒲原郡 → echigo:古志郡 → echigo:南蒲原郡 → echigo:古志郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_240.json)|
|`link_241` 栃尾城―坂戸城|echigo:古志郡 → echigo:北魚沼郡 → echigo:南魚沼郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_241.json)|
|`link_242` 坂戸城―春日山城|echigo:南魚沼郡 → echigo:中魚沼郡 → echigo:東頸城郡 → echigo:中頸城郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_242.json)|
|`link_243` 新発田城―黒川城|echigo:北蒲原郡 → echigo:東蒲原郡 → echigo:未確定 → honshu-area-09:河沼郡 → honshu-area-09:耶麻郡 → honshu-area-09:河沼郡 → honshu-area-09:耶麻郡 → honshu-area-09:河沼郡 → honshu-area-09:北会津郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_243.json)|
|`link_244` 宇都宮城―白河小峰城|shimotsuke:河内郡 → shimotsuke:塩谷郡 → shimotsuke:那須郡 → shimotsuke:未確定 → honshu-area-08:西白河郡 → honshu-area-09:未確定|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_244.json)|
|`link_245` 白河小峰城―須賀川城|honshu-area-09:未確定 → honshu-area-09:岩瀬郡 → honshu-area-09:未確定 → honshu-area-09:岩瀬郡 → honshu-area-09:未確定 → honshu-area-09:岩瀬郡 → honshu-area-09:未確定|6|[区間・通過点](../../data/work/districts/stage_e/routes/link_245.json)|
|`link_246` 須賀川城―本宮城|honshu-area-09:未確定 → honshu-area-09:安積郡 → honshu-area-09:未確定 → honshu-area-09:安積郡 → honshu-area-09:未確定 → honshu-area-09:安積郡 → honshu-area-09:未確定 → honshu-area-09:安積郡 → honshu-area-09:安達郡|8|[区間・通過点](../../data/work/districts/stage_e/routes/link_246.json)|
|`link_247` 本宮城―二本松城|honshu-area-09:安達郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_247.json)|
|`link_248` 二本松城―白石城|honshu-area-09:安達郡 → honshu-area-09:信夫郡 → honshu-area-09:伊達郡 → honshu-area-08:未確定 → honshu-area-08:刈田郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_248.json)|
|`link_249` 白石城―塩竈|honshu-area-08:刈田郡 → honshu-area-08:未確定 → honshu-area-05:柴田郡 → honshu-area-05:名取郡 → honshu-area-05:宮城郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_249.json)|
|`link_250` 塩竈―寺池城|honshu-area-05:宮城郡 → honshu-area-05:未確定 → honshu-area-05:宮城郡 → honshu-area-05:未確定 → honshu-area-05:宮城郡 → honshu-area-05:桃生郡 → honshu-area-05:宮城郡 → honshu-area-05:桃生郡 → honshu-area-05:宮城郡 → honshu-area-05:桃生郡 → honshu-area-05:遠田郡 → honshu-area-05:桃生郡 → honshu-area-05:遠田郡 → honshu-area-05:登米郡|13|[区間・通過点](../../data/work/districts/stage_e/routes/link_250.json)|
|`link_251` 寺池城―鳥谷ヶ崎城|honshu-area-05:登米郡 → honshu-area-05:未確定 → honshu-area-05:登米郡 → honshu-area-05:未確定 → honshu-area-05:登米郡 → honshu-area-05:未確定 → honshu-area-05:登米郡 → honshu-area-05:未確定 → honshu-area-05:登米郡 → honshu-area-04:未確定 → honshu-area-04:西磐井郡 → honshu-area-04:胆沢郡 → honshu-area-04:江刺郡 → honshu-area-04:東和賀郡 → honshu-area-04:稗貫郡|14|[区間・通過点](../../data/work/districts/stage_e/routes/link_251.json)|
|`link_252` 鳥谷ヶ崎城―高水寺城|honshu-area-04:稗貫郡 → honshu-area-04:紫波郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_252.json)|
|`link_253` 高水寺城―九戸城|honshu-area-04:紫波郡 → honshu-area-04:南岩手郡 → honshu-area-04:北岩手郡 → honshu-area-01:未確定 → honshu-area-01:二戸郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_253.json)|
|`link_254` 九戸城―三戸城|honshu-area-01:二戸郡 → honshu-area-01:三戸郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_254.json)|
|`link_255` 太田城―赤館城|hitachi:久慈郡 → hitachi:未確定 → honshu-area-08:東白川郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_255.json)|
|`link_256` 赤館城―白河小峰城|honshu-area-08:東白川郡 → honshu-area-08:西白河郡 → honshu-area-09:未確定|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_256.json)|
|`link_257` 太田城―小高城|hitachi:久慈郡 → hitachi:多賀郡 → hitachi:未確定 → hitachi:多賀郡 → hitachi:未確定 → hitachi:多賀郡 → hitachi:未確定 → hitachi:多賀郡 → hitachi:未確定 → hitachi:多賀郡 → hitachi:未確定 → honshu-area-08:未確定 → honshu-area-08:菊多郡 → honshu-area-08:未確定 → honshu-area-08:菊多郡 → honshu-area-08:磐前郡 → honshu-area-08:磐城郡 → honshu-area-08:未確定 → honshu-area-08:磐城郡 → honshu-area-08:楢葉郡 → honshu-area-08:未確定 → honshu-area-08:楢葉郡 → honshu-area-08:未確定 → honshu-area-08:楢葉郡 → honshu-area-08:未確定 → honshu-area-08:楢葉郡 → honshu-area-08:未確定 → honshu-area-08:楢葉郡 → honshu-area-08:未確定 → honshu-area-08:楢葉郡 → honshu-area-08:未確定 → honshu-area-08:楢葉郡 → honshu-area-08:未確定 → honshu-area-08:楢葉郡 → honshu-area-08:標葉郡 → honshu-area-08:行方郡|35|[区間・通過点](../../data/work/districts/stage_e/routes/link_257.json)|
|`link_258` 小高城―丸森城|honshu-area-08:行方郡 → honshu-area-08:宇多郡 → honshu-area-08:伊具郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_258.json)|
|`link_259` 丸森城―白石城|honshu-area-08:伊具郡 → honshu-area-08:刈田郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_259.json)|
|`link_260` 本宮城―小浜城|honshu-area-09:安達郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_260.json)|
|`link_261` 小浜城―二本松城|honshu-area-09:安達郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_261.json)|
|`link_262` 須賀川城―黒川城|honshu-area-09:未確定 → honshu-area-09:岩瀬郡 → honshu-area-09:安積郡 → honshu-area-09:岩瀬郡 → honshu-area-09:安積郡 → honshu-area-09:北会津郡|5|[区間・通過点](../../data/work/districts/stage_e/routes/link_262.json)|
|`link_263` 黒川城―米沢城付近|honshu-area-09:北会津郡 → honshu-area-09:河沼郡 → honshu-area-09:耶麻郡 → honshu-area-06:未確定 → honshu-area-06:南置賜郡|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_263.json)|
|`link_264` 米沢城付近―上山城|honshu-area-06:南置賜郡 → honshu-area-06:東置賜郡 → honshu-area-06:南村山郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_264.json)|
|`link_265` 上山城―山形城|honshu-area-06:南村山郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_265.json)|
|`link_266` 山形城―天童城|honshu-area-06:南村山郡 → honshu-area-06:東村山郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_266.json)|
|`link_267` 天童城―延沢城|honshu-area-06:東村山郡 → honshu-area-06:北村山郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_267.json)|
|`link_268` 延沢城―鮭延城|honshu-area-06:北村山郡 → honshu-area-06:最上郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_268.json)|
|`link_269` 鮭延城―横手城|honshu-area-06:最上郡 → honshu-area-03:未確定 → honshu-area-03:雄勝郡 → honshu-area-03:平鹿郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_269.json)|
|`link_270` 横手城―角館城|honshu-area-03:平鹿郡 → honshu-area-03:仙北郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_270.json)|
|`link_271` 角館城―大館城|honshu-area-03:仙北郡 → honshu-area-03:北秋田郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_271.json)|
|`link_272` 大館城―堀越城|honshu-area-03:北秋田郡 → honshu-area-01:未確定 → honshu-area-01:南津軽郡 → honshu-area-01:未確定 → honshu-area-01:南津軽郡 → honshu-area-01:未確定 → honshu-area-01:南津軽郡 → honshu-area-01:中津軽郡|7|[区間・通過点](../../data/work/districts/stage_e/routes/link_272.json)|
|`link_273` 堀越城―大浦城|honshu-area-01:中津軽郡|0|[区間・通過点](../../data/work/districts/stage_e/routes/link_273.json)|
|`link_274` 本庄城―尾浦城|echigo:岩舩郡 → honshu-area-06:未確定 → honshu-area-06:西田川郡|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_274.json)|
|`link_275` 尾浦城―酒田|honshu-area-06:西田川郡 → honshu-area-06:未確定 → honshu-area-06:東田川郡 → honshu-area-06:未確定|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_275.json)|
|`link_276` 酒田―湊城|honshu-area-06:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:未確定 → honshu-area-03:飽海郡 → honshu-area-03:由利郡 → honshu-area-03:未確定 → honshu-area-03:由利郡 → honshu-area-03:未確定 → honshu-area-03:由利郡 → honshu-area-03:未確定 → honshu-area-03:由利郡 → honshu-area-03:未確定 → honshu-area-03:由利郡 → honshu-area-03:未確定 → honshu-area-03:河邊郡 → honshu-area-03:南秋田郡|33|[区間・通過点](../../data/work/districts/stage_e/routes/link_276.json)|
|`link_277` 湊城―檜山城|honshu-area-03:南秋田郡 → honshu-area-03:山本郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_277.json)|
|`link_278` 檜山城―大館城|honshu-area-03:山本郡 → honshu-area-03:北秋田郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_278.json)|
|`link_279` 横手城―湊城|honshu-area-03:平鹿郡 → honshu-area-03:仙北郡 → honshu-area-03:河邊郡 → honshu-area-03:南秋田郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_279.json)|
|`link_280` 堀越城―三戸城|honshu-area-01:中津軽郡 → honshu-area-01:南津軽郡 → honshu-area-01:未確定 → honshu-area-01:三戸郡|3|[区間・通過点](../../data/work/districts/stage_e/routes/link_280.json)|
|`link_281` 米沢城付近―白石城|honshu-area-06:南置賜郡 → honshu-area-06:東置賜郡 → honshu-area-06:南置賜郡 → honshu-area-06:東置賜郡 → honshu-area-06:南置賜郡 → honshu-area-06:東置賜郡 → honshu-area-06:未確定 → honshu-area-08:刈田郡|7|[区間・通過点](../../data/work/districts/stage_e/routes/link_281.json)|
|`link_282` 石山本願寺―堺|settsu:西成郡 → settsu:住吉郡 → settsu:未確定|2|[区間・通過点](../../data/work/districts/stage_e/routes/link_282.json)|
|`link_283` 高屋城―筒井城|kawachi:古市郡 → kawachi:古市郡 + yamato:未確定（数値接点・通過郡未判定） → yamato:未確定 → yamato:葛下郡 → yamato:未確定 → yamato:葛下郡 → yamato:平群郡 → yamato:葛下郡 → yamato:広瀬郡 → yamato:葛下郡 → yamato:広瀬郡 → yamato:平群郡|10|[区間・通過点](../../data/work/districts/stage_e/routes/link_283.json)|
|`link_284` 筒井城―郡山城|yamato:平群郡 → yamato:添下郡|1|[区間・通過点](../../data/work/districts/stage_e/routes/link_284.json)|
|`link_285` 岸和田城―雑賀・鷺森付近|izumi:南郡 → izumi:日根郡 → izumi:未確定 → kii:名草郡 → kii:未確定|4|[区間・通過点](../../data/work/districts/stage_e/routes/link_285.json)|
