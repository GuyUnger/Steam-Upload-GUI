@tool
class_name Turbo
extends EditorPlugin

const ICON_CLEAR = preload("res://addons/turbo_tools/icons/Clear.svg")
const ICON_PIN = preload("res://addons/turbo_tools/icons/Pin.svg")

const TURBO_OPEN = preload("res://addons/turbo_tools/turbo_open.tscn")

const TURBO_GENERATE = preload("res://addons/turbo_tools/turbo_generate.tscn")
const STREAM_MODIFIED_NOTIFICATION = preload("res://addons/turbo_tools/modified_notification.wav")

var script_editor: ScriptEditor
var code_editor: CodeEdit
var caret_lines: Array[int] = []

var audio_modified: AudioStreamPlayer = AudioStreamPlayer.new()

var format: TurboFormat = TurboFormat.new()
@onready var generate: TurboGenerate

var turbo_open_window: Window

var line_count_window: Window

# Run Scene Pin
var run_scene_button: Button
var pinned_scene: String
var run_scene_callable
var popup_menu: PopupMenu

const CONFIG_PATH = "res://addons/turbo_tools/config.cfg"
var config: ConfigFile


func _enter_tree() -> void:
	EditorInterface.get_script_editor().editor_script_changed.connect(_on_editor_script_changed)
	
	config = ConfigFile.new()
	
	if config.load(CONFIG_PATH) != OK:
		config.save(CONFIG_PATH)
	
	find_and_add_run_scene_pin()
	init_generate()
	
	format.turbo = self
	
	add_child(audio_modified)
	audio_modified.stream = STREAM_MODIFIED_NOTIFICATION
	_on_editor_script_changed(null)
	
	scene_changed.connect(_on_scene_changed)
	
	pinned_scene = config.get_value("run_scene_pin", "pinned_scene", "")
	add_tool_menu_item("Count Lines", count_lines)
	add_tool_menu_item("Open Editor Folder", open_editor_folder)


func open_editor_folder():
	OS.shell_open(OS.get_executable_path().get_base_dir())


func init_generate() -> void:
	generate = TURBO_GENERATE.instantiate()
	generate.turbo = self
	generate.visible = false


func _exit_tree() -> void:
	generate.queue_free()
	audio_modified.queue_free()
	
	run_scene_button.pressed.connect(run_scene_callable)
	run_scene_button.pressed.disconnect(_on_run_scene_pressed)
	run_scene_button.gui_input.disconnect(_on_run_scene_button_gui_input)
	remove_tool_menu_item("Count Lines")


func _on_editor_script_changed(_script) -> void:
	if is_instance_valid(generate):
		if generate.get_parent():
			generate.get_parent().remove_child(generate)
	else:
		init_generate()
	if is_instance_valid(code_editor):
		code_editor.caret_changed.disconnect(_on_caret_changed)
	
	script_editor = EditorInterface.get_script_editor()
	if script_editor.get_current_editor() and script_editor.get_current_editor().get_base_editor():
		code_editor = script_editor.get_current_editor().get_base_editor()
		code_editor.add_child(generate)
		
		code_editor.caret_changed.connect(_on_caret_changed)
		
		if get_setting("generate_class_name"):
			add_class_name()


func add_class_name() -> void:
	var file_path = EditorInterface.get_script_editor().get_current_script().resource_path
	var generated_class_name = file_path.get_file().get_basename().to_pascal_case()
	if ProjectSettings.has_setting("autoload/%s" % generated_class_name):
		prints(ProjectSettings.get_setting("autoload/%s" % generated_class_name))
		# Skip for autoloads
		return
	var has_class_name: bool = false
	for i in code_editor.get_line_count():
		if code_editor.get_line(i).begins_with("class_name"):
			has_class_name = true
			break
	if not has_class_name and EditorInterface.get_script_editor().get_current_script():
		var line = "class_name %s" % [generated_class_name]
		var at_line: int = 0
		if code_editor.get_line(0).begins_with("@tool"):
			at_line = 1
		code_editor.insert_line_at(at_line, line)


func _on_scene_changed(root: Node) -> void:
	var scene_name = root.scene_file_path.get_file().get_basename().to_pascal_case()
	if root.name != scene_name:
		print_rich("[color=webgray]Root Node Renamed from[/color] %s [color=webgray]to[/color] %s." % [root.name, scene_name])
		root.name = scene_name


func _on_caret_changed() -> void:
	if not is_instance_valid(code_editor):
		return
	if not EditorInterface.get_script_editor().get_current_script():
		return
	var caret_lines_current: Array[int] = []
	for caret_index in code_editor.get_caret_count():
		var line = code_editor.get_caret_line(caret_index)
		if not caret_lines_current.has(line):
			caret_lines_current.push_back(line)
	
	for line_num in caret_lines:
		if not caret_lines_current.has(line_num):
			if format.format_line(line_num):
				audio_modified.play()
	
	caret_lines = caret_lines_current


func _input(event) -> void:
	if event is InputEventKey and event.is_pressed():
		if line_count_window and event.keycode == KEY_ESCAPE:
			line_count_window.queue_free()
		if turbo_open_window and event.keycode == KEY_ESCAPE:
			turbo_open_window.queue_free()
			
		if Input.is_key_pressed(KEY_CTRL):
			if event.keycode == KEY_SEMICOLON:
				generate.open()
			if get_setting("turbo_open") and event.keycode == KEY_P and not Input.is_key_pressed(KEY_SHIFT):
				if is_instance_valid(turbo_open_window):
					return
				turbo_open_window = Window.new()
				turbo_open_window.close_requested.connect(turbo_open_window.queue_free)
				turbo_open_window.size = Vector2(600, 800)
				turbo_open_window.always_on_top = true
				add_child(turbo_open_window)
				turbo_open_window.position = get_window().position
				turbo_open_window.move_to_center()
				var turbo_open := TURBO_OPEN.instantiate()
				turbo_open_window.add_child(turbo_open)
				
				if EditorInterface.get_editor_main_screen().get_child(2).visible:
					turbo_open.load_scripts()
				else:
					turbo_open.load_scenes()


func find_and_add_run_scene_pin() -> void:
	run_scene_button = get_tree().root.find_children("", "EditorRunBar", true, false)[0].get_child(0).get_child(0).get_child(4)
	run_scene_callable = run_scene_button.pressed.get_connections()[0].callable
	run_scene_button.pressed.disconnect(run_scene_callable)
	run_scene_button.pressed.connect(_on_run_scene_pressed)
	run_scene_button.gui_input.connect(_on_run_scene_button_gui_input)
	
	popup_menu = PopupMenu.new()
	popup_menu.add_icon_item(ICON_PIN, "Pin Current Scene")
	popup_menu.id_pressed.connect(_on_popup_pressed)
	
	run_scene_button.add_child(popup_menu)


func _on_run_scene_pressed() -> void:
	if pinned_scene:
		get_editor_interface().play_custom_scene(pinned_scene)
	else:
		get_editor_interface().play_custom_scene(get_editor_interface().get_edited_scene_root().scene_file_path)


func _on_run_scene_button_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if popup_menu.item_count > 1:
				popup_menu.remove_item(1)
			if pinned_scene != "":
				popup_menu.add_icon_item(ICON_CLEAR, "Clear Pin (%s)" % pinned_scene)
			popup_menu.popup(Rect2(run_scene_button.get_screen_position(), Vector2.ZERO))


func _on_popup_pressed(id) -> void:
	if id == 0:
		pinned_scene = get_editor_interface().get_edited_scene_root().scene_file_path
	else:
		pinned_scene = ""
	config.set_value("run_scene_pin", "pinned_scene", pinned_scene)
	config.save(CONFIG_PATH)


func count_lines() -> void:
	var result := {
		"files": 0,
		"code": 0,
		"disabled": 0,
		"comments": 0,
		"comments_critical": 0,
		"comments_warning": 0,
		"comments_notice": 0,
		"documentation_comments": 0,
		"functions": 0,
		"functions_typed": 0,
		"variables": 0,
		"variables_typed": 0,
		"signals": 0,
		"conditions": 0,
		"loops": 0,
		"other": 0,
		"total": 0,
	}
	count_dir("res://", result)
	
	
	line_count_window = Window.new()
	line_count_window.close_requested.connect(line_count_window.queue_free)
	line_count_window.size = Vector2(400, 400)
	line_count_window.always_on_top = true
	add_child(line_count_window)
	line_count_window.move_to_center()
	
	var margin_container := MarginContainer.new()
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin_value = 16
	margin_container.add_theme_constant_override("margin_top", margin_value)
	margin_container.add_theme_constant_override("margin_left", margin_value)
	margin_container.add_theme_constant_override("margin_bottom", margin_value)
	margin_container.add_theme_constant_override("margin_right", margin_value)

	line_count_window.add_child(margin_container)
	
	var label := Label.new()
	margin_container.add_child(label)
	
	var output: String = ""
	output += "%s line count:\n\n" % ProjectSettings.get_setting("application/config/name")
	output += "📜 %s scripts (excluding addons)\n" % result.files
	output += "📝 %s lines (excluding blanks)\n" % result.total
	output += "\n"
	output += "⚙️ %s lines of code\n" % result.code
	output += "        🔨 %s functions (%d%% typed)\n" % [result.functions, (float(result.functions_typed) / result.functions) * 100]
	output += "        📦 %s variables + const (%d%% typed)\n" % [result.variables, (float(result.variables_typed) / result.variables) * 100]
	output += "        ✋ %s conditions\n" % result.conditions
	output += "        🔁 %s loops\n" % result.loops
	output += "        ⚙️ %s other\n" % result.other
	output += "\n"
	output += "#️ %s comments\n" % [result.comments + result.documentation_comments + result.disabled]
	output += "        🧠 %s code comments (%s critical, %s warning, %s notice)\n" % [result.comments, result.comments_critical, result.comments_warning, result.comments_notice]
	output += "        📕 %s documentation comments\n" % result.documentation_comments
	output += "        💀 %s disabled\n" % result.disabled
	
	label.text = output


func count_dir(path: String, result: Dictionary) -> void:
	var directories = DirAccess.get_directories_at(path)
	for d in directories:
		if d == "turbo_tools" or d == "godot-cpp":
			continue
		if path == "res://":
			count_dir(path + d, result)
		else:
			count_dir(path + "/" + d, result)
	
	var files = DirAccess.get_files_at(path)
	
	for f in files:
		if not f.get_extension() == "gd":
			continue
		result.files += 1
		var file := FileAccess.open(path + "/" + f, FileAccess.READ)
		var lines := file.get_as_text().split("\n")
		
		for line: String in lines:
			var line_stripped := line.strip_edges()
			if line_stripped == "":
				continue
			result.total += 1
			if line_stripped.begins_with("#"):
				if line_stripped.begins_with("## "):
					result.documentation_comments += 1
				elif line_stripped.begins_with("# "):
					result.comments += 1
					continue
				elif (
						line_stripped.begins_with("#ALERT")
						or line_stripped.begins_with("#ATTENTION")
						or line_stripped.begins_with("#CAUTION")
						or line_stripped.begins_with("#CRITICAL")
						or line_stripped.begins_with("#DANGER")
						or line_stripped.begins_with("#SECURITY")
				):
					result.comments += 1
					result.comments_critical += 1
				elif (
						line_stripped.begins_with("#BUG")
						or line_stripped.begins_with("#DEPRECATED")
						or line_stripped.begins_with("#FIXME")
						or line_stripped.begins_with("#HACK")
						or line_stripped.begins_with("#TASK")
						or line_stripped.begins_with("#TBD")
						or line_stripped.begins_with("#TODO")
						or line_stripped.begins_with("#WARNING")
				):
					result.comments += 1
					result.comments_warning += 1
				elif (
						line_stripped.begins_with("#INFO")
						or line_stripped.begins_with("#NOTE")
						or line_stripped.begins_with("#NOTICE")
						or line_stripped.begins_with("#TEST")
						or line_stripped.begins_with("#TESTING")
				):
					result.comments += 1
					result.comments_notice += 1
				else:
					result.disabled += 1
				continue
			
			result.code += 1
			if line_stripped.begins_with("func "):
				result.functions += 1
				if line_stripped.contains("->"):
					result.functions_typed += 1
				else:
					print(line_stripped, path + "/" + f)
			elif (
					line_stripped.begins_with("var ")
					or line_stripped.begins_with("@onready ")
					or line_stripped.begins_with("@export ")
			):
				if line_stripped.contains(":"):
					result.variables_typed += 1
				else:
					print(line_stripped, path + "/" + f)
				result.variables += 1
			elif line_stripped.begins_with("const "):
				result.variables += 1
				result.variables_typed += 1
			elif line_stripped.begins_with("signal "):
				result.signals += 1
			elif line_stripped.begins_with("if "):
				result.conditions += 1
			elif line_stripped.begins_with("for ") or line_stripped.begins_with("while "):
				result.loops += 1
			else:
				result.other += 1


func get_setting(key:String) -> bool:
	return config.get_value("preferences", "key", true)
