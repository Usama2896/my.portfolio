extends RefCounted
const OWNER = preload("res://owner_settings.gd")
const PATH = "user://activation.cfg"
var error := ""
func machine_id() -> String:
	var identity := OS.get_unique_id()
	if identity.is_empty(): identity = OS.get_environment("COMPUTERNAME")
	return identity.sha256_text() if not identity.is_empty() else ""
func proof(identity: String) -> String:
	return ("AL-JEHAD-FPV|"+identity+"|"+OWNER.ACTIVATION_KEY).sha256_text()
func is_active() -> bool:
	var cfg := ConfigFile.new()
	var identity := machine_id()
	return not identity.is_empty() and cfg.load(PATH)==OK and cfg.get_value("license","machine","")==identity and cfg.get_value("license","proof","")==proof(identity)
func activate(key: String) -> bool:
	error = ""
	if key.strip_edges()!=OWNER.ACTIVATION_KEY:
		error = "Incorrect key. Ask the software owner for the activation key."
		return false
	var identity := machine_id()
	if identity.is_empty():
		error = "Cannot identify this PC. Activation could not be saved."
		return false
	var cfg := ConfigFile.new()
	cfg.set_value("license","machine",identity)
	cfg.set_value("license","proof",proof(identity))
	if cfg.save(PATH)!=OK:
		error = "Cannot save activation. Check write access to your Windows app-data folder."
		return false
	return true
