# Comparació pas a pas amb la versió web. tools/oracle_web.mjs executa el codi original
# de reference/web/index.html amb el mateix generador d'atzar (mulberry32) i desa
# fotogrames a tests/fixtures/web_oracle.json; aquí es reprodueixen amb MatchSim i han
# de coincidir (tolerància 1e-6). Hi ha dos minuts de joc des del servei, un penal córner
# i dos partits sencers (quarts de 30 s i de 150 s).
extends GdUnitTestSuite

const OracleCheck := preload("res://tools/oracle_check.gd")

var _fx: Dictionary


func before() -> void:
	_fx = OracleCheck.load_fixture()


func _check(run_idx: int) -> void:
	var run: Dictionary = _fx["runs"][run_idx]
	var r := OracleCheck.compare_run(run)
	(
		assert_str(r["first_diff"])
		. override_failure_message("llavor %d: %s" % [run["seed"], r["first_diff"]])
		. is_empty()
	)
	assert_int(r["ok_frames"]).is_equal(r["frames"])


func test_servei_i_primer_gol_llavor_1() -> void:
	_check(0)


func test_un_minut_de_joc_llavor_7() -> void:
	_check(1)


func test_penal_corner_llavor_3() -> void:
	_check(2)


func test_partit_sencer_quarts_de_30_s() -> void:
	_check(3)


func test_partit_sencer_quarts_de_150_s() -> void:
	_check(4)
