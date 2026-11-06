## Presets de qualitat gràfica. La fase 3 en fa servir dos per als criteris d'acceptació
## (Baixa: 60 fps a 1080p amb una gràfica integrada; Alta: 144 fps a 1440p amb una GPU
## mitjana). La fase 7 els ajustarà. Es trien al menú d'opcions (GameSettings) o amb
## `-- --quality=<nom>`, que mana sobre les opcions; per defecte, alta.
class_name Quality
extends RefCounted

const DEFAULT := "alta"
const NAMES: Array[String] = ["baixa", "mitjana", "alta", "ultra"]

## Mesures (tools/bench.sh, Intel Arc 130V integrada): vegeu docs/decisions/0005.
## msaa: Viewport.MSAA_* · fxaa: suavitzat de pantalla barat · scale: escala 3D
## sun_size/sun_splits/sun_dist: ombra del sol · spot_shadows/spot_atlas: ombres dels
## focus de nit · soft: qualitat del filtre de les ombres (RenderingServer.SHADOW_QUALITY_*)
## ssao/ssil/glow: efectes de l'entorn.
const PRESETS := {
	"baixa":
	{
		"msaa": Viewport.MSAA_DISABLED,
		"fxaa": true,
		"scale": 1.0,
		"sun_size": 2048,
		"sun_splits": 2,
		"sun_dist": 110.0,
		"spot_shadows": true,
		"spot_atlas": 2048,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"ssao": false,
		"ssil": false,
		"glow": true,
	},
	"mitjana":
	{
		"msaa": Viewport.MSAA_2X,
		"fxaa": false,
		"scale": 1.0,
		"sun_size": 4096,
		"sun_splits": 3,
		"sun_dist": 120.0,
		"spot_shadows": true,
		"spot_atlas": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"ssao": false,
		"ssil": false,
		"glow": true,
	},
	"alta":
	{
		"msaa": Viewport.MSAA_2X,
		"fxaa": false,
		"scale": 1.0,
		"sun_size": 4096,
		"sun_splits": 4,
		"sun_dist": 130.0,
		"spot_shadows": true,
		"spot_atlas": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"ssao": true,
		"ssil": false,
		"glow": true,
	},
	"ultra":
	{
		"msaa": Viewport.MSAA_4X,
		"fxaa": false,
		"scale": 1.0,
		"sun_size": 8192,
		"sun_splits": 4,
		"sun_dist": 150.0,
		"spot_shadows": true,
		"spot_atlas": 8192,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"ssao": true,
		"ssil": true,
		"glow": true,
	},
}


static func preset(name: String) -> Dictionary:
	if not PRESETS.has(name):
		push_warning("Qualitat desconeguda «%s»: faig servir «%s»" % [name, DEFAULT])
		name = DEFAULT
	var q: Dictionary = PRESETS[name].duplicate()
	q["name"] = name
	return q


## Canvia valors d'un preset a partir d'un text "clau=valor,clau=valor" (proves de
## rendiment: tools/bench.sh amb --qset). Els valors prenen el tipus del preset.
static func override(q: Dictionary, spec: String) -> void:
	for kv in spec.split(",", false):
		var parts := kv.split("=")
		if parts.size() != 2 or not q.has(parts[0]):
			push_warning("--qset: no entenc «%s»" % kv)
			continue
		var old: Variant = q[parts[0]]
		match typeof(old):
			TYPE_BOOL:
				q[parts[0]] = parts[1] in ["1", "true", "si", "sí"]
			TYPE_INT:
				q[parts[0]] = int(parts[1])
			TYPE_FLOAT:
				q[parts[0]] = float(parts[1])
			_:
				q[parts[0]] = parts[1]


## Aplica el preset al viewport i al servidor de render. La part de l'estadi (llums i
## entorn) la fa Stadium.apply_quality().
## Amb q["fsr"] < 1 (opcions), el 3D es dibuixa a aquesta escala i FSR 2.2 l'escala i el
## suavitza (substitueix l'MSAA i l'FXAA del preset).
static func apply_viewport(q: Dictionary, vp: Viewport) -> void:
	var fsr: float = q.get("fsr", 1.0)
	if fsr < 0.999:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		vp.scaling_3d_scale = fsr
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = q["scale"]
		vp.msaa_3d = q["msaa"]
		vp.screen_space_aa = (
			Viewport.SCREEN_SPACE_AA_FXAA if q["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
		)
	vp.positional_shadow_atlas_size = q["spot_atlas"]
	RenderingServer.directional_shadow_atlas_set_size(q["sun_size"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(q["soft"])
	RenderingServer.positional_soft_shadow_filter_set_quality(q["soft"])
