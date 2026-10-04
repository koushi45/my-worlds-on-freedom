from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=(ROOT/'tools/portraits_history102_finish.py').read_text(encoding='utf-8').replace('102','116').replace('==26','==29').replace('viewed=26','viewed=29').replace('SHEETS_26_OK','SHEETS_29_OK').replace('背景26枚','背景29枚')
a=p.index("'','佐々成政は")
b=p.index("'','## 一覧'",a)
p=p[:a]+"'','北条氏康は史料の顔・礼服を保ち、姿勢と視線で威厳を強める。北条氏政・氏直は1803年法雲寺本を入力し、早雲寺本とは区別。幻庵は祐泉寺本を用い、嫡男時長像を除外。千葉親胤は久保神社の少年武者像。古田重然は1702年の無彩色木版本を用い、2020年彩色画像は不採用。土岐頼純は同定異説を伴う伝来模本として留保する。堀尾吉晴は1611年春光院本で、1961年油彩は不採用。堀直寄は1636年の寿像、堀秀政は長慶寺の法体像。礼装・法体を創作甲冑へ変えない。','','能力値はofficers_1546.jsonの5能力合計150点を使用。北条氏康134点のみ高能力演出の目安120点以上。ほか115名は120点未満で、数値に合わせて表情・姿勢・照明を控える。ゲーム能力値は変更しない。',"+p[b+3:]
p=p.replace('前回88名・55名と従来50名を維持','前回102名・88名・55名と従来の非商用肖像を維持（北条氏康は今回の新画像へ更新）')
p=p.replace(".replace('SHEETS_22_OK','SHEETS_26_OK')",".replace('SHEETS_22_OK','SHEETS_29_OK')")
p=p.replace("for p,markers in logs.items():","logs['builds/qa/history116_prior102.log']=['HISTORICAL_MODERN_PORTRAITS_102_OK']\n    for p,markers in logs.items():")
p=p.replace('prior88_source_ui=True,','prior102_source_ui=True,prior88_source_ui=True,')
(ROOT/'tools/portraits_history116_finish.py').write_text(p,encoding='utf-8')
print('116 finisher prepared')
