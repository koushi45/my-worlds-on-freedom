import json
from pathlib import Path
root=Path(__file__).resolve().parents[1];mp=root/'docs/portraits_history_modern_20261002_55.json';rows=json.loads(mp.read_text(encoding='utf-8'))
designs=[
'Elderly long broad face, fine white beard and moustache, folded black eboshi tied with a white band, light blue patterned kataginu over dark burgundy robe and white collar. Use only the seated elder, ignore armor in the background. Portrait is traditionally identified as Mitamura Saemon; identification with Kunisada is uncertain.',
'Japanese retainer aged 48, oblong face, straight brows, clean shaved cheeks, black compact topknot, muted slate-blue kosode and charcoal kataginu with plain white collar.',
'Japanese lord aged 52, round face, intelligent slightly hooded eyes, neat short dark moustache, receding tied black hair, subdued warm brown robe and grey-green sleeveless over-robe.',
'Japanese retainer aged 39, angular cheekbones, clean shaven, tight small black topknot, dark charcoal simple Japanese lamellar armor with muted blue lacing over indigo cloth.',
'Japanese administrator aged 42, oval face, thoughtful alert eyes, neat small topknot, no beard, earth ochre kosode under muted dark blue kataginu, off-white inner collar.',
'Japanese mature retainer aged 56, sturdy square jaw, light greying moustache, shaved crown and neat knot, understated black-brown lamellar cuirass and rust-brown under-robe.',
'Use ONLY the central man labelled Sadakatsu in this historical group drawing. Long mature face, thin moustache and small chin whiskers, tall black eboshi, dark formal robe with white inner collar. Source is greyscale; dark neutral cloth colors are an artistic inference. Ignore the other men.',
'Japanese noble aged 60, long face, narrow contemplative eyes, thin grey moustache, black eboshi, muted olive formal robe with subtle woven texture and ivory collar.',
'Japanese noble aged 46, rounded cheeks, straight thin brows, short neat moustache, softly folded black eboshi, muted plum brown hitatare with pale inner collar.',
'Maintain historical portrait face: broad oval cheeks, strong dark brows, short thin dark moustache, clean chin, tall folded dark grey eboshi, teal-blue hitatare with dark knotted ties and white collar. Do not replace robes with armor.',
'Japanese noble aged 28, refined oval face, clean shaven, jet-black tied hair with modest eboshi, restrained pale grey-blue formal hitatare with charcoal cord ties, clear intent gaze.',
'Japanese young noble aged 22, soft rectangular face, clean shaven, small black eboshi, muted wine-red formal robe over ivory inner collar, slightly hesitant calm eyes.',
'Use ONLY the UPPER seated armored warrior, not the bald attendant below. Kenshin is the older name Kagetora in the inscription, not the adopted younger Uesugi Kagetora. Mature Japanese face around 49, strong brows, short dark moustache and small goatee, white folded headcloth draped beside cheeks, gold patterned armored breastplate, black lamellar shoulder plates with restrained red lacing, pale blue outer battle coat. Reconstruct the same garment and headwrap, never the distorted seated body.',
'Japanese lord aged 47, lean oval face, slightly arched brows, neat small dark moustache, tied black hair, simple charcoal iron armor with muted dark green lacing over brown cloth.',
'Japanese tea-associated retainer aged 45, slender scholarly face, fine straight brows, clean shaven, small dark eboshi, muted moss-green robe with charcoal collar and modest natural folds.',
'Japanese sword master aged 63, lean sun-weathered face, grey temples and neatly tied dark grey hair, small grey chin beard, plain indigo robe with faded grey collar; calm steady alert eyes and upright posture.',
'Japanese experienced retainer aged 44, broad cheekbones, clean shaven, black topknot, simple black lacquered cuirass with muted rust-red lacing over slate robe.',
'Japanese elder clerical adviser aged 67, shaved head, narrow dignified face, fine grey eyebrows, tiny grey chin whiskers, restrained black-grey clerical robe with dusty ochre mantle.',
'Japanese retainer aged 36, short rectangular face, dark attentive eyes, clean shaven, neat short topknot, plain dark teal kosode and dark charcoal sleeveless kataginu.',
'Japanese clerical retainer aged 43, shaved head, broad oval face, no beard, earnest composed eyes, plain charcoal robe with faded brown draped mantle.',
'Japanese clerical retainer aged 51, shaved head, long triangular face, fine dark moustache, muted tobacco-brown robe with slate grey mantle and pale collar.',
'Japanese clerical retainer aged 38, shaved head, round face, clean shaven, clear steady gaze, subdued black-blue robe and grey-green mantle.',
'Japanese commanding clerical warrior aged 45, shaved head, powerful broad jaw and sharp brows, no beard, plain dark grey robe under simple black Japanese lamellar cuirass with dark red cords, clothing is independent creative interpretation, not a claimed historical suit.',
'Japanese senior clerical retainer aged 54, shaved head, long weathered face, grey moustache and short grey chin beard, muted ochre-brown robe and dark charcoal mantle.',
'Japanese ordinary retainer aged 41, gently square face, thin brows, clean shaven, short black topknot, plain dusty grey robe and dark brown kataginu.',
'Japanese retainer aged 34, angular slim face, clean shaven, neat black knot, plain indigo kosode and muted tan kataginu.',
'Japanese elder retainer aged 58, broad forehead, greying moustache, tied grey-black hair, muted dark olive robe and charcoal over-robe.',
'Japanese administrator aged 52, broad round face, small dark eyes, short greying moustache, neat black topknot with grey temples, simple grey-green kataginu over charcoal robe.',
'Japanese ordinary retainer aged 30, round youthful face, clean shaven, short black topknot, muted umber robe with pale grey collar, quiet mild expression.',
'Japanese ordinary retainer aged 47, long slightly narrow face, clean cheeks and tiny moustache, modest black topknot, muted indigo-brown kosode and grey kataginu.',
'Japanese retainer aged 49, sturdy round jaw, weathered brow, neat short dark beard, black tied hair, simple charcoal lacquered cuirass with dark brown cords over olive cloth.',
'Japanese retainer aged 37, oval face, straight dark brows, clean shaven, compact black topknot, subdued dark burgundy kosode and charcoal sleeveless over-robe.',
'Historical Yoshiiku print shows strongly furrowed brows, broad face with dark moustache and side whiskers, black helmet with simple broad gold crescent-like ornament, green lamellar armor and orange patterned sleeveless outer coat. Treat it as a nineteenth-century imaginative historical print, not a contemporary likeness. Normalize hair, expression and proportions into a natural human face and realistic armor. No spear or action scene.',
'Historical Hidenari portrait: slender oval pale Japanese face, delicate straight brows and small closed lips, clean shaven; black formal kanmuri with vertical crown element, black formal sokutai robe with narrow muted red edging. Natural shoulders instead of the wide geometric garment silhouette.',
'Japanese noble aged 24, narrow oval youthful face, clean shaven, compact black eboshi, subdued deep blue formal hitatare with white inner collar and dark ties.',
'Japanese ordinary retainer aged 42, broad jaw, short black moustache, shaved crown and compact knot, modest charcoal robe and muted olive kataginu.',
'Japanese retainer aged 51, long stern face, short greying goatee, tied dark hair, simple black cuirass with muted blue cords over dusty brown cloth.',
'Japanese ordinary retainer aged 46, round cheeks, fine brows, clean shaven, neat dark topknot, faded slate robe and tan kataginu.',
'Japanese retainer aged 40, narrow firm face, sparse dark moustache, short neat knot, simple brown-black Japanese cuirass with charcoal cord lacing over muted red-brown undercloth.',
'Japanese ordinary retainer aged 56, broad oval face, grey temples, thin grey moustache, small knot, plain earthy green robe and charcoal outer garment.',
'Japanese military retainer aged 36, square jaw, pronounced cheekbones, short dark moustache, black topknot, modest black armor with subdued olive lacing over indigo cloth.',
'Japanese senior retainer aged 57, long lean face, thoughtful stern brows, short grey moustache and chin beard, tied greying hair, simple charcoal lacquered armor with dusty blue cords.',
'Japanese ordinary retainer aged 48, oval face with heavy eyelids, clean shaven, small neat knot, plain muted brown kosode with slate kataginu.',
'Japanese ordinary retainer aged 33, broad open face, clean shaven, compact black knot, plain grey-blue robe and dark olive over-robe.',
'Japanese mature retainer aged 61, narrow face, thick grey brows, fine grey moustache, tied greying hair, subdued charcoal formal robe with brown-green collar.',
'Japanese ordinary retainer aged 39, short angular face, clean shaven, neat black topknot, faded dark plum kosode and plain grey kataginu.',
'Japanese retainer aged 50, broad face, dark moustache, black hair tied close, simple black-brown lamellar armor with understated dark red cord over charcoal cloth.',
'Japanese sword master aged 55, lean face, level focused eyes, short dark-grey moustache, grey temples and neatly tied dark hair, plain earth-grey robe with dark indigo collar; disciplined alert posture.',
'Japanese retainer aged 54, square face, slight grey chin beard, black-grey tied hair, simple black cuirass with brown lacing and slate blue under-robe.',
'Use the historical Nagahide portrait face, hair, headgear and clothes exclusively; preserve its small moustache and formal robe structure. Describe verified specifics after inspecting the reference.',
'Historic Nomi Munekatsu portrait: bare bald head, elderly long Japanese face, fine grey brows, sparse short white moustache and chin whiskers, black lamellar cuirass and shoulder guards with restrained ochre details over white chest cloth. Natural shoulder width. Do not copy the exaggerated seated body.',
'Japanese retainer aged 43, lean oval face, short dark moustache, neat black knot, modest charcoal armor with dark ochre cord lacing over muted brown cloth.',
'Japanese ordinary retainer aged 35, square youthful face, clean shaven, dark tied hair, simple blue-grey robe and dark brown kataginu.',
'Japanese elder lord aged 59, rounded long face, grey moustache and small grey chin beard, tied grey-black hair, restrained muted olive formal hitatare and small black eboshi.',
'Japanese ordinary retainer aged 46, narrow face, clean shaven, dark greying temples and compact knot, modest brown robe and charcoal grey kataginu.'
]
assert len(designs)==55
for r,d in zip(rows,designs):
    r['appearance_design']=d
    if not r['reference_paths']:
        r['basis']='No personally identified historical face/costume image verified in the recorded searches; independent fictional appearance, not a likeness reconstruction.'
        r['rights']='No external appearance image input.'
    elif r['index']==0:
        r['basis']='Traditional Mitamura Saemon portrait, owned by Denshoji; equation with Kunisada uncertain; undated historical artwork, not a confirmed contemporary likeness.'
    elif r['index']==6:
        r['basis']='Sadakatsu, central labelled figure in historical Uesugi lord portraits; Uesugi Museum; date unverified; greyscale colors inferred.'
    elif r['index']==9:
        r['basis']='Kagekatsu historical portrait owned by Uesugi Shrine; possibly later nineteenth century, not contemporary.'
    elif r['index']==32:
        r['basis']='Taiheiki Eiyuden no.17, Nakagawa Kiyohide, Utagawa Yoshiiku, 1867; imaginative posthumous historical print, not a verified lifetime likeness.'
    elif r['index']==33:
        r['basis']='Nakagawa Hidenari portrait, Hekiunji; historical portrait, date unverified.'
    elif r['index']==50:
        r['basis']='Nomi Munekatsu historical portrait owned by Shounji; date unverified, not a verified lifetime likeness.'
    dramatic=r['ability']>=120
    framing='Dramatic three-quarter chest turn, confident chin and commanding intense gaze, heroic but anatomically natural.' if dramatic else ['Quiet upright three-quarter bust, composed gaze slightly left.','Natural chest turned slightly right with face toward viewer, attentive gentle gaze.','Calm chest angled left, steady level eyes toward viewer.'][r['index']%3]
    source='Reference image 1 is '+r['basis']+' Use it ONLY for this named person\'s facial features, hair, headgear and clothes. Do not imitate its body proportions, posture, composition, lettering, background or flat ink technique. ' if r['reference_paths'] else 'No historical appearance image is verified for this person. The following face, age and costume are an independent creative interpretation appropriate to a Japanese Sengoku retainer, not a claim of his actual appearance. '
    r['prompt']=f'Create one polished modern Japanese Sengoku strategy-game character icon representing {r["name"]}. {source}Appearance: {d} Render as realistic Western oil painting with refined painterly strokes, three-dimensional natural Japanese facial anatomy, realistic neck and shoulder proportions, beautiful clear facial planes and natural eyes, detailed cloth weave and restrained metal highlights. Western oil technique only, not Western ethnicity. {framing} Game five-ability total {r["ability"]}/150; high-ability dramatic threshold 120, otherwise modest dignified presentation. Bust from head to mid chest, entire head and headgear contained, natural shoulders, upper transparent margin 5 percent, readable face. Single person only. Square 1:1, target 512 by 512, genuine transparent RGBA PNG, crisp clean alpha silhouette. No scenery, no painted checkerboard, no solid background, no halo, no frame, no logos, no watermark, no Japanese or other text, no modern fashion, no fantasy decorations. Do not reference any commercial game artwork or character designs.'
    r['status']='ready'
mp.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(rows,ensure_ascii=True))
