extends Control


@onready var appodeal = $AppodealAds
func _ready() -> void:
	appodeal.init()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_appodeal_ads_initialization_finished(success: bool, error_message: String) -> void:
	if success:
		appodeal.load_banner()
		appodeal.load_native(1)
		appodeal.load_interstitial()
		appodeal.load_rewarded()
	else:
		print("something error ",error_message)

func _on_appodeal_ads_banner_loaded(height: int, is_precache: bool) -> void:
	appodeal.show_banner_on_control($ScrollContainer/BoxContainer2/VBoxContainer/banner)

func _on_appodeal_ads_native_loaded(count: int) -> void:
	appodeal.show_native_on_control($ScrollContainer/BoxContainer2/VBoxContainer/native)

func _on_appodeal_ads_rewarded_loaded(is_precache: bool) -> void:
	pass # Replace with function body.


func _on_appodeal_ads_interstitial_loaded(is_precache: bool) -> void:
	pass # Replace with function body.


func _on_interst_pressed() -> void:
	if appodeal.is_interstitial_loaded():
		appodeal.show_interstitial("")
		

func _on_rewarded_pressed() -> void:
	if appodeal.is_rewarded_loaded():
		appodeal.show_rewarded("")


func _on_appodeal_ads_banner_shown() -> void:
	print("Banner Shown")
