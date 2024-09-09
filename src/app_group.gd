extends PanelContainer
class_name AppGroup

const CHECK_BOX_TEXT : String = "App ID: %s - %s"

var app_id := "":
	set(value):
		app_id = value
		$HBox/CheckBox.text = CHECK_BOX_TEXT % [app_id, vdf_file_name]

var vdf_file_name := "":
	set(value):
		vdf_file_name = value
		$HBox/CheckBox.text = CHECK_BOX_TEXT % [app_id, vdf_file_name]
		
var desc := "":
	set(value):
		desc = value
		$HBox/DescEdit.text = desc


func setup(_app_id:String, _desc:String, _vdf_file_name:String) -> void:
	app_id = _app_id
	desc = _desc
	vdf_file_name = _vdf_file_name


func has_filter_name(filter:String):
	filter = filter.to_lower()
	return filter in app_id.to_lower() or filter in vdf_file_name.to_lower()


func get_desc() -> String:
	return $HBox/DescEdit.text


func is_selected() -> bool:
	return $HBox/CheckBox.pressed


func set_selected(selected:bool):
	$HBox/CheckBox.pressed = selected
