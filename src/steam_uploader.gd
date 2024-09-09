class_name SteamUploader
extends PanelContainer


const ENCRYPT_PW : String		= "STEAMUPLOADGUI"
const SETTINGS_FILE : String	 = "/SteamUploadGUI_settings.bin"
const STEAMCMD : String			= "steamcmd.exe"
const GODOT_BAT : String		= "godot_exec.bat"
const BATCH_CONTENT : String	= "@echo off\nSTART cmd {mode} \"\"{path}steamcmd.exe\" {args}\""
const STEAM_GUARD : String		= "cd {path} && {steam_cmd} \"set_steam_guard_code {guard_code}\""
const TEXT_WAIT_CLOSE : String	= "Please close Steam shell when it is done to continue.\nUploading App ID '%s'"
const TEXT_WAIT : String		= "Waiting for Content Builder and Upload.\nUploading App ID '%s'"
const AppGroupScene : PackedScene	= preload("res://app_group.tscn")

var local_dir : String			= ""
var contentbuilder_dir : String = ""
var scripts_path : String		= ""
var builder_path : String		= ""
var steam_apps : Array			= []
var users : Dictionary			= {}

var regex_appid : RegEx		= RegEx.new()
var regex_descr : RegEx		= RegEx.new()

@onready var settings_checkbox: Button = %SettingsCheckBox
@onready var user_list: VBoxContainer = %UserList
@onready var add_users_button: Button = %AddUsersButton
@onready var users_hbox: HBoxContainer = %UsersHbox
@onready var add_user_name_line_edit: LineEdit = %AddUserNameLineEdit
@onready var save_pw: CheckBox = %SavePW
@onready var user_selection_button: OptionButton = %UserSelectionButton
@onready var user_password_edit: LineEdit = %UserPasswordEdit
@onready var user_dialog: PopupPanel = %UserDialog
@onready var settings_group: VBoxContainer = %SettingsGroup
@onready var send_steam_guard_button: Button = %SendSteamGuardButton
@onready var steam_guard_code_edit: LineEdit = %SteamGuardCodeEdit
@onready var steam_guard_popup: PopupPanel = %SteamGuardPopup
@onready var keep_shell_open: CheckBox = %KeepShellOpen
@onready var steam_upload_label: Label = %SteamUploadLabel
@onready var steam_uploading_popup: PopupPanel = %SteamUploadingPopup
@onready var password_missing: Panel = %PasswordMissing
@onready var upload_button: Button = %UploadButton
@onready var selected_apps_check_box: CheckBox = %SelectedAppsCheckBox
@onready var apps_to_upload: VBoxContainer = %AppsToUpload
@onready var apps_error_message: RichTextLabel = %AppsErrorMessage
@onready var content_builder_path_edit: LineEdit = %ContentBuilderPathEdit

func _ready() -> void:
	regex_appid.compile("\"appid\".\"(.*)\"")
	regex_descr.compile("\"desc\".\"(.*)\"")
	
	local_dir = ProjectSettings.globalize_path("res://")
	if local_dir == "":
		local_dir = OS.get_executable_path().get_base_dir()
	else:
		local_dir = local_dir.get_base_dir()
	contentbuilder_dir = local_dir
	
	# Load local Settings saved from last Upload
	if FileAccess.file_exists(local_dir + SETTINGS_FILE):
		var save_pw_file: FileAccess
		save_pw_file = FileAccess.open_encrypted_with_pass(local_dir + SETTINGS_FILE, FileAccess.READ, ENCRYPT_PW)
		var settings_json_result: Dictionary = JSON.parse_string(save_pw_file.get_as_text())
		if settings_json_result:
			users = settings_json_result.users
			contentbuilder_dir = settings_json_result.path
		save_pw_file.close()
	for u in users.keys():
		if not users[u].has("save_pw") or not users[u].has("pw") or not users[u].has("username"):
			users.erase(u)
	update_users()
	content_builder_path_edit.text = contentbuilder_dir
	if check_contentbuilder_path():
		generate_apps_from_vdfs()


func clear_apps():
	# Clear old list of Steam apps...
	if not steam_apps.is_empty():
		for steam_app in steam_apps:
			steam_app.queue_free()
		steam_apps.clear()


func generate_apps_from_vdfs():
	clear_apps()
	scripts_path = contentbuilder_dir + "/scripts/"
	# Get all the files located in the /scripts/ folder
	if DirAccess.dir_exists_absolute(scripts_path):
		apps_error_message.hide()
		var files : Array = list_vdf_files_in_directory(scripts_path)
		for file_name in files:
			if not FileAccess.file_exists(scripts_path + file_name):
				continue
			var file := FileAccess.open(scripts_path + file_name, FileAccess.READ)
			var file_content : String = file.get_as_text()
			file_content = file_content.to_lower()
			file.close()
			if file_content.left(10) != "\"appbuild\"":
				# The file is not a "app" vdf, only a depot vdf
				continue
			
			# Create the App Group elements
			var new_app_group: AppGroup = AppGroupScene.instantiate()
			new_app_group.setup(get_appid(file_content), get_desc(file_content), file_name)
			apps_to_upload.add_child(new_app_group)
			selected_apps_check_box.button_pressed = true
			steam_apps.append(new_app_group)
	else:
		apps_error_message.show()


func check_contentbuilder_path() -> bool:
	builder_path = contentbuilder_dir + "/builder/"
	if !DirAccess.dir_exists_absolute(builder_path):
		clear_apps()
		settings_checkbox.button_pressed = true
		apps_error_message.show()
		upload_button.text = "Builder path not found (\"tools\\ContentBuilder\\builder\\\")!"
		upload_button.disabled = true
		return false
	else:
		if not FileAccess.file_exists(builder_path + STEAMCMD):
			apps_error_message.show()
			upload_button.text = "steamcmd.exe not found (\"tools\\ContentBuilder\\builder\\steamcmd.exe\")!"
			upload_button.disabled = true
			return false
		else:
			upload_button.text = "Upload"
			upload_button.disabled = false
			return true


func get_appid(_string:String) -> String:
	var s_id_r : RegExMatch = regex_appid.search(_string)
	if s_id_r:
		return s_id_r.get_string(1)
	return "App ID not found!"


func get_desc(_string:String) -> String:
	var s_desc_r : RegExMatch = regex_descr.search(_string)
	if s_desc_r:
		return s_desc_r.get_string(1)
	return "Desc not found!"


func list_vdf_files_in_directory(path:String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and file.ends_with(".vdf"):
			files.append(file)
	
	dir.list_dir_end()
	return files


func save_settings() -> void:
	# Save the Settings
	var save_pw_file := FileAccess.open_encrypted_with_pass(local_dir + SETTINGS_FILE, FileAccess.WRITE, ENCRYPT_PW)
	var settings_dict := {
		"path" : content_builder_path_edit.text,
		"users" : users
		}
	save_pw_file.store_string(JSON.stringify(settings_dict))
	save_pw_file.close()


func _on_UploadButton_pressed() -> void:
	save_settings()
	
	var selected_user := get_selected_user_credentials()
	
	if selected_user.pw == "":
		var tween := create_tween()
		tween.interpolate_property(password_missing, "position:x", 0, 5, 0.05, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.interpolate_property(password_missing, "position:x", 5, -5, 0.1, Tween.TRANS_SINE, Tween.EASE_OUT, 0.05)
		tween.interpolate_property(password_missing, "position:x", -5, 0, 0.05, Tween.TRANS_SINE, Tween.EASE_OUT, 0.15)
		tween.interpolate_property(password_missing, "modulate:a", 0.5, 1.0, 0.05, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.interpolate_property(password_missing, "modulate:a", 1.0, 0.5, 0.5, Tween.TRANS_SINE, Tween.EASE_OUT, 0.05)
		tween.start()
		return
	
	# Create an array of the selected vdfs
	# Update the desc content of the vdfs
	var selected_vdfs : Array = []
	for app in steam_apps:
		if app.is_selected() and app.visible:
			selected_vdfs.append({"file": app.vdf_file_name, "app_id": app.app_id})
			var vdf_file := FileAccess.open(scripts_path + app.vdf_file_name, FileAccess.READ)
			var vdf_content : String = vdf_file.get_as_text()
			vdf_file.close()
			var as_lines : PackedStringArray = vdf_content.split("\n")
			for i in as_lines.size():
				if as_lines[i].strip_edges().begins_with("\"desc\""):
					as_lines[i] = as_lines[i].split("\"desc\"")[0] + ("\"desc\" \"%s\"" % app.desc)
					break
			var vdf_write_file := FileAccess.open(scripts_path + app.vdf_file_name, FileAccess.WRITE)
			vdf_write_file.store_string("\n".join(as_lines))
			vdf_write_file.close()
	
	# Upload each App from the selected vdfs
	# A batch file is generated for every upload. This is a workaround of the problem
	# That 'blocking' on OS.execute() while showing the shell will lead to an empty
	# shell window as the stdout is consumed.
	for upload in selected_vdfs:
		var vdf_path: String = "\"../scripts/%s\"" % upload.file
		var args : PackedStringArray = ["+login", selected_user.username, selected_user.pw, "+run_app_build", vdf_path, "+quit"]
		var shell_mode: String = "/k" if keep_shell_open.button_pressed else "/c"
		# Open the Popup informing the user that this is paused until the shells are closed
		steam_uploading_popup.popup()
		steam_upload_label.text = TEXT_WAIT_CLOSE % upload.app_id if keep_shell_open.button_pressed else TEXT_WAIT % upload.app_id
		await get_tree().idle_frame
		var bat_file := FileAccess.open(local_dir + "godot_exec.bat", FileAccess.WRITE)
		bat_file.store_string(BATCH_CONTENT.format({"mode": shell_mode, "path": builder_path, "args": " ".join(args)}))
		bat_file.close()
		OS.execute(local_dir + "godot_exec.bat", [], [], true)
	
	await get_tree().idle_frame
	DirAccess.remove_absolute(local_dir + "godot_exec.bat")
	steam_uploading_popup.hide()


func _on_SetSteamGuardButton_pressed() -> void:
	steam_guard_popup.popup_centered(Vector2.ONE)
	steam_guard_code_edit.grab_focus()


func _on_SendSteamGuardButton_pressed():
	var cmd_arg = STEAM_GUARD.format({"path": builder_path, "steam_cmd": STEAMCMD, "guard_code": steam_guard_code_edit.text, })
	OS.execute("cmd", ["/c", cmd_arg], [], false, true)
	steam_guard_popup.hide()


func _on_SteamGuardCodeEdit_text_changed(new_text:String) -> void:
	send_steam_guard_button.disabled = new_text.length() < 5


func _on_ContentBuilderPathEdit_text_entered(new_text:String) -> void:
	contentbuilder_dir = new_text.trim_suffix("\\")
	if check_contentbuilder_path():
		generate_apps_from_vdfs()


func _on_OpenDirButton_pressed():
	$PopupLayer/FileDialog.popup_centered()


func _on_FileDialog_dir_selected(dir):
	_on_ContentBuilderPathEdit_text_entered(dir)
	content_builder_path_edit.text = contentbuilder_dir


func _on_RefreshButton_pressed():
	generate_apps_from_vdfs()


func _on_popup_about_to_show():
	$PopupLayer/FileDialogBG.show()


func _on_popup_hide():
	$PopupLayer/FileDialogBG.hide()


func _on_GitHubLinkButton_pressed():
	OS.shell_open("https://github.com/RPicster/Steam-Upload-GUI")


func _on_CoffeeLinkButton_pressed():
	OS.shell_open("https://www.buymeacoffee.com/raffa")


func _on_SelectedAppsCheckBox_toggled(button_pressed):
	for a in steam_apps:
		a.set_selected(button_pressed)


func _on_AppFilter_text_changed(filter):
	if filter == "":
		selected_apps_check_box.button_pressed = true
		for a in steam_apps:
			a.show()
	else:
		for a in steam_apps:
			a.visible = a.has_filter_name(filter)
			a.set_selected(a.visible)


func _on_SettingsCheckBox_toggled(button_pressed) -> void:
	settings_group.visible = button_pressed
	settings_checkbox.text = "Hide Settings" if button_pressed else "Show Settings"


func _on_ManageUsersButton_pressed() -> void:
	$PopupLayer/UserDialogBG.show()
	user_dialog.popup_centered()


func update_users(and_selection := true) -> void:
	for c in user_list.get_children():
		c.queue_free()
	if and_selection:
		user_selection_button.clear()
	if users.is_empty():
		users_hbox.hide()
		add_users_button.show()
		return
	users_hbox.show()
	add_users_button.hide()
	for u in users.keys():
		var new_user = load("res://user_panel.tscn").instantiate()
		new_user.username = u
		new_user.save_pw = users[u].save_pw
		user_list.add_child(new_user)
		if and_selection:
			user_selection_button.add_item(u)
		new_user.connect("delete_user", self, "on_delete_user", [u])
		new_user.connect("save_password", self, "on_save_password", [u])
	if and_selection:
		user_selection_button.select(0)
		_on_UserSelectionButton_item_selected(0)


func on_add_user(_text:String) -> void:
	var new_user: Dictionary = create_user_dict(add_user_name_line_edit.text)
	users[add_user_name_line_edit.text] = new_user
	add_user_name_line_edit.text = ""
	update_users()


func create_user_dict(username:String) -> Dictionary:
	return {"username" : username, "save_pw" : true, "pw": ""}


func on_delete_user(username:String):
	if users.has(username):
		users.erase(username)
	update_users()


func on_save_password(save_pw: bool, username: String) -> void:
	if users.has(username):
		users[username].save_pw = save_pw
	update_users(false)


func _on_CloseUserManagementButton_pressed() -> void:
	user_dialog.hide()
	$PopupLayer/UserDialogBG.hide()
	update_users()


func _on_SavePW_pressed():
	var selected_user : String = user_selection_button.get_item_text(user_selection_button.get_selected_id())
	if users.has(selected_user):
		users[selected_user].save_pw = save_pw.button_pressed
	update_users(false)


func get_selected_user_credentials() -> Dictionary:
	var username: String = user_selection_button.get_item_text(user_selection_button.get_selected_id())
	var current_user := {"username": username, "pw": ""}
	if users.has(username):
		current_user.pw = users[username].pw
	return current_user


func _on_UserSelectionButton_item_selected(index):
	var selected_user : String = user_selection_button.get_item_text(index)
	if users.has(selected_user):
		save_pw.button_pressed = users[selected_user].save_pw
		if users[selected_user].save_pw:
			user_password_edit.text = users[selected_user].pw
		else:
			user_password_edit.text = ""
		password_missing.visible = user_password_edit.text == ""


func _on_UserPasswordEdit_text_changed(_new_text) -> void:
	var selected_user : String = user_selection_button.get_item_text(user_selection_button.get_selected_id())
	if users.has(selected_user) and users[selected_user].save_pw:
		users[selected_user].pw = user_password_edit.text
		password_missing.visible = user_password_edit.text == ""


func _on_SaveSettingsButton_pressed():
	save_settings()


func _on_apps_error_message_meta_clicked(meta:Variant) -> void:
	_on_GitHubLinkButton_pressed()
