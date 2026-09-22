# 近畿・中部：国境線作業の途中記録

状態: **未完成・未承認。本番利用不可。**

## 作成したもの

`data/work/political/kinki_chubu_registration/` 配下に地域別対応点と画像座標トレースを保存。

- `kinki/`、`chubu/` の `warped_raster.png`: 画像側を地域別の区分線形変換で変形した結果。
- 各 `border_review_candidate.gpkg`: 原画像の確認可能な線、変換線、陸地クリップ後の線、正本海岸、対応点、変換三角形。
- 各 `review_layer.json`: 正本海岸ID・点列と国境線候補。**国別面と所属海岸区間は未確定のため空**。
- 各 `qa/01_actual_warp.png`: 黒い変形画像と桃色の正本海岸。
- 各 `qa/02_raster_vector_overlay.png`: 上記に水色の国境線候補を重ねる。
- 各 `qa/03_boundaries.png`: 抽出線だけを表示。
- 各 `qa/04_names_unconfirmed.png`: 未確定の国名ラベル配置。確定した国領域ではない。
- 各 `qa/05_source_trace.png`: 原画像とのトレース比較。

比較用の便宜上、若狭・伊勢・志摩を近畿側、越前以北・東海・甲信越を中部側に置いた。現代の地方区分をゲーム属性として追加したものではない。

## 保全

変形対象は画像のみ。陸地基盤、正本海岸、入力画像、承認済み九州・四国・中国を含む本番レジストリのSHA-256は変更前後で一致。
既存本番スクリプト、承認済み正本、Windowsビルドには変更を加えていない。

## 未完了事項

1. 近畿の山城・河内・大和付近などの多国接点と国名対応の精査。
2. 中部の内陸境界、越後端部などのトレース経路の修正。
3. 湾・半島で生じる画像海岸と正本海岸の差の追加補正。
4. 既存中国地方と近畿、近畿と中部の共有線を同一線へ統合。現在の独立した候補をそのまま接続しない。
5. 共有境界と正本海岸区間による閉じた面、国の所有、クリック判定の構築・検査。
6. 佐渡・淡路などの島所属と別補正。

補助トレースが白地を直線で横切る区間は出力せず、未確定として記録している。線の欠けは確定した境界の欠損ではなく、作業未完了を表す。参照点の墨線への移動、除外区間、海側への逸脱は各 `registration_report.json` に残してある。

`validation_report.json` の `partial_candidate_integrity=passed` はハッシュ保全、正本海岸点列の一致、陸地内の線、変換三角形の非反転・往復変換の検査のみ。**国境の完成・史実精度・政治領域の妥当性が合格した意味ではない**。

## 再生成と検査

```powershell
python tools/build_kinki_chubu_border_review.py --region all
python tools/verify_kinki_chubu_border_review.py
```

`tools/build_kinki_chubu_registration.py` の領域生成側は未完成であり、レビュー生成は上記 `border_review` 側を使う。
