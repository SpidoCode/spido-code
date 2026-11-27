class_name ADAVisualizador
extends Control

var tiempo: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	tiempo += delta
	queue_redraw()


func _draw() -> void:
	var ancho: float = size.x
	var alto: float = size.y
	if ancho < 10.0 or alto < 10.0:
		return

	# Ondas de sonido / espectro de audio de A.D.A. a lo ancho de la tarjeta
	var cant_barras: int = 25
	var margen_lateral: float = 8.0
	var espacio_util: float = ancho - (margen_lateral * 2.0)
	var paso_x: float = espacio_util / float(cant_barras - 1)
	var base_y: float = alto * 0.5
	var verde_brillante := Color(0.7608, 0.937, 0.775, 0.95)

	for indice in range(cant_barras):
		var factor_centro: float = sin(PI * float(indice) / float(cant_barras - 1))
		var oscilacion: float = abs(sin(tiempo * 5.0 + float(indice) * 0.5) * cos(tiempo * 2.5 + float(indice) * 0.25))
		var altura: float = 3.5 + (factor_centro * 0.35 + 0.65) * oscilacion * (alto * 0.42)
		var bx: float = margen_lateral + float(indice) * paso_x
		draw_line(Vector2(bx, base_y - altura), Vector2(bx, base_y + altura), verde_brillante, 3.0, false)
