> 2026-10-02：商用ゲーム画像を参照した旧素材は使用を取り消し、該当する実ファイル・キャッシュ・ゲーム登録を削除した。この文書は過去の制作経緯の記録であり、再生成・再採用の指示ではない。対象：`hachinohe_masahide.png`, `kanematsu_masayoshi.png`, `nyuta_chikazane.png`, `rokkaku_sadayori.png`, `rokkaku_yoshiharu.png`, `rokkaku_yoshikata.png`。独立に作り直した `_oil_` 版の採用記録は別文書を参照。

# Officer portraits: batch 23

Ten square transparent PNG portraits are saved under `assets/officers/portraits/` and registered by officer ID in `scripts/game/officer_portraits.gd`. Each was created with its own built-in image-generation call. The six verified exact-person game faces were supplied directly as image references; reference images are not shipped with the game. The other four portraits are explicitly imaginative reconstructions, not claimed historical likenesses.

| Officer | Final PNG | Direct image reference | Treatment |
| --- | --- | --- | --- |
| 入来院重聡 | `irikiin_shigetoshi.png` | No verified exact-person historical portrait or game image found | Imaginative reconstruction; older Satsuma commander |
| 入田親誠 | `nyuta_chikazane.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1579) | Exact-person game face; high topknot, moustache, ochre and burgundy robes |
| 八戸政栄 | `hachinohe_masahide.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/1637) | Exact-person game face; black court hat, moustache and goatee, pale lavender robe |
| 六角定治 | `rokkaku_sadaharu.png` | No verified exact-person historical portrait or game image found | Imaginative reconstruction; dark eboshi and formal robe |
| 六角定頼 | `rokkaku_sadayori.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/2180) | Exact-person game face; white headband, dark soft cap, red and white armor |
| 六角義介 | `rokkaku_yoshisuke.png` | No verified exact-person historical portrait or game image found | Imaginative reconstruction; young warrior in dark green |
| 六角義実 | `rokkaku_yoshizane.png` | No verified exact-person historical portrait or game image found | Imaginative reconstruction; bearded warrior in oxblood armor |
| 六角義治 | `rokkaku_yoshiharu.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/2182) | Exact-person game face; tall court cap, tan robe, purple collar |
| 六角義賢 | `rokkaku_yoshikata.png` | [Nobunaga's Ambition: Shinsei, listed as 六角承禎](https://altema.jp/nobunagashinsei/busyo/2181) | Exact-person game face; shaved head, strong brows, ornate brown and purple outer robe |
| 兼松正吉 | `kanematsu_masayoshi.png` | [Nobunaga's Ambition: Shinsei](https://altema.jp/nobunagashinsei/busyo/659) | Exact-person game face; huge gold crescent and disc helmet, blue-purple and white armor |

The [Shiga Cultural Properties Institute](https://www.shiga-bunkazai.jp/shigabun-shinbun/recommended-relics/%E8%AA%BF%E6%9F%BB%E5%93%A1%E3%81%AE%E3%81%8A%E3%81%99%E3%81%99%E3%82%81%E3%81%AE%E9%80%B8%E5%93%81%E2%84%96391-%E5%94%AF%E4%B8%80%E8%A6%8B%E3%82%8B%E3%81%93%E3%81%A8%E3%81%AE%E3%81%A7%E3%81%8D/) notes that the only known portrait among Rokkaku heads was that of Ujiyori, now of unknown whereabouts. None of the game images above is presented as a historical likeness.

## Generation constraints

Built-in image-generation mode, one call per portrait. For each sourced officer, the exact-person image was provided via `referenced_image_paths` and the prompt called out facial proportions, grooming, headgear, and garment colors to carry into a modern, realistic rendering. The four unsourced officers received text-only, separately differentiated prompts so another person's face would not be misrepresented as theirs. Every prompt requested 1:1 genuine alpha PNG, upper-body cutout, complete head, hands out of frame, no scenery or text, and modern cinematic realistic detail rather than period painting style.
