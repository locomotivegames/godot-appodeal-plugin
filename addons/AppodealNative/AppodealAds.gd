@tool
@icon("res://addons/AppodealNative/icon.svg")
extends Node

class_name AppodealAds
@export var app_key:String = "your appodeal app key here.."
@export var is_testing : bool = true
@export var auto_cache : bool = true
@export var UMP_consent_debug_mode : bool = false

var device_hashed_id = "442134D66BAFF9D612160C4228334C8"
# use this to filter logcat and get device id after running the app once :adb logcat -v time | findstr /i "addTestDeviceHashedId ConsentDebugSettings UserMessagingPlatform UMP requestConsentInfoUpdate consent"
enum NativeTemplate {
	NEWS_FEED = 0,
	APP_WALL = 1,
	CONTENT_STREAM = 2,
}

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

var _native_slots := {}
var _active_native_slot: String = ""
var _native_visible := false
var _last_native_rect := Rect2i()

var _banner_target: Control = null
var _banner_visible := false
var _last_banner_rect := Rect2i()


func _ready() -> void:
	set_process(false)


func init() -> void:
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

	start_appodeal_with_consent()

func start_appodeal_with_consent() -> void:
	plugin.consent_info_updated.connect(_on_consent_info_updated)
	plugin.consent_form_dismissed.connect(_on_consent_form_dismissed)
	plugin.consent_flow_finished.connect(_on_consent_flow_finished)
	
	#for appodeal
	if UMP_consent_debug_mode:
		plugin.request_ump_debug_consent_flow(
			device_hashed_id,
			false, #tagForUnderAgeOfConsent: Boolean,
			true, #forceEea: Boolean,
			true # reset , this clears the saved UMP consent state on that device, so the consent form can show again.
		)
	else:
		plugin.request_consent_info_update(app_key, false)
	#for admob_
	

func _on_consent_info_updated(success: bool, message: String) -> void:
	print("Consent info updated: ", success, " / ", message)
	
	if not success:
		push_warning("Consent info update failed: " + message)
		# You can decide whether to initialize or block ads here.
		# For strict compliance, fix the consent error first.
		return
	
	match message:
		"NotRequired":
			print("Consent not required. Initializing Appodeal.")
			plugin.initialize(app_key, is_testing, auto_cache)

		"Obtained":
			print("Consent already obtained. Initializing Appodeal.")
			plugin.initialize(app_key, is_testing, auto_cache)

		"Required":
			print("Consent required. Showing consent form.")
			plugin.load_and_show_consent_form_if_required()

		_:
			print("Unknown consent status: ", message)
			plugin.init(app_key, false, false)

func _on_consent_flow_finished(success: bool, message: String) -> void:
	print("Consent flow finished: ", success, " / ", message)
	plugin.initialize(app_key, is_testing, auto_cache)
func _on_consent_form_dismissed(success: bool, message: String) -> void:
	print("Consent form dismissed: ", success, " / ", message)

	# Now initialize ads.
	plugin.initialize(app_key, is_testing, auto_cache)
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
		if not _native_slots.has(_active_native_slot):
			hide_native()
		else:
			var data: Dictionary = _native_slots[_active_native_slot]
			var control: Control = data.get("control", null)

			if not is_instance_valid(control) or not control.is_visible_in_tree():
				hide_native()
			else:
				_sync_active_native_position(false)
	if _banner_visible:
		if not is_instance_valid(_banner_target) or not _banner_target.is_visible_in_tree():
			hide_banner()
		else:
			_sync_banner_position(false)


func _update_processing_state() -> void:
	set_process(_native_visible or _banner_visible)


func _sync_active_native_position(force_show: bool) -> void:
	if plugin == null:
		return

	if not _native_slots.has(_active_native_slot):
		return

	var data: Dictionary = _native_slots[_active_native_slot]
	var control: Control = data.get("control", null)
	var native_type: int = int(data.get("type", NativeTemplate.NEWS_FEED))

	if not is_instance_valid(control):
		return

	var rect := _control_to_screen_rect(control)

	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	if not force_show and rect == _last_native_rect:
		return

	_last_native_rect = rect

	if force_show:
		plugin.show_native_at(
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y,
			native_type
		)
	else:
		plugin.update_native_position(
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y
		)

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
	
	
	
func register_native_slot(slot_name: String, control: Control, native_type: int = NativeTemplate.NEWS_FEED) -> bool:
	if not is_instance_valid(control):
		push_warning("Cannot register native slot. Control is invalid: " + slot_name)
		return false

	_cleanup_invalid_native_slots()

	# If same slot already exists, check if it is the same target/type.
	if _native_slots.has(slot_name):
		var existing_data: Dictionary = _native_slots[slot_name]
		var existing_control_variant = existing_data.get("control", null)
		var existing_type: int = int(existing_data.get("type", NativeTemplate.NEWS_FEED))

		if existing_control_variant != null and is_instance_valid(existing_control_variant):
			var existing_control := existing_control_variant as Control

			if existing_control == control and existing_type == native_type:
				return false
		else:
			_native_slots.erase(slot_name)

	# Check if this target Control is already registered under another slot.
	for existing_slot_name in _native_slots.keys():
		var data: Dictionary = _native_slots[existing_slot_name]
		var existing_control_variant = data.get("control", null)

		if existing_control_variant == null:
			continue

		if not is_instance_valid(existing_control_variant):
			_native_slots.erase(existing_slot_name)
			continue

		var existing_control := existing_control_variant as Control

		if existing_control == control:
			print("Native target already registered in slot: ", existing_slot_name)
			return false

	_native_slots[slot_name] = {
		"control": control,
		"type": native_type,
	}

	return true
	
func _cleanup_invalid_native_slots() -> void:
	for slot_name in _native_slots.keys():
		var data: Dictionary = _native_slots[slot_name]
		var control_variant = data.get("control", null)

		if control_variant == null or not is_instance_valid(control_variant):
			if _active_native_slot == slot_name:
				hide_native()

			_native_slots.erase(slot_name)
func unregister_native_slot(slot_name: String) -> void:
	if _active_native_slot == slot_name:
		hide_native()

	_native_slots.erase(slot_name)


func show_native_slot(slot_name: String) -> void:
	if plugin == null:
		return

	if not _native_slots.has(slot_name):
		push_warning("Native slot not found: " + slot_name)
		return

	var data: Dictionary = _native_slots[slot_name]
	var control: Control = data.get("control", null)

	if not is_instance_valid(control):
		push_warning("Native slot control is invalid: " + slot_name)
		return

	_active_native_slot = slot_name
	_native_visible = true
	_last_native_rect = Rect2i()

	set_process(true)

	await get_tree().process_frame
	_sync_active_native_position(true)


func show_native_on_control(control: Control, native_type: int = NativeTemplate.NEWS_FEED) -> void:
	register_native_slot("__direct__", control, native_type)
	show_native_slot("__direct__")


func hide_native() -> void:
	_native_visible = false
	_active_native_slot = ""
	_last_native_rect = Rect2i()

	if plugin:
		plugin.hide_native()

	_update_processing_state()
