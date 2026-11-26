extends SceneTree
## Sustituye la apertura del navegador; no hace peticiones ni lee credenciales.

class AuthSinNavegador:
	extends RefCounted
	var urls: Array[String] = []
	var resultado: Error = OK

	func _abrir_registro_web(url: String) -> Error:
		urls.append(url)
		return resultado

func _initialize() -> void:
	call_deferred("comprobar")

func comprobar() -> void:
	var navegador := AuthSinNavegador.new()
	var auth = load("res://script/auth.gd").new()
	auth._abrir_navegador = navegador._abrir_registro_web
	var status := Label.new()
	auth.status_label = status
	# Sin inputs: registrarse no debe exigir ni leer credenciales del juego.
	auth._on_registrarse_pressed()
	var passed: bool = auth.WEB_SIGNUP_URL == "https://www.spidocode.com/registro"
	passed = passed and navegador.urls == [auth.WEB_SIGNUP_URL]
	passed = passed and status.text.contains("Completa el registro en el navegador")
	passed = passed and root.get_node("Supabase").pending_operation.is_empty()
	# La URL exacta impide añadir query strings o fragmentos con credenciales.
	navegador.resultado = ERR_CANT_OPEN
	auth._on_registrarse_pressed()
	passed = passed and navegador.urls.size() == 2
	passed = passed and navegador.urls[1] == auth.WEB_SIGNUP_URL
	passed = passed and status.text == "No se pudo abrir el navegador. Inténtalo nuevamente."
	passed = passed and root.get_node("Supabase").pending_operation.is_empty()
	var recovery_url := "https://www.spidocode.com/recuperar-contrasena"
	var empty_email := LineEdit.new()
	auth.email_input = empty_email
	navegador.resultado = OK
	auth._on_recuperar_password_pressed()
	passed = passed and navegador.urls.size() == 3 and navegador.urls[2] == recovery_url
	passed = passed and status.text.contains("Completa la recuperación en el navegador")
	passed = passed and root.get_node("Supabase").pending_operation.is_empty()
	navegador.resultado = ERR_CANT_OPEN
	auth._on_recuperar_password_pressed()
	passed = passed and navegador.urls.size() == 4 and navegador.urls[3] == recovery_url
	passed = passed and status.text == "No se pudo abrir el navegador. Inténtalo nuevamente."
	passed = passed and root.get_node("Supabase").pending_operation.is_empty()
	empty_email.free()
	auth.free()
	status.free()
	if passed:
		print("PASS: URLs oficiales, éxito y error de registro y recuperación, sin navegador, credenciales ni petición Supabase.")
	else:
		push_error("FAIL: URL, resultado del botón o aislamiento del registro o la recuperación web incorrectos.")
	quit(0 if passed else 1)
