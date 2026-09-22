# 1546年・所属追加調査 第2組100人

前回100人と重複しない未配置者100人を対象とする。配置先を表せない若狭・志摩・対馬・蝦夷の6人は選定から外し、別の6人を加えた。除外者は報告書・基準台帳に記録し、変更しない。

保存済み人物紹介の前半生・系譜・就任年を個別に再読し、一部は自治体・博物館の解説で補った。全件が同時代史料で確定した調査ではない。推測による所属、出生伝承、後年の活動地を利用したゲーム配置を個別に明記する。

- 100人に立場・配置郡を設定。所属家は44人、所属不明を維持する人物は56人。
- 立場は元服前80人、浪人12人、大名5人、大名家一門2人、武将1人。
- 幼少の家族配置と出仕を区別。幼少当主は大名のまま出仕無効。1544年元服の三木通秋は年齢だけで元服前に戻さない。
- 郡は現在の表示区画。葉栗・佐東など対応しない歴史郡は代替区画であることを注記する。名前の一致だけで九戸城を九戸郡、沼田小早川氏を安芸沼田郡に配置しない。
- 生年・同定の留保は残す。成田長親、増田長盛の1546年出生説や上杉朝定の年内没、実在に疑問がある小島弥太郎などは配置しても自動出仕を無効にする。
- 家系・父母子・能力値は変更しない。歴史所属台帳も保持し、ゲーム設定への追加層として適用する。

## 入力と再生成

`tools/officers/affiliation_batch2_selection.json` が固定の対象100人。
`tools/officers/affiliation_batch2_decisions.txt` が人物別の判断。
`tools/officers/apply_affiliation_batch2.py` が家中の本拠圏、補足資料、配置・表示の生成を担当する。

```powershell
python tools/officers/build_affiliations.py
python tools/officers/build_roster.py
python -m unittest discover -s tests/officers
python tools/officers/check_html.py
godot_console --headless --path . --script tools/officers/smoke.gd
```

`data/master/officers/affiliation_batch2_research.json` に変更前後・出典URL・保存資料ハッシュ・個別判断を保存し、`docs/officers/affiliation_research_next_100.html` に出力する。

既存の家の配置先プールは拡張せず、人数が少ない郡から固定シードで選ぶ。新規13家は個別の本拠圏1郡を登録し、郡全体の歴史的所有権を認定するものではない。他1498人を動かさないことを生成時とテストで検証する。

## 基準の更新と差し戻し

`affiliation_batch2_baseline.json` が更新前1598人の設定と保護対象ファイルのハッシュを保持する。家系の既存検証が所属変更を検出するため、今回許可された100人の変更に限り `lineages_baseline.json` の `affiliations_sha256` を更新した。旧値・新値・正規化方式は `affiliation_batch2_migration.json` に記録する。他の基準値は変更しない。

第2組を差し戻す場合は `apply_affiliation_scenario.py` の第2組呼び出しを外して再生成し、基準ハッシュを移行記録の旧値へ戻す。第2組のリンク・報告書も同時に取り下げる。前回100人の元入力を編集する必要はない。
