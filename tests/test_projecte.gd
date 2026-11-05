# Prova d'exemple de la fase 0: comprova la configuració bàsica del projecte
# que demana el pla (secció 9, fase 0).
extends GdUnitTestSuite

const SimStats := preload("res://tools/sim_stats.gd")


func test_fisica_a_60_hz() -> void:
	assert_int(Engine.physics_ticks_per_second).is_equal(60)


func test_finestra_1080p() -> void:
	assert_int(ProjectSettings.get_setting("display/window/size/viewport_width")).is_equal(1920)
	assert_int(ProjectSettings.get_setting("display/window/size/viewport_height")).is_equal(1080)


func test_renderitzador_forward_plus() -> void:
	var metode: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert_str(metode).is_equal("forward_plus")


func test_nom_del_projecte() -> void:
	var nom: String = ProjectSettings.get_setting("application/config/name")
	assert_str(nom).is_equal("Estic Hoquei Herba")


func test_escena_principal_existeix() -> void:
	var escena: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_bool(ResourceLoader.exists(escena)).is_true()


func test_resum_estadistiques() -> void:
	# El resum de tools/sim_stats.gd ha de sumar els dos equips i fer la mitjana.
	var stats_a := {
		"shots": [5, 3], "on": [2, 1], "pcs": [2, 2], "fouls": [1, 0], "poss": [30.0, 10.0]
	}
	var stats_b := {
		"shots": [1, 1], "on": [1, 0], "pcs": [0, 0], "fouls": [2, 2], "poss": [10.0, 30.0]
	}
	var partits: Array[Dictionary] = [
		{"score": [2, 1], "stats": stats_a},
		{"score": [0, 1], "stats": stats_b},
	]
	var resum: Dictionary = SimStats.summarize(partits)
	assert_int(resum["n"]).is_equal(2)
	assert_float(resum["mean"]["goals"]).is_equal_approx(2.0, 0.0001)
	assert_float(resum["mean"]["shots"]).is_equal_approx(5.0, 0.0001)
	assert_float(resum["mean"]["poss_iluro"]).is_equal_approx(0.5, 0.0001)
	assert_float(resum["sd"]["shots"]).is_equal_approx(3.0, 0.0001)


func test_comparacio_toleranca() -> void:
	var web := {"goals": 3.0, "shots": 10.0, "pcs": 4.0}
	var dins: Dictionary = SimStats.compare({"goals": 3.5, "shots": 8.5, "pcs": 4.0}, web)
	assert_bool(dins["ok"]).is_true()
	var fora: Dictionary = SimStats.compare({"goals": 3.0, "shots": 12.5, "pcs": 4.0}, web)
	assert_bool(fora["ok"]).is_false()
	assert_bool(fora["metriques"]["shots"]["ok"]).is_false()
