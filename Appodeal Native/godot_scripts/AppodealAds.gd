extends Node
class_name AppodealAds

signal initialization_finished(success: bool, error_message: String)

signal banner_loaded(height: int, is_precache: bool)
signal banner_failed_to_load
signal banner_shown
signal banner_show_failed
signal banner_clicked
signal banner_expired
signal banner_hidden
signal banner_position_updated(x: int, y: int, width: int, height: int)

signal interstitial_loaded(is_precache: bool)
signal interstitial_failed_to_load
signal interstitial_shown
signal interstitial_show_failed
signal interstitial_clicked
signal interstitial_closed
signal interstitial_expired

signal rewarded_loaded(is_precache: bool)
signal rewarded_failed_to_load
signal rewarded_shown
signal rewarded_show_failed
signal rewarded_clicked
signal rewarded_finished(amount: float, currency: String)
signal rewarded_closed(finished: bool)
signal rewarded_expired

signal native_loaded(count: int)
signal native_failed_to_load
signal native_shown
signal native_show_failed
signal native_clicked
signal native_expired
signal native_hidden
signal native_position_updated(x: int, y: int, width: int, height: int)

var plugin: Object = null
var initialized := false

var _native_target: Control = null
var _native_visible := false
var _last_native_rect := Rect2i()

var _banner_target: Control = null
var _banner_visible := false
var _last_banner_rect := Rect2i()


func _ready() -> void:
	set_process(false)


func init(app_key: String, testing: bool = true, auto_cache: bool = false) -> void:
	if OS.get_name() != "Android":
		push_warning("AppodealAds works only on Android exports.")
		emit_signal("initialization_finished", false, "Not Android")
		return

	if not Engine.has_singleton("AppodealNative"):
		push_error("AppodealNative singleton not found. Enable the plugin and export with Gradle Build.")
		emit_signal("initialization_finished", false, "AppodealNative singleton not found")
		return

	plugin = Engine.get_singleton("AppodealNative")
	_connect_plugin_signals()

	plugin.initialize(app_key, testing, auto_cache)


func _connect_plugin_signals() -> void:
	_connect_plugin_signal("initialization_finished", Callable(self, "_on_plugin_initialization_finished"))

	_connect_plugin_signal("banner_loaded", Callable(self, "_on_plugin_banner_loaded"))
	_connect_plugin_signal("banner_failed_to_load", Callable(self, "_on_plugin_banner_failed_to_load"))
	_connect_plugin_signal("banner_shown", Callable(self, "_on_plugin_banner_shown"))
	_connect_plugin_signal("banner_show_failed", Callable(self, "_on_plugin_banner_show_failed"))
	_connect_plugin_signal("banner_clicked", Callable(self, "_on_plugin_banner_clicked"))
	_connect_plugin_signal("banner_expired", Callable(self, "_on_plugin_banner_expired"))
	_connect_plugin_signal("banner_hidden", Callable(self, "_on_plugin_banner_hidden"))
	_connect_plugin_signal("banner_position_updated", Callable(self, "_on_plugin_banner_position_updated"))

	_connect_plugin_signal("interstitial_loaded", Callable(self, "_on_plugin_interstitial_loaded"))
	_connect_plugin_signal("interstitial_failed_to_load", Callable(self, "_on_plugin_interstitial_failed_to_load"))
	_connect_plugin_signal("interstitial_shown", Callable(self, "_on_plugin_interstitial_shown"))
	_connect_plugin_signal("interstitial_show_failed", Callable(self, "_on_plugin_interstitial_show_failed"))
	_connect_plugin_signal("interstitial_clicked", Callable(self, "_on_plugin_interstitial_clicked"))
	_connect_plugin_signal("interstitial_closed", Callable(self, "_on_plugin_interstitial_closed"))
	_connect_plugin_signal("interstitial_expired", Callable(self, "_on_plugin_interstitial_expired"))

	_connect_plugin_signal("rewarded_loaded", Callable(self, "_on_plugin_rewarded_loaded"))
	_connect_plugin_signal("rewarded_failed_to_load", Callable(self, "_on_plugin_rewarded_failed_to_load"))
	_connect_plugin_signal("rewarded_shown", Callable(self, "_on_plugin_rewarded_shown"))
	_connect_plugin_signal("rewarded_show_failed", Callable(self, "_on_plugin_rewarded_show_failed"))
	_connect_plugin_signal("rewarded_clicked", Callable(self, "_on_plugin_rewarded_clicked"))
	_connect_plugin_signal("rewarded_finished", Callable(self, "_on_plugin_rewarded_finished"))
	_connect_plugin_signal("rewarded_closed", Callable(self, "_on_plugin_rewarded_closed"))
	_connect_plugin_signal("rewarded_expired", Callable(self, "_on_plugin_rewarded_expired"))

	_connect_plugin_signal("native_loaded", Callable(self, "_on_plugin_native_loaded"))
	_connect_plugin_signal("native_failed_to_load", Callable(self, "_on_plugin_native_failed_to_load"))
	_connect_plugin_signal("native_shown", Callable(self, "_on_plugin_native_shown"))
	_connect_plugin_signal("native_show_failed", Callable(self, "_on_plugin_native_show_failed"))
	_connect_plugin_signal("native_clicked", Callable(self, "_on_plugin_native_clicked"))
	_connect_plugin_signal("native_expired", Callable(self, "_on_plugin_native_expired"))
	_connect_plugin_signal("native_hidden", Callable(self, "_on_plugin_native_hidden"))
	_connect_plugin_signal("native_position_updated", Callable(self, "_on_plugin_native_position_updated"))


func _connect_plugin_signal(signal_name: StringName, callable: Callable) -> void:
	if plugin == null:
		return

	if plugin.is_connected(signal_name, callable):
		return

	plugin.connect(signal_name, callable)


func load_banner() -> void:
	if plugin:
		plugin.load_banner()


func load_interstitial() -> void:
	if plugin:
		plugin.load_interstitial()


func load_rewarded() -> void:
	if plugin:
		plugin.load_rewarded()


func load_native(amount: int = 1) -> void:
	if plugin:
		plugin.load_native(amount)


func is_banner_loaded() -> bool:
	return plugin != null and plugin.is_banner_loaded()


func is_interstitial_loaded() -> bool:
	return plugin != null and plugin.is_interstitial_loaded()


func is_rewarded_loaded() -> bool:
	return plugin != null and plugin.is_rewarded_loaded()


func is_native_loaded() -> bool:
	return plugin != null and plugin.is_native_loaded()


func get_available_native_count() -> int:
	if plugin == null:
		return 0

	return int(plugin.get_available_native_count())


func show_interstitial(placement: String = "") -> void:
	if plugin:
		plugin.show_interstitial(placement)


func show_rewarded(placement: String = "") -> void:
	if plugin:
		plugin.show_rewarded(placement)


func show_native_on_control(control: Control) -> void:
	if plugin == null:
		return

	_native_target = control
	_native_visible = true
	set_process(true)

	await get_tree().process_frame
	_sync_native_position(true)


func hide_native() -> void:
	_native_visible = false
	_native_target = null
	_last_native_rect = Rect2i()

	if plugin:
		plugin.hide_native()

	_update_processing_state()


func show_banner_on_control(control: Control) -> void:
	if plugin == null:
		return

	_banner_target = control
	_banner_visible = true
	set_process(true)

	await get_tree().process_frame
	_sync_banner_position(true)


func hide_banner() -> void:
	_banner_visible = false
	_banner_target = null
	_last_banner_rect = Rect2i()

	if plugin:
		plugin.hide_banner()

	_update_processing_state()


func _process(_delta: float) -> void:
	if _native_visible:
		if not is_instance_valid(_native_target) or not _native_target.is_visible_in_tree():
			hide_native()
		else:
			_sync_native_position(false)

	if _banner_visible:
		if not is_instance_valid(_banner_target) or not _banner_target.is_visible_in_tree():
			hide_banner()
		else:
			_sync_banner_position(false)


func _update_processing_state() -> void:
	set_process(_native_visible or _banner_visible)


func _sync_native_position(force_show: bool) -> void:
	if plugin == null or not is_instance_valid(_native_target):
		return

	var rect := _control_to_screen_rect(_native_target)

	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	if not force_show and rect == _last_native_rect:
		return

	_last_native_rect = rect

	if force_show:
		plugin.show_native_at(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	else:
		plugin.update_native_position(rect.position.x, rect.position.y, rect.size.x, rect.size.y)


func _sync_banner_position(force_show: bool) -> void:
	if plugin == null or not is_instance_valid(_banner_target):
		return

	var rect := _control_to_screen_rect(_banner_target)

	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	if not force_show and rect == _last_banner_rect:
		return

	_last_banner_rect = rect

	if force_show:
		plugin.show_banner_at(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	else:
		plugin.update_banner_position(rect.position.x, rect.position.y, rect.size.x, rect.size.y)


func _control_to_screen_rect(control: Control) -> Rect2i:
	var rect := control.get_global_rect()

	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()

	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return Rect2i()

	var scale_x := window_size.x / viewport_size.x
	var scale_y := window_size.y / viewport_size.y

	return Rect2i(
		int(rect.position.x * scale_x),
		int(rect.position.y * scale_y),
		int(rect.size.x * scale_x),
		int(rect.size.y * scale_y)
	)


func debug_status() -> String:
	if plugin == null:
		return "AppodealNative plugin is null"

	return plugin.debug_status()


func _on_plugin_initialization_finished(success: bool, error_message: String) -> void:
	initialized = success
	emit_signal("initialization_finished", success, error_message)


func _on_plugin_banner_loaded(height: int, is_precache: bool) -> void:
	emit_signal("banner_loaded", height, is_precache)


func _on_plugin_banner_failed_to_load() -> void:
	emit_signal("banner_failed_to_load")


func _on_plugin_banner_shown() -> void:
	emit_signal("banner_shown")


func _on_plugin_banner_show_failed() -> void:
	emit_signal("banner_show_failed")


func _on_plugin_banner_clicked() -> void:
	emit_signal("banner_clicked")


func _on_plugin_banner_expired() -> void:
	emit_signal("banner_expired")


func _on_plugin_banner_hidden() -> void:
	emit_signal("banner_hidden")


func _on_plugin_banner_position_updated(x: int, y: int, width: int, height: int) -> void:
	emit_signal("banner_position_updated", x, y, width, height)


func _on_plugin_interstitial_loaded(is_precache: bool) -> void:
	emit_signal("interstitial_loaded", is_precache)


func _on_plugin_interstitial_failed_to_load() -> void:
	emit_signal("interstitial_failed_to_load")


func _on_plugin_interstitial_shown() -> void:
	emit_signal("interstitial_shown")


func _on_plugin_interstitial_show_failed() -> void:
	emit_signal("interstitial_show_failed")


func _on_plugin_interstitial_clicked() -> void:
	emit_signal("interstitial_clicked")


func _on_plugin_interstitial_closed() -> void:
	emit_signal("interstitial_closed")


func _on_plugin_interstitial_expired() -> void:
	emit_signal("interstitial_expired")


func _on_plugin_rewarded_loaded(is_precache: bool) -> void:
	emit_signal("rewarded_loaded", is_precache)


func _on_plugin_rewarded_failed_to_load() -> void:
	emit_signal("rewarded_failed_to_load")


func _on_plugin_rewarded_shown() -> void:
	emit_signal("rewarded_shown")


func _on_plugin_rewarded_show_failed() -> void:
	emit_signal("rewarded_show_failed")


func _on_plugin_rewarded_clicked() -> void:
	emit_signal("rewarded_clicked")


func _on_plugin_rewarded_finished(amount: float, currency: String) -> void:
	emit_signal("rewarded_finished", amount, currency)


func _on_plugin_rewarded_closed(finished: bool) -> void:
	emit_signal("rewarded_closed", finished)


func _on_plugin_rewarded_expired() -> void:
	emit_signal("rewarded_expired")


func _on_plugin_native_loaded(count: int) -> void:
	emit_signal("native_loaded", count)


func _on_plugin_native_failed_to_load() -> void:
	emit_signal("native_failed_to_load")


func _on_plugin_native_shown() -> void:
	emit_signal("native_shown")


func _on_plugin_native_show_failed() -> void:
	emit_signal("native_show_failed")


func _on_plugin_native_clicked() -> void:
	emit_signal("native_clicked")


func _on_plugin_native_expired() -> void:
	emit_signal("native_expired")


func _on_plugin_native_hidden() -> void:
	emit_signal("native_hidden")


func _on_plugin_native_position_updated(x: int, y: int, width: int, height: int) -> void:
	emit_signal("native_position_updated", x, y, width, height)
