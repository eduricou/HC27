## Mesura el rendiment fotograma a fotograma (escenari perf de main.gd, tools/perf.sh): el
## temps de cada fotograma i com es reparteix (simulació, scripts, preparació del render a
## la CPU i GPU), les estrebades amb el moment del partit en què passen, les compilacions
## de pipelines i la memòria. En acabar, report() en fa el resum i desa un CSV.
## (Performance.TIME_PROCESS no serveix per fotograma: és el màxim de cada segon.)
class_name PerfProbe
extends Node

## Un fotograma més llarg és una estrebada (criteri d'acceptació de la fase 7).
const HITCH_MS := 50.0
## Els fotogrames més llargs que això es guarden amb el context per al resum.
const SLOW_MS := 25.0
## Cada quant es mira la memòria (segons).
const MEM_EVERY := 0.5
## Compilacions de pipelines que fa Godot (comptadors acumulats). Les «draw» es fan en el
## moment de dibuixar i aturen el fotograma; les altres es fan en carregar o en segon pla.
const PIPELINES := [
	Performance.PIPELINE_COMPILATIONS_CANVAS,
	Performance.PIPELINE_COMPILATIONS_MESH,
	Performance.PIPELINE_COMPILATIONS_SURFACE,
	Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
]

var runner: MatchRunner
var cam: CameraRig
## Part del recorregut (menú, partit...): el resum les separa.
var label := "":
	set(v):
		label = v
		if not _labels.has(v):
			_labels.append(v)

var _labels: Array[String] = []
var _t := 0.0
var _mem_t := 0.0
var _time := PackedFloat32Array()
var _frame := PackedFloat32Array()
var _gpu := PackedFloat32Array()
## Scripts (_process de tots els nodes), passos de simulació (_physics_process) i
## preparació del render a la CPU, en ms.
var _proc := PackedFloat32Array()
var _phys := PackedFloat32Array()
var _render := PackedFloat32Array()
var _proc_t0 := 0
var _phys_t0 := 0
var _phys_acc := 0
var _part := PackedInt32Array()
var _draws := PackedInt32Array()
## Compilacions de pipelines de cada fotograma: en dibuixar i les altres.
var _comp_draw := PackedInt32Array()
var _comp_other := PackedInt32Array()
var _last_draw := -1
var _last_other := -1
var _slow: Array[Dictionary] = []
## Esdeveniments dels passos de simulació d'aquest fotograma i del fotograma anterior: el
## temps que es mesura en un fotograma és el que ha trigat l'anterior.
var _events_now: Array[String] = []
var _ctx_prev := {}
var _static_max := 0
var _video_max := 0
var _texture_max := 0


func _ready() -> void:
	# Va després de tots els altres nodes; els senyals process_frame i physics_frame
	# arriben abans que cap.
	process_priority = 1000
	process_physics_priority = 1000
	get_tree().process_frame.connect(func() -> void: _proc_t0 = Time.get_ticks_usec())
	get_tree().physics_frame.connect(func() -> void: _phys_t0 = Time.get_ticks_usec())
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if runner:
		runner.stepped.connect(_on_step)


func _physics_process(_delta: float) -> void:
	_phys_acc += Time.get_ticks_usec() - _phys_t0


func _on_step(events: Array[Dictionary]) -> void:
	for e in events:
		_events_now.append(String(e["type"]))


func _process(delta: float) -> void:
	if label == "":
		return
	var rid := get_viewport().get_viewport_rid()
	var draw := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	var other := 0
	for m: Performance.Monitor in PIPELINES:
		other += int(Performance.get_monitor(m))
	var sample := {
		"phys": _phys_acc / 1000.0,
		"proc": (Time.get_ticks_usec() - _proc_t0) / 1000.0,
		"render":
		(
			RenderingServer.viewport_get_measured_render_time_cpu(rid)
			+ RenderingServer.get_frame_setup_time_cpu()
		),
		"gpu": RenderingServer.viewport_get_measured_render_time_gpu(rid),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"comp_draw": draw - _last_draw if _last_draw >= 0 else 0,
		"comp_other": other - _last_other if _last_other >= 0 else 0,
	}
	_phys_acc = 0
	_last_draw = draw
	_last_other = other
	add_frame(delta * 1000.0, sample)
	_ctx_prev = _context()
	_events_now.clear()
	_mem_t += delta
	if _mem_t >= MEM_EVERY:
		_mem_t = 0.0
		_static_max = maxi(_static_max, OS.get_static_memory_usage())
		_video_max = maxi(
			_video_max, int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		)
		_texture_max = maxi(
			_texture_max, int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
		)


## Apunta un fotograma de `ms` mil·lisegons a la part actual. `sample` porta com es
## reparteix (phys, proc, render, gpu, draws, comp_draw, comp_other; per defecte, 0).
func add_frame(ms: float, sample := {}) -> void:
	_t += ms / 1000.0
	_time.append(_t)
	_frame.append(ms)
	_phys.append(sample.get("phys", 0.0))
	_proc.append(sample.get("proc", 0.0))
	_render.append(sample.get("render", 0.0))
	_gpu.append(sample.get("gpu", 0.0))
	_draws.append(sample.get("draws", 0))
	_comp_draw.append(sample.get("comp_draw", 0))
	_comp_other.append(sample.get("comp_other", 0))
	_part.append(_labels.find(label))
	if ms > SLOW_MS:
		var c := _ctx_prev.duplicate()
		c["t"] = _t
		c["ms"] = ms
		c["part"] = label
		c["comp"] = "%d+%d" % [_comp_draw[-1], _comp_other[-1]]
		_slow.append(c)


func _context() -> Dictionary:
	var c := {"events": ",".join(_events_now)}
	if runner and runner.sim:
		var s := runner.sim.s
		c["state"] = String(s.state)
		c["mode"] = String(s.mode)
	if cam:
		c["cam"] = CameraRig.Mode.keys()[cam.mode]
	return c


## Resum per parts del recorregut i les estrebades. Desa tots els fotogrames a `csv_path`.
## Retorna el nombre d'estrebades de més de HITCH_MS a la part `counted` (el partit).
## Amb process_memory, hi afegeix la memòria del procés (a Windows, amb PowerShell).
func report(csv_path: String, counted := "partit", process_memory := true) -> int:
	var hitches := 0
	for i in _labels.size():
		var idx := _indices(i)
		if idx.is_empty():
			continue
		var fr := _pick(_frame, idx)
		var over50 := _count_over(fr, HITCH_MS)
		if _labels[i] == counted:
			hitches += over50
		var total := 0.0
		for v in fr:
			total += v
		var sorted := fr.duplicate()
		sorted.sort()
		var p99 := sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))]
		print(
			(
				(
					"PERF %s: %d fotogrames en %.1f s · %.0f fps de mitjana · mediana %.2f ms · "
					+ "1 %% més lents %.2f ms (%.0f fps) · màxim %.1f ms · >33 ms: %d · >50 ms: %d"
				)
				% [
					_labels[i],
					fr.size(),
					total / 1000.0,
					fr.size() * 1000.0 / total,
					sorted[sorted.size() / 2],
					p99,
					1000.0 / p99,
					sorted[-1],
					_count_over(fr, 33.4),
					over50,
				]
			)
		)
		print(
			(
				(
					"PERF %s (mitjanes): simulació %.2f ms · scripts %.2f ms · render CPU %.2f ms · "
					+ "GPU %.2f ms · %d crides de dibuix · pipelines compilats en dibuixar: %d · "
					+ "altres: %d"
				)
				% [
					_labels[i],
					_mean(_pick(_phys, idx)),
					_mean(_pick(_proc, idx)),
					_mean(_pick(_render, idx)),
					_mean(_pick(_gpu, idx)),
					roundi(_mean(_pick_int(_draws, idx))),
					_sum_int(_comp_draw, idx),
					_sum_int(_comp_other, idx),
				]
			)
		)
	print(
		(
			"PERF memòria: Godot (estàtica) màx %d MB · vídeo màx %d MB (textures %d MB) · procés %s"
			% [
				_static_max >> 20,
				_video_max >> 20,
				_texture_max >> 20,
				_process_memory() if process_memory else "-",
			]
		)
	)
	_slow.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ms"] > b["ms"])
	for c in _slow.slice(0, 12):
		print(
			(
				"PERF lent: %.1f ms a %.1f s · %s · estat %s · càmera %s · pipelines %s · %s"
				% [
					c["ms"],
					c["t"],
					c["part"],
					c.get("state", "-"),
					c.get("cam", "-"),
					c["comp"],
					c.get("events", ""),
				]
			)
		)
	_save_csv(csv_path)
	return hitches


func _indices(part: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in _part.size():
		if _part[k] == part:
			out.append(k)
	return out


static func _pick(arr: PackedFloat32Array, idx: PackedInt32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in idx:
		out.append(arr[k])
	return out


static func _pick_int(arr: PackedInt32Array, idx: PackedInt32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in idx:
		out.append(arr[k])
	return out


static func _sum_int(arr: PackedInt32Array, idx: PackedInt32Array) -> int:
	var n := 0
	for k in idx:
		n += arr[k]
	return n


static func _count_over(arr: PackedFloat32Array, limit: float) -> int:
	var n := 0
	for v in arr:
		if v > limit:
			n += 1
	return n


static func _mean(arr: PackedFloat32Array) -> float:
	var total := 0.0
	for v in arr:
		total += v
	return total / maxi(1, arr.size())


## Pic de memòria del procés (working set) i memòria privada, en MB. Només a Windows.
func _process_memory() -> String:
	if OS.get_name() != "Windows":
		return "(només a Windows)"
	var out := []
	var cmd := (
		"$p = Get-Process -Id %d; '{0} {1}' -f ($p.PeakWorkingSet64 -shr 20), "
		+ "($p.PrivateMemorySize64 -shr 20)"
	)
	OS.execute("powershell.exe", ["-NoProfile", "-Command", cmd % OS.get_process_id()], out)
	var parts := PackedStringArray()
	if not out.is_empty():
		parts = String(out[0]).strip_edges().split(" ")
	if parts.size() != 2:
		return "(no s'ha pogut llegir)"
	return "pic %s MB · privada %s MB" % [parts[0], parts[1]]


func _save_csv(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No puc desar %s" % path)
		return
	(
		f
		. store_line(
			"t,part,fotograma_ms,simulacio_ms,scripts_ms,render_cpu_ms,gpu_ms,crides,pip_dibuix,pip_altres"
		)
	)
	for k in _frame.size():
		var row := [_time[k], _labels[_part[k]], _frame[k], _phys[k], _proc[k], _render[k]]
		row.append_array([_gpu[k], _draws[k], _comp_draw[k], _comp_other[k]])
		f.store_line("%.3f,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d" % row)
	print("PERF fotogrames: ", ProjectSettings.globalize_path(path))
