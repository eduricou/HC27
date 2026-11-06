# Proves de la pilota i del pal que no necessiten pantalla: la mida de la pilota (real de
# prop, mai massa petita de lluny), com roda i gira, i el pal fet amb codi (el cap pla a
# terra i la pilota tocant-ne la cara).
extends GdUnitTestSuite

var _cam: Camera3D


func before_test() -> void:
	_cam = auto_free(Camera3D.new())
	add_child(_cam)
	_cam.fov = 30.0
	_cam.current = true


func _ball() -> BallView:
	var b: BallView = auto_free(BallView.new())
	add_child(b)
	return b


func _look_from(dist: float) -> void:
	_cam.look_at_from_position(Vector3(0.0, dist * 0.5, dist), Vector3.ZERO, Vector3.UP)


# --- Pilota -----------------------------------------------------------------------------


func test_la_pilota_te_la_mida_real_de_prop_i_es_veu_de_lluny() -> void:
	var b := _ball()
	_look_from(3.0)
	b.place(Vector3.ZERO, 0.0, true)
	assert_float(b.radius).is_equal(BallView.RADIUS)
	# El centre, a un radi de terra.
	assert_float(b.position.y).is_equal_approx(BallView.RADIUS, 1e-5)
	_look_from(80.0)
	b.place(Vector3.ZERO, 0.0, true)
	assert_float(b.radius).is_greater(BallView.RADIUS * 2.0)
	# A la pantalla fa MIN_SCREEN de l'alçada de la imatge.
	var d := _cam.global_position.distance_to(Vector3.ZERO)
	var frac := b.radius / (d * tan(deg_to_rad(_cam.fov) * 0.5))
	assert_float(frac).is_equal_approx(BallView.MIN_SCREEN, 1e-4)


func test_la_pilota_roda_sense_lliscar() -> void:
	var b := _ball()
	_look_from(3.0)
	b.place(Vector3.ZERO, 1.0 / 60.0, true)
	var step := 0.005
	for i in 10:
		b.place(Vector3((i + 1) * step, 0.0, 0.0), 1.0 / 60.0)
	# Ha girat la distància entre el radi, al voltant de l'eix perpendicular al moviment.
	var q := b.mesh.transform.basis.get_rotation_quaternion()
	assert_float(q.get_angle()).is_equal_approx(10 * step / b.radius, 1e-3)
	assert_vector(q.get_axis()).is_equal_approx(Vector3.FORWARD, Vector3.ONE * 1e-3)


func test_a_l_aire_continua_girant_i_un_salt_no_la_fa_rodar() -> void:
	var b := _ball()
	_look_from(3.0)
	b.place(Vector3.ZERO, 1.0 / 60.0, true)
	b.place(Vector3(0.02, 0.0, 0.0), 1.0 / 60.0)
	var before := b.mesh.transform.basis.get_rotation_quaternion()
	# Enlaire i quieta (de costat): continua girant com girava.
	b.place(Vector3(0.02, 0.4, 0.0), 1.0 / 60.0)
	var after := b.mesh.transform.basis.get_rotation_quaternion()
	assert_float(before.angle_to(after)).is_greater(0.1)
	# Un salt (represa) no la fa girar.
	b.place(Vector3(10.0, 0.0, 3.0), 1.0 / 60.0, true)
	var jumped := b.mesh.transform.basis.get_rotation_quaternion()
	assert_float(after.angle_to(jumped)).is_less(1e-4)


func test_l_ombra_de_contacte_s_esvaeix_quan_s_enlaira() -> void:
	var b := _ball()
	_look_from(3.0)
	b.place(Vector3.ZERO, 0.0, true)
	var mat := b._contact.material_override as ShaderMaterial
	assert_float(float(mat.get_shader_parameter("strength"))).is_greater(0.3)
	# A terra encara que la pilota sigui amunt.
	b.place(Vector3(0.0, 1.0, 0.0), 0.0, true)
	assert_float(float(mat.get_shader_parameter("strength"))).is_equal(0.0)
	assert_float(b._contact.global_position.y).is_less(0.01)


# --- Pal ----------------------------------------------------------------------------------


## Amb la canya inclinada LIE cap enrere, el cap reposa pla: tota la vora de sota és a
## terra o a sobre, i el fons la toca.
func test_el_cap_del_pal_reposa_pla_a_terra() -> void:
	var d := Vector3(0.0, cos(StickMesh.LIE), sin(StickMesh.LIE))
	var basis := StickMesh.place_basis(d, Vector3.LEFT)
	var low := INF
	for q in StickMesh.bottom_points():
		var y := (basis * q).y
		low = minf(low, y)
		assert_float(y).is_greater(-0.002)
	assert_float(low).is_less(0.003)
	# La canya va cap a d i la cara plana (+X del cap) mira a l'esquerra del jugador.
	assert_vector(basis * StickMesh.shaft_dir()).is_equal_approx(d, Vector3.ONE * 1e-4)
	assert_vector(basis.x).is_equal_approx(Vector3.LEFT, Vector3.ONE * 1e-4)


func test_la_pilota_toca_la_cara_del_ganxo() -> void:
	var r := BallView.RADIUS
	var c := StickMesh.ball_contact(r)
	assert_float(c.y).is_equal_approx(r, 1e-6)
	# Del costat de la cara, a tocar del fons del ganxo.
	var bottom := StickMesh.hook_point(0.0)
	assert_float(c.x - bottom.x).is_between(
		StickMesh.HOOK_THICK + r, StickMesh.HOOK_THICK + r + 0.005
	)


func test_un_pal_per_equip_de_mida_real() -> void:
	var a := StickMesh.build(Color("f07c1a"))
	assert_object(StickMesh.build(Color("f07c1a"))).is_same(a)
	assert_object(StickMesh.build(Color("14234b"))).is_not_same(a)
	# Del fons del ganxo a dalt, uns 95 cm al llarg de la canya.
	var top := StickMesh.heel() + StickMesh.shaft_dir() * StickMesh.LENGTH
	assert_float(top.length()).is_between(0.92, 1.0)
	assert_float(a.get_aabb().position.y).is_greater(-0.001)
