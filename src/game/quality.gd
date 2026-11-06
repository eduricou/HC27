## Presets de qualitat gràfica (fase 7, docs/decisions/0010). Objectius: Baixa, 60 fps a
## 1080p amb una gràfica integrada; Alta, 144 fps a 1440p amb una GPU mitjana. Es trien al
## menú d'opcions (GameSettings) o amb `-- --quality=<nom>`, que mana sobre les opcions. El
## primer cop que s'obre el joc es tria segons la gràfica (for_adapter_type()).
## L'escala FSR 2.2 no és del preset sinó una opció a part: en una integrada a 1080p fa anar
## el joc més lent (decisió 0010).
class_name Quality
extends RefCounted

const DEFAULT := "alta"
## Mida del mapa d'ombres de la llum que no es fa servir (el sol de nit, els focus de tarda).
const UNUSED_ATLAS := 256
const NAMES: Array[String] = ["baixa", "mitjana", "alta", "ultra"]

## Mesures (tools/bench.sh i tools/perf.sh, Intel Arc 130V integrada): decisions 0005 i 0010.
## msaa: Viewport.MSAA_* · fxaa: suavitzat de pantalla barat · scale: escala 3D
## sun_size/sun_splits/sun_dist: ombra del sol · spot_shadows: quants focus de nit fan
## ombra (dels 6; Stadium.SPOT_SHADOW_ORDER) · spot_atlas: mapa de les ombres dels focus
## soft: qualitat del filtre de les ombres (RenderingServer.SHADOW_QUALITY_*)
## ssao/ssil/glow: efectes de l'entorn · lod: llindar del LOD de les malles, en píxels
## (Viewport.mesh_lod_threshold; més alt, abans es passa a una malla més simple).
const PRESETS := {
	"baixa":
	{
		"msaa": Viewport.MSAA_DISABLED,
		"fxaa": true,
		"scale": 1.0,
		"sun_size": 2048,
		"sun_splits": 2,
		"sun_dist": 110.0,
		"spot_shadows": 2,
		"spot_atlas": 2048,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"ssao": false,
		"ssil": false,
		"glow": true,
		"lod": 4.0,
	},
	"mitjana":
	{
		"msaa": Viewport.MSAA_2X,
		"fxaa": false,
		"scale": 1.0,
		"sun_size": 4096,
		"sun_splits": 3,
		"sun_dist": 120.0,
		"spot_shadows": 4,
		"spot_atlas": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"ssao": false,
		"ssil": false,
		"glow": true,
		"lod": 2.0,
	},
	"alta":
	{
		"msaa": Viewport.MSAA_2X,
		"fxaa": false,
		"scale": 1.0,
		"sun_size": 4096,
		"sun_splits": 4,
		"sun_dist": 130.0,
		"spot_shadows": 6,
		"spot_atlas": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"ssao": true,
		"ssil": false,
		"glow": true,
		"lod": 1.0,
	},
	"ultra":
	{
		"msaa": Viewport.MSAA_4X,
		"fxaa": false,
		"scale": 1.0,
		"sun_size": 8192,
		"sun_splits": 4,
		"sun_dist": 150.0,
		"spot_shadows": 6,
		"spot_atlas": 8192,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"ssao": true,
		"ssil": true,
		"glow": true,
		"lod": 0.5,
	},
}


## Preset del primer cop que s'obre el joc, segons el tipus de gràfica
## (RenderingServer.get_video_adapter_type()): Alta amb una de dedicada; Baixa amb una
## d'integrada o desconeguda, que és la que té l'objectiu de 60 fps a 1080p.
static func for_adapter_type(type: RenderingDevice.DeviceType) -> String:
	return "alta" if type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU else "baixa"


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


## Ajusta el preset al renderitzador. El Compatibility (OpenGL 3.3, l'accés directe per a
## gràfiques antigues) no té FXAA, FSR, SSAO ni SSIL: hi posa MSAA 2x en lloc de l'FXAA i
## treu la resta, perquè Godot no avisi a cada canvi.
static func adapt_to_renderer(q: Dictionary, method: String) -> void:
	if method != "gl_compatibility":
		return
	if q["fxaa"]:
		q["fxaa"] = false
		q["msaa"] = maxi(q["msaa"], Viewport.MSAA_2X)
	q["fsr"] = 1.0
	q["ssao"] = false
	q["ssil"] = false


## Aplica el preset al viewport i al servidor de render. La part de l'estadi (llums,
## entorn i mapes d'ombres) la fa Stadium.apply_quality().
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
	vp.mesh_lod_threshold = q["lod"]
	RenderingServer.directional_soft_shadow_filter_set_quality(q["soft"])
	RenderingServer.positional_soft_shadow_filter_set_quality(q["soft"])


## Mapes d'ombres: només el de la llum que es fa servir (el sol de tarda o els focus de nit)
## té la mida del preset; l'altre es deixa petit perquè no ocupi memòria. Amb Ultra, els dos
## de 8192 junts ocupen 256 MB (fase 7).
static func apply_shadow_atlases(q: Dictionary, vp: Viewport, night: bool) -> void:
	vp.positional_shadow_atlas_size = q["spot_atlas"] if night else UNUSED_ATLAS
	RenderingServer.directional_shadow_atlas_set_size(
		UNUSED_ATLAS if night else q["sun_size"], true
	)
