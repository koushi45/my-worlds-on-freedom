import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'docs/portraits_history_modern_20261003_102.json'
rows=json.loads(p.read_text(encoding='utf-8'))
faces=['broad oval face, gently wide nose and thoughtful narrow eyes','long lean face, high cheekbones, straight nose and level eyebrows','soft square face, rounded jaw, low cheekbones and slightly arched brows','short rounded face, broad forehead, small straight nose and patient eyes','angular face, defined cheekbones, slender nose and thick calm eyebrows','narrow oval face, pronounced chin, slightly rounded nose and steady dark eyes','rectangular face, strong natural jaw, fine straight eyebrows and deep-set eyes','full face, warm cheek contours, broad nose and watchful eyes','long oval face, prominent natural cheekbones, curved brows and small mouth']
cloth=['muted ink-blue kosode under charcoal sleeveless cloth robe','plain russet-brown kosode with layered pale-grey collar','subdued olive-brown woven robe over a cream inner collar','dark plum-brown kosode beneath a soft charcoal outer coat','simple slate-grey kosode under a dull indigo short outer robe','muted ochre-brown robe with a dark brown folded collar','deep navy robe with restrained brown cloth layers','dark moss-green kosode under a smoke-grey outer garment','warm charcoal robe with an understated grey-blue folded collar','plain brown kosode under a dark indigo cloth coat','subdued blue-grey robe with a warm ivory undercollar']
prefix='Use case: historical-scene. Asset: individual modern Japanese Sengoku officer game portrait. '
suffix=' Realistic Western oil-painted portrait technique with fine restrained brushwork, polished contemporary realistic game character presentation, natural Japanese facial anatomy and lifelike age and skin, carefully painted eyes and three-dimensional cloth. Soft upper-side key light with gentle fill, no theatrical halo. Historical sources guide face and clothing only; do not imitate historical artwork body ratios, posture, backgrounds or flat drawing. Realistic human skull, neck and shoulder proportions. Bust-up only, complete hair and headgear, comfortably contained natural shoulders; reserve an empty 6% transparent top margin, torso may end at canvas bottom. Square 1:1 true transparent-background RGBA PNG. No writing or text in any language, Japanese characters, scenery, solid or checkerboard background, independent crests, logos, frame, UI, watermark, colored rim glow, weapons or commercial-game character designs. '
for r in rows:
    i=r['index'];r['search_queries']=[f'"{r["name"]}" 肖像 所蔵']
    if r['status']=='generated':continue
    age=33+(i*7)%32
    facial=faces[i%len(faces)]
    hair=['shaved-front Japanese period topknot, clean-shaven cheeks and chin','Japanese period topknot, short modest moustache and otherwise clean-shaven','Japanese period topknot, a fine moustache and short neat chin beard','Japanese period topknot, sparse natural moustache, no chin beard'][i%4]
    clothing=cloth[i%len(cloth)]
    if i==58:hair='black court eboshi completely contained, clean-shaven face';clothing='plain subdued olive-grey court robe, white folded collar; no invented decorative insignia'
    if i==74:hair='shaved monk head, clean-shaven face';clothing='dark brown Buddhist robe with modest grey-brown cloth layers'
    pose=['relaxed shoulders slightly angled right, face gently turned toward viewer, calm attentive eyes','gentle left three-quarter shoulders, head almost frontal, composed thoughtful gaze','nearly frontal chest, face turned a little left, quiet resolute expression','right three-quarter bust, level chin, calm naturally alert gaze'][i%4]
    r['basis']='検索で本人と出所・年代・利用条件を確認できる外見史料をまだ採用していない。以下は独自の創作であり、本人の容貌の確定的復元ではない。'
    r['creative_note']=f'年齢{age}歳前後、顔、髪・髭、衣服を創作。能力{r["ability"]}/150、120未満の控えめな胸像演出。'
    r['prompt']=prefix+f'Subject: {r["name"]}. No authenticated usable appearance reference has been adopted from the recorded historical searches, so this is an original imaginative representation, never a claimed likeness reconstruction. One historical Japanese man about {age}, {facial}; {hair}. Clothing: {clothing}. Pose: {pose}.'+suffix+f'Current game ability total {r["ability"]}/150, below high-ability threshold 120: restrained ordinary dignified facial expression, modest clothing and pose; keep professional image quality.'
p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Prepared distinct creative prompts; historical candidates must be verified and replace these prompts before source-based generation.')
