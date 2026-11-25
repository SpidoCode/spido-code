extends SceneTree

func _initialize() -> void:
	call_deferred("_check_redirect")

func _check_redirect() -> void:
	var service = root.get_node("Supabase")
	var expected: String = service.SUPABASE_URL + "/auth/v1/recover?redirect_to=https%3A%2F%2Fwww.spidocode.com%2Freset-password"
	if service._password_recovery_url() != expected:
		push_error("La solicitud de recuperación debe usar la URL oficial codificada.")
		quit(1)
		return
	print("PASS: redirección oficial de recuperación, sin solicitud externa.")
	quit(0)
