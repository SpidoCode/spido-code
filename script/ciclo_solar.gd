extends DirectionalLight3D

## Ciclo Solar y Lunar para SpidoCode
## Controla la transición continua entre día, atardecer, noche y amanecer.
## Garantiza que durante la noche el mapa se mantenga 100% visible con iluminación lunar
## y luz ambiental nocturna atmosférica sin perder detalle de minerales, terreno ni del Spid.

signal cambio_fase(nueva_fase: String)

@export_group("Velocidad y Tiempo")
## Velocidad del ciclo en grados por segundo (1.0 = 360s / 6 minutos por ciclo completo)
@export var velocidad_rotacion: float = 1.0
## Ángulo inicial en grados (45° = mañana soleada y brillante)
@export_range(0.0, 360.0) var angulo_inicial: float = 45.0

@export_group("Iluminación Solar (Día)")
@export var color_sol: Color = Color(1.0, 0.97, 0.91)
@export var color_ocaso: Color = Color(1.0, 0.65, 0.40)
@export var energia_sol_max: float = 1.10

@export_group("Iluminación Lunar (Noche)")
@export var color_luna: Color = Color(0.68, 0.82, 1.0)
@export var energia_luna_max: float = 0.50

@export_group("Ambiente (WorldEnvironment)")
@export var color_ambiente_dia: Color = Color(0.48, 0.52, 0.62)
@export var energia_ambiente_dia: float = 0.55
@export var color_ambiente_ocaso: Color = Color(0.58, 0.44, 0.38)
@export var energia_ambiente_ocaso: float = 0.62
## Durante la noche la luz ambiental es luminosa y azulada para asegurar 100% de visibilidad
@export var color_ambiente_noche: Color = Color(0.34, 0.48, 0.72)
@export var energia_ambiente_noche: float = 0.80

var angulo_actual: float = 0.0
var luz_luna: DirectionalLight3D = null
var environment_ref: Environment = null
var fase_actual: String = ""


func _ready() -> void:
	angulo_actual = angulo_inicial
	_configurar_luz_luna()
	_obtener_environment()
	_actualizar_iluminacion(0.0)


func _configurar_luz_luna() -> void:
	var padre := get_parent()
	if padre != null:
		luz_luna = padre.get_node_or_null("LuzLuna") as DirectionalLight3D
		if luz_luna == null:
			luz_luna = DirectionalLight3D.new()
			luz_luna.name = "LuzLuna"
			luz_luna.shadow_enabled = false
			padre.add_child.call_deferred(luz_luna)


func _obtener_environment() -> void:
	var padre := get_parent()
	if padre is WorldEnvironment and (padre as WorldEnvironment).environment != null:
		environment_ref = (padre as WorldEnvironment).environment
	elif get_tree() != null and get_tree().current_scene != null:
		var w_env := get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if w_env != null and w_env.environment != null:
			environment_ref = w_env.environment


func _process(delta: float) -> void:
	angulo_actual = fmod(angulo_actual + velocidad_rotacion * delta, 360.0)
	_actualizar_iluminacion(delta)


func _actualizar_iluminacion(_delta: float) -> void:
	# 0° a 180°: Sol sobre el horizonte (Día / Amanecer / Atardecer)
	# 180° a 360°: Luna sobre el horizonte (Noche)
	var rad := deg_to_rad(angulo_actual)
	var sen_angulo := sin(rad) # > 0 de día, < 0 de noche
	
	# Determinar fase del día
	var nueva_fase := _calcular_fase(angulo_actual)
	if nueva_fase != fase_actual:
		fase_actual = nueva_fase
		cambio_fase.emit(fase_actual)

	# 1. ACTUALIZAR SOL (Direct Light principal)
	if sen_angulo > 0.0:
		# El sol está en el cielo
		visible = true
		var elev_sol := sen_angulo
		var factor_cenit := clampf(elev_sol, 0.0, 1.0)
		
		# Ángulo de inclinación del sol: desciende suavemente en amanecer/atardecer (-18° a -72°)
		var pitch_sol := -lerpf(18.0, 72.0, factor_cenit)
		var azim_sol := lerpf(-55.0, 55.0, angulo_actual / 180.0)
		rotation_degrees = Vector3(pitch_sol, azim_sol, 0.0)
		
		# Tinte cálido en atardecer/amanecer y blanco diurno al mediodía
		var factor_color_sol := clampf((factor_cenit - 0.15) / 0.4, 0.0, 1.0)
		light_color = color_ocaso.lerp(color_sol, factor_color_sol)
		
		# Suavizar entrada y salida cerca del horizonte
		var factor_fade_sol := clampf(factor_cenit / 0.15, 0.0, 1.0)
		light_energy = energia_sol_max * factor_fade_sol
	else:
		# De noche el sol se apaga completamente (no ilumina desde abajo de la tierra)
		light_energy = 0.0
		visible = false

	# 2. ACTUALIZAR LUNA (Direct Light secundaria nocturna)
	if is_instance_valid(luz_luna):
		if sen_angulo < 0.0:
			# La luna está en el cielo nocturno
			luz_luna.visible = true
			var elev_luna := -sen_angulo # 0.0 a 1.0
			var factor_cenit_luna := clampf(elev_luna, 0.0, 1.0)
			
			var pitch_luna := -lerpf(25.0, 65.0, factor_cenit_luna)
			var progreso_noche := (angulo_actual - 180.0) / 180.0
			var azim_luna := lerpf(55.0, -55.0, progreso_noche)
			luz_luna.rotation_degrees = Vector3(pitch_luna, azim_luna, 0.0)
			
			luz_luna.light_color = color_luna
			var factor_fade_luna := clampf(factor_cenit_luna / 0.15, 0.0, 1.0)
			luz_luna.light_energy = energia_luna_max * factor_fade_luna
		else:
			# De día la luna se apaga
			luz_luna.light_energy = 0.0
			luz_luna.visible = false

	# 3. ACTUALIZAR AMBIENTE (WorldEnvironment)
	if environment_ref != null:
		var color_amb: Color
		var energia_amb: float
		
		if sen_angulo > 0.2:
			# Pleno Día
			var t := clampf((sen_angulo - 0.2) / 0.8, 0.0, 1.0)
			color_amb = color_ambiente_ocaso.lerp(color_ambiente_dia, t)
			energia_amb = lerpf(energia_ambiente_ocaso, energia_ambiente_dia, t)
		elif sen_angulo >= -0.2:
			# Transición Ocaso / Amanecer
			var t := (sen_angulo + 0.2) / 0.4 # 0.0 = noche próxima, 1.0 = día próximo
			if sen_angulo >= 0.0:
				color_amb = color_ambiente_ocaso
				energia_amb = energia_ambiente_ocaso
			else:
				color_amb = color_ambiente_noche.lerp(color_ambiente_ocaso, t * 2.0)
				energia_amb = lerpf(energia_ambiente_noche, energia_ambiente_ocaso, t * 2.0)
		else:
			# Plena Noche: garantizamos luminosidad ambiente alta con tinte azul nocturno
			var t := clampf((-sen_angulo - 0.2) / 0.8, 0.0, 1.0)
			color_amb = color_ambiente_ocaso.lerp(color_ambiente_noche, t)
			energia_amb = lerpf(energia_ambiente_ocaso, energia_ambiente_noche, t)

		environment_ref.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment_ref.ambient_light_color = color_amb
		environment_ref.ambient_light_energy = energia_amb


func _calcular_fase(ang: float) -> String:
	if ang >= 340.0 or ang < 20.0:
		return "amanecer"
	elif ang >= 20.0 and ang < 160.0:
		return "dia"
	elif ang >= 160.0 and ang < 200.0:
		return "atardecer"
	else:
		return "noche"


## Métodos públicos para consultar el estado del ciclo desde otros sistemas o HUD
func obtener_fase() -> String:
	return fase_actual

func es_de_noche() -> bool:
	return fase_actual == "noche"

func es_de_dia() -> bool:
	return fase_actual == "dia"

func obtener_angulo() -> float:
	return angulo_actual

func obtener_progreso() -> float:
	return angulo_actual / 360.0

## Permite cambiar la velocidad de rotación o pausar el ciclo
func establecer_velocidad(vel: float) -> void:
	velocidad_rotacion = vel
