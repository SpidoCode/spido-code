extends Node3D

@export var mineral_scene : PackedScene
@onready var grid_map: GridMap = $GridMap

# Esta es la casilla cuyo centro queda junto a la nave.
const CASILLA_INICIAL := Vector3i.ZERO
const CASILLA_TRANSFERENCIA := CASILLA_INICIAL

# Nivel de expansión del mismo mapa.
# 0 = zona inicial 1x1
# 1 = corredor 1x3
# 2 = sector 2x3 (tres casillas adicionales)
# 3 = sector 3x3, reservado para una expansión futura
var radio_mapa_desbloqueado: int = 0
var max_minerales: int = 1
var corredor_1x3_desbloqueado: bool = false
var mapa_3x3_desbloqueado: bool = false
var mapa_4x3_desbloqueado: bool = false
var mapa_4x4_desbloqueado: bool = false
var mapa_5x4_desbloqueado: bool = false
var mapa_5x5_desbloqueado: bool = false
var casillas_extra_desbloqueadas: bool = false
var ultima_celda_minada: Vector3i = Vector3i(9999, 9999, 9999)

func _ready():
	var map_tier := 0
	var progreso: Dictionary = {}
	var restaurar_progreso := false
	# El autoload conserva su vida entre escenas; cada entrada al mundo parte
	# explícitamente de la sintaxis inicial antes de restaurar un usuario.
	GestorSintaxis.aplicar_sintaxis_desbloqueada({})

	if Supabase.is_authenticated():
		if ProgressService.has_loaded_progress():
			progreso = ProgressService.get_current_progress()
			map_tier = int(progreso.get("map_tier", 0))
			restaurar_progreso = true
		else:
			push_error("Sesión autenticada sin progreso cargado. Se inicia un mundo seguro sin restaurar datos.")

	var ya_compro_3x3: bool = false
	var ya_compro_4x3: bool = false
	var compl_prog = progreso.get("completed_missions", [])
	if typeof(compl_prog) == TYPE_ARRAY:
		if "comprar_mapa_3x3" in compl_prog or "comprar_sector_3x3" in compl_prog:
			ya_compro_3x3 = true
		if "comprar_sector_4x3" in compl_prog or "comprar_telemetria" in compl_prog or "telemetria_dinamica" in compl_prog:
			ya_compro_4x3 = true
	if MissionService != null:
		var compl = MissionService.get_completed_missions()
		if "comprar_mapa_3x3" in compl or "comprar_sector_3x3" in compl:
			ya_compro_3x3 = true
		if "comprar_sector_4x3" in compl or "comprar_telemetria" in compl or "telemetria_dinamica" in compl or GestorSintaxis.esta_desbloqueada("tamano_mundo"):
			ya_compro_4x3 = true

	if ya_compro_4x3:
		map_tier = maxi(map_tier, 4)
	elif ya_compro_3x3:
		map_tier = maxi(map_tier, 3)
	elif not ya_compro_3x3 and MissionService != null and MissionService.objective_id in ["comprar_mapa_3x3", "senales_inciertas"]:
		map_tier = mini(map_tier, 2)

	aplicar_progreso_mapa(map_tier)
	_posicionar_spid_en_casilla_inicial()
	_resaltar_casilla_principal()
	generar_minerales_iniciales()
	var spid := grid_map.get_node_or_null("Spid")
	if spid != null and spid.has_signal("mineral_minado"):
		spid.mineral_minado.connect(_on_mineral_minado)

	if MissionService != null and MissionService.has_signal("veta_lineal_solicitada"):
		MissionService.veta_lineal_solicitada.connect(_on_veta_lineal_solicitada)

	if restaurar_progreso:
		var sintaxis = progreso.get("unlocked_syntax", {})
		if typeof(sintaxis) != TYPE_DICTIONARY:
			push_error("El progreso cargado contiene unlocked_syntax inválido; se usarán sintaxis bloqueadas.")
			sintaxis = {}
		GestorSintaxis.aplicar_sintaxis_desbloqueada(sintaxis)

	var interfaz := get_node_or_null("CanvasLayer")
	if interfaz != null:
		interfaz.aplicar_progreso(progreso)

func _on_veta_lineal_solicitada(_indice: int) -> void:
	asegurar_minerales_por_columnas()

func _on_mineral_minado(celda: Vector3i) -> void:
	ultima_celda_minada = celda
	asegurar_minerales_por_columnas.call_deferred()

func _verificar_regeneracion_circuito_2x3() -> void:
	asegurar_minerales_por_columnas()

# Reconstruye el mapa desde el tier persistido. No valida costos ni emite
# efectos de compra, por lo que también se puede usar al restaurar progreso.
func aplicar_progreso_mapa(map_tier: int) -> void:
	var tier_seguro := maxi(0, map_tier)
	var ya_compro_3x3: bool = false
	var ya_compro_4x3: bool = false
	if MissionService != null:
		var compl = MissionService.get_completed_missions()
		if "comprar_mapa_3x3" in compl or "comprar_sector_3x3" in compl:
			ya_compro_3x3 = true
		if "comprar_sector_4x3" in compl or "comprar_telemetria" in compl or "telemetria_dinamica" in compl or GestorSintaxis.esta_desbloqueada("tamano_mundo"):
			ya_compro_4x3 = true

	# Durante la fase previa a comprar el sector 3x3, el mapa se mantiene en sector 2x3 (tier 2)
	if ya_compro_4x3:
		tier_seguro = maxi(tier_seguro, 4)
	elif ya_compro_3x3:
		tier_seguro = maxi(tier_seguro, 3)
	elif not ya_compro_3x3 and not mapa_3x3_desbloqueado and MissionService != null and MissionService.objective_id in ["comprar_mapa_3x3", "senales_inciertas", "comprar_casillas"]:
		tier_seguro = mini(tier_seguro, 2)

	radio_mapa_desbloqueado = tier_seguro

	corredor_1x3_desbloqueado = (
		radio_mapa_desbloqueado >= 1
	)

	mapa_5x5_desbloqueado = (
		radio_mapa_desbloqueado >= 7
	)
	mapa_5x4_desbloqueado = (
		radio_mapa_desbloqueado >= 6
	)
	mapa_4x4_desbloqueado = (
		radio_mapa_desbloqueado >= 5
	)
	mapa_4x3_desbloqueado = (
		radio_mapa_desbloqueado >= 4
	)
	mapa_3x3_desbloqueado = (
		radio_mapa_desbloqueado >= 3
	)
	casillas_extra_desbloqueadas = radio_mapa_desbloqueado >= 2
	if mapa_5x5_desbloqueado:
		max_minerales = 6
	elif mapa_5x4_desbloqueado:
		max_minerales = 5
	elif mapa_4x4_desbloqueado:
		max_minerales = 4
	elif mapa_4x3_desbloqueado:
		max_minerales = 4
	elif mapa_3x3_desbloqueado:
		max_minerales = 3
	elif casillas_extra_desbloqueadas:
		max_minerales = 2
	else:
		max_minerales = 1

	grid_map.clear()

	# Sector 5x5: cinco columnas (-2 a 2) y cinco filas (-2 a 2) con base central (0, 0)
	if mapa_5x5_desbloqueado:
		for x in range(-2, 3):
			for z in range(-2, 3):
				var casilla := CASILLA_INICIAL + Vector3i(x, 0, z)
				var tipo_casilla := 1 if (x + z) % 2 == 0 else 2
				grid_map.set_cell_item(casilla, tipo_casilla)
		return

	# Sector 5x4: cinco columnas (-2 a 2) y cuatro filas (-2 a 1) con base central (0, 0)
	if mapa_5x4_desbloqueado:
		for x in range(-2, 3):
			for z in range(-2, 2):
				var casilla := CASILLA_INICIAL + Vector3i(x, 0, z)
				var tipo_casilla := 1 if (x + z) % 2 == 0 else 2
				grid_map.set_cell_item(casilla, tipo_casilla)
		return

	# Sector 4x4: cuatro columnas (-1 a 2) y cuatro filas (-2 a 1) con base central (0, 0)
	if mapa_4x4_desbloqueado:
		for x in range(-1, 3):
			for z in range(-2, 2):
				var casilla := CASILLA_INICIAL + Vector3i(x, 0, z)
				var tipo_casilla := 1 if (x + z) % 2 == 0 else 2
				grid_map.set_cell_item(casilla, tipo_casilla)
		return

	# Sector 4x3: cuatro columnas (-1 a 2) y tres filas (-1 a 1) con base central (0, 0)
	if mapa_4x3_desbloqueado:
		for x in range(-1, 3):
			for z in range(-1, 2):
				var casilla := CASILLA_INICIAL + Vector3i(x, 0, z)
				var tipo_casilla := 1 if (x + z) % 2 == 0 else 2
				grid_map.set_cell_item(casilla, tipo_casilla)
		return

	# Sector 3x3: tres columnas centradas en X (-1 a 1) y tres filas centradas en Z (-1 a 1) con base central (0, 0)
	if mapa_3x3_desbloqueado:
		for x in range(-1, 2):
			for z in range(-1, 2):
				var casilla := CASILLA_INICIAL + Vector3i(x, 0, z)
				var tipo_casilla := 1 if (x + z) % 2 == 0 else 2
				grid_map.set_cell_item(casilla, tipo_casilla)
		return

	if casillas_extra_desbloqueadas:
		for x in range(0, 2):
			for z in range(-1, 2):
				var casilla := CASILLA_INICIAL + Vector3i(x, 0, z)
				grid_map.set_cell_item(casilla, 1 if (x + z) % 2 == 0 else 2)
		return

	# Corredor 1x3: comienza en la nave y avanza hacia el norte.
	if corredor_1x3_desbloqueado:
		for z in range(
			CASILLA_INICIAL.z - 1,
			CASILLA_INICIAL.z + 2
		):
			var posicion := Vector3i(
				CASILLA_INICIAL.x,
				0,
				z
			)

			var tipo_casilla := (
				1 if (
				posicion.x + posicion.z
				) % 2 == 0 else 2
			)

			grid_map.set_cell_item(
				posicion,
				tipo_casilla
			)

		return

	# Nivel inicial: solamente la casilla de transferencia.
	grid_map.set_cell_item(
			CASILLA_INICIAL,
			1
		)

func _posicionar_spid_en_casilla_inicial() -> void:
	var spid := grid_map.get_node_or_null("Spid") as Node3D
	if spid == null:
		return

	var centro: Vector3 = grid_map.map_to_local(CASILLA_INICIAL)
	spid.position.x = centro.x
	spid.position.z = centro.z


func resetear_posicion_spid() -> void:
	var spid := grid_map.get_node_or_null("Spid") as Node3D
	if spid == null:
		return
	var centro_local: Vector3 = grid_map.map_to_local(CASILLA_INICIAL)
	var centro_global: Vector3 = grid_map.to_global(centro_local)
	centro_global.y = spid.global_position.y
	if spid.has_method("resetear_a_base"):
		spid.resetear_a_base(centro_global)
	else:
		spid.global_position = centro_global
		spid.rotation = Vector3.ZERO

const CIRCUITO_FOR_2X3: Array[Vector3i] = [
	Vector3i(0, 0, -1), # Norte
	Vector3i(1, 0, -1), # Noreste
	Vector3i(1, 0, 0)   # Este
]

const DEPOSITO_MISION_8 := Vector3i(0, 0, -1) # 1 paso al norte de la base central

func generar_deposito_mision_8() -> void:
	asegurar_minerales_por_columnas()

func _verificar_regeneracion_mision_8() -> void:
	asegurar_minerales_por_columnas()

func generar_circuito_for_2x3() -> void:
	asegurar_minerales_por_columnas()

func asegurar_minerales_por_columnas() -> void:
	if mineral_scene == null:
		return

	# Obtener celdas con minerales activos que no estén en proceso de eliminación
	var ocupadas: Array[Vector3i] = []
	var minerales_por_columna: Dictionary = {}

	for mineral in get_tree().get_nodes_in_group("minerales"):
		var objeto := mineral.get_parent() as Node3D
		if objeto == null or objeto.get_parent() != self or objeto.is_queued_for_deletion():
			continue
		var celda := grid_map.local_to_map(grid_map.to_local(objeto.global_position))
		celda.y = 0
		ocupadas.append(celda)
		if not minerales_por_columna.has(celda.x):
			minerales_por_columna[celda.x] = []
		minerales_por_columna[celda.x].append(celda)

	# En las 3 primeras misiones del corredor (hasta completar bucle while / cuota_suministro),
	# el mineral debe generarse siempre en el norte.
	var forzar_norte: bool = (
		radio_mapa_desbloqueado > 0
		and (
			not casillas_extra_desbloqueadas
			or (MissionService != null and MissionService.objective_id in ["ruta_calibracion", "trabajo_continuo", "cuota_suministro"])
		)
	)
	if forzar_norte:
		var casilla_norte := CASILLA_INICIAL + Vector3i(0, 0, -1)
		if not (casilla_norte in ocupadas) and grid_map.get_cell_item(casilla_norte) != GridMap.INVALID_CELL_ITEM:
			instanciar_mineral_en_casilla(casilla_norte)
		return

	# Identificar todas las columnas (X) disponibles en el grid_map
	var columnas_existentes: Array[int] = []
	var celdas_por_columna: Dictionary = {}

	for celda in grid_map.get_used_cells():
		var celda_2d := Vector3i(celda.x, 0, celda.z)
		if not celdas_por_columna.has(celda_2d.x):
			celdas_por_columna[celda_2d.x] = []
			columnas_existentes.append(celda_2d.x)
		celdas_por_columna[celda_2d.x].append(celda_2d)

	columnas_existentes.sort()

	if columnas_existentes.is_empty():
		return

	# Garantizar al menos un mineral por corrida / columna
	for col_x in columnas_existentes:
		var minerales_en_col: Array = minerales_por_columna.get(col_x, [])
		if minerales_en_col.is_empty():
			var celdas_col: Array = celdas_por_columna.get(col_x, [])
			var candidatas: Array[Vector3i] = []
			for c in celdas_col:
				if c == CASILLA_TRANSFERENCIA:
					continue
				if c in ocupadas:
					continue
				candidatas.append(c)

			if not candidatas.is_empty():
				var candidatas_sin_repetir: Array[Vector3i] = []
				for c in candidatas:
					if c != ultima_celda_minada:
						candidatas_sin_repetir.append(c)

				var elegida: Vector3i
				if not candidatas_sin_repetir.is_empty():
					elegida = candidatas_sin_repetir.pick_random()
				else:
					elegida = candidatas.pick_random()

				instanciar_mineral_en_casilla(elegida)
				ocupadas.append(elegida)
				if not minerales_por_columna.has(col_x):
					minerales_por_columna[col_x] = []
				minerales_por_columna[col_x].append(elegida)

func generar_minerales_iniciales():
	# Si el radio es 0 (solo 1 casilla), solo hacemos aparecer 1 mineral
	if radio_mapa_desbloqueado == 0:
		max_minerales = 1
		spawn_mineral_aleatorio()
		return

	asegurar_minerales_por_columnas()

func instanciar_mineral_en_casilla(casilla: Vector3i) -> void:
	if mineral_scene == null:
		return
	var centro_local := grid_map.map_to_local(casilla)
	var centro_global := grid_map.to_global(centro_local)
	var nuevo_mineral = mineral_scene.instantiate()
	add_child(nuevo_mineral)
	nuevo_mineral.global_position = centro_global + Vector3(0, -0.4, 0.3)

func spawn_mineral_aleatorio() -> void:
	var ocupadas: Array[Vector3i] = []
	for mineral in get_tree().get_nodes_in_group("minerales"):
		var objeto := mineral.get_parent() as Node3D
		if objeto == null or objeto.get_parent() != self or objeto.is_queued_for_deletion():
			continue
		var celda := grid_map.local_to_map(grid_map.to_local(objeto.global_position))
		celda.y = 0
		ocupadas.append(celda)

	if ocupadas.size() >= max_minerales:
		return

	var casilla_mineral := CASILLA_INICIAL

	# 1. Sector expandido 2x3 (map_tier >= 2)
	if casillas_extra_desbloqueadas:
		var candidatas: Array[Vector3i] = []
		for celda in grid_map.get_used_cells():
			var celda_2d := Vector3i(celda.x, 0, celda.z)
			# REGLA A: Nunca en la casilla de transferencia / nave (0, 0, 0)
			if celda_2d == CASILLA_TRANSFERENCIA:
				continue
			# REGLA B: Nunca en una celda que ya tenga mineral
			if celda_2d in ocupadas:
				continue
			candidatas.append(celda_2d)

		if candidatas.is_empty():
			return

		# REGLA C: Evitar la última celda minada si hay otra alternativa disponible
		var candidatas_sin_repetir: Array[Vector3i] = []
		for c in candidatas:
			if c != ultima_celda_minada:
				candidatas_sin_repetir.append(c)

		if not candidatas_sin_repetir.is_empty():
			casilla_mineral = candidatas_sin_repetir.pick_random()
		else:
			# Si no hay alternativa, permitimos repetir
			casilla_mineral = candidatas.pick_random()

	# 2. Corredor 1x3 (map_tier 1)
	elif corredor_1x3_desbloqueado:
		casilla_mineral = CASILLA_INICIAL + Vector3i(0, 0, -1)

	# 3. Zona inicial 1x1 (map_tier 0)
	else:
		casilla_mineral = CASILLA_INICIAL

	# Instanciar el mineral visualmente centrado en la casilla elegida
	var centro_local := grid_map.map_to_local(casilla_mineral)
	var centro_global := grid_map.to_global(centro_local)

	var nuevo_mineral = mineral_scene.instantiate()
	add_child(nuevo_mineral)
	nuevo_mineral.global_position = centro_global + Vector3(0, -0.4, 0.3)

func reubicar_mineral_para_corredor() -> void:
	var minerales := get_tree().get_nodes_in_group("minerales")
	var padres_eliminados: Dictionary = {}

	for mineral in minerales:
		var objeto_mineral := mineral.get_parent() as Node

		if objeto_mineral == null:
			continue

		var id_objeto := objeto_mineral.get_instance_id()

		if padres_eliminados.has(id_objeto):
			continue

		padres_eliminados[id_objeto] = true
		objeto_mineral.queue_free()

	# Esperamos a que Godot elimine el mineral anterior.
	call_deferred("generar_minerales_iniciales")

func spid_esta_en_casilla_transferencia(spid: Node3D) -> bool:
	if spid == null:
		return false

	var posicion_local := grid_map.to_local(spid.global_position)
	var casilla_actual := grid_map.local_to_map(posicion_local)

	# El movimiento ocurre horizontalmente.
	casilla_actual.y = CASILLA_TRANSFERENCIA.y

	return casilla_actual == CASILLA_TRANSFERENCIA

func expandir_corredor_1x3() -> bool:
	if corredor_1x3_desbloqueado:
		return false

	aplicar_progreso_mapa(1)
	reubicar_mineral_para_corredor()

	print(
		"Corredor adquirido: terreno expandido a 1x3."
	)

	return true


func expandir_tres_casillas() -> bool:
	if casillas_extra_desbloqueadas or not corredor_1x3_desbloqueado:
		return false
	aplicar_progreso_mapa(2)
	reubicar_mineral_para_corredor()
	return true


func expandir_mapa_3x3() -> bool:
	if mapa_3x3_desbloqueado:
		return false

	aplicar_progreso_mapa(3)
	reubicar_mineral_para_corredor()

	print(
		"Sector adquirido: terreno expandido a 3x3."
	)

	return true


func expandir_mapa_4x3() -> bool:
	if mapa_4x3_desbloqueado:
		return false

	aplicar_progreso_mapa(4)
	reubicar_mineral_para_corredor()

	print(
		"Sector adquirido: terreno expandido a 4x3."
	)

	return true


func expandir_mapa_4x4() -> bool:
	if mapa_4x4_desbloqueado or not mapa_4x3_desbloqueado:
		return false

	aplicar_progreso_mapa(5)
	reubicar_mineral_para_corredor()

	print(
		"Sector adquirido: terreno expandido a 4x4."
	)

	return true


func expandir_mapa_5x4() -> bool:
	if mapa_5x4_desbloqueado or not mapa_4x4_desbloqueado:
		return false

	aplicar_progreso_mapa(6)
	reubicar_mineral_para_corredor()

	print(
		"Sector adquirido: terreno expandido a 5x4."
	)

	return true


func expandir_mapa_5x5() -> bool:
	if mapa_5x5_desbloqueado or not mapa_5x4_desbloqueado:
		return false

	aplicar_progreso_mapa(7)
	reubicar_mineral_para_corredor()

	print(
		"Sector adquirido: terreno expandido a 5x5."
	)

	return true

func get_map_tier() -> int:
	return radio_mapa_desbloqueado


func _resaltar_casilla_principal() -> void:
	var resaltador = grid_map.get_node_or_null("ResaltadorBase")
	if resaltador == null:
		resaltador = MeshInstance3D.new()
		resaltador.name = "ResaltadorBase"
		var malla = PlaneMesh.new()
		malla.size = Vector2(1.8, 1.8)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.15, 0.45, 0.3, 0.4)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color(0.15, 0.45, 0.3)
		material.emission_energy_multiplier = 0.8
		malla.material = material
		resaltador.mesh = malla
		grid_map.add_child(resaltador)
	
	var centro_local = grid_map.map_to_local(CASILLA_INICIAL)
	resaltador.position = centro_local + Vector3(0, 0.11, 0)
