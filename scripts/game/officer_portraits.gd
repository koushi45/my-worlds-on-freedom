extends RefCounted

## Portrait assets are keyed by the stable officer registry ID so that aliases and
## later name changes do not break the association.
const PATH_BY_OFFICER_ID := {
	"officer_q171411": "res://assets/officers/portraits/oda_nobunaga.png",
	"officer_q187550": "res://assets/officers/portraits/hashiba_hideyoshi.png",
	"officer_q171977": "res://assets/officers/portraits/tokugawa_ieyasu.png",
	"officer_q311080": "res://assets/officers/portraits/uesugi_kenshin.png",
	"officer_q276404": "res://assets/officers/portraits/takeda_shingen.png",
	"officer_q1156545": "res://assets/officers/portraits/mori_motonari.png",
	"officer_q1070082": "res://assets/officers/portraits/chosokabe_motochika.png",
	"officer_q1156288": "res://assets/officers/portraits/shimazu_yoshihiro.png",
	"officer_q943643": "res://assets/officers/portraits/hojo_ujiyasu.png",
	"officer_q1054305": "res://assets/officers/portraits/imagawa_yoshimoto.png",
}

static func texture_for(officer_id: String) -> Texture2D:
	var path: String = PATH_BY_OFFICER_ID.get(officer_id, "")
	return load(path) as Texture2D if not path.is_empty() else null
