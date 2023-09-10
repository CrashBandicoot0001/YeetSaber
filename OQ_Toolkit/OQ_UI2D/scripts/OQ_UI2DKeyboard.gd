extends Node3D

@export var show_text_input := true;
# if 'show_text_input' is enabled and this flag is set true, then
# the text input box will aquire focus when then keyboard gains visibilty
@export var focus_on_visible := false;
@export var cancelable := true: set = _set_cancelable
# the minimum number of characters needed to be entered before the enter button
# will be enabled
@export var min_chars_to_enable_enter := 0

# if 'true' then the keyboard will make sure the first letter of each word is
# capitalized
@export var is_name_input := false

var _text_edit : TextEdit = null;
var _keyboard = null;

signal text_input_cancel();
signal text_input_enter(text);


func _on_cancel():
	emit_signal("text_input_cancel");
	_text_edit.text = "";


func _on_enter():
	emit_signal("text_input_enter", _text_edit.text);
	_text_edit.text = "";


func _ready():
	_text_edit = $OQ_UI2DCanvas_TextInput.find_child("TextEdit", true, false);
	_keyboard = $OQ_UI2DCanvas_Keyboard.find_child("VirtualKeyboard", true, false);
	_keyboard.set_cancelable(cancelable)
	
	# force update of things that based on the text input
	#  * enable/disable enter key based on min char length
	#  * name input capitalization
	_on_TextEdit_text_changed()
	
	if (show_text_input):
		_keyboard.connect("cancel_pressed", Callable(self, "_on_cancel"));
		_keyboard.connect("enter_pressed", Callable(self, "_on_enter"));
	
	if (show_text_input):
		$OQ_UI2DCanvas_TextInput.visible = true;
		_text_edit.grab_focus();
	else:
		$OQ_UI2DCanvas_TextInput.visible = false; # ?? maybe delte the node if not used

func _show():
	show()
	$OQ_UI2DCanvas_Keyboard._show()
	$OQ_UI2DCanvas_TextInput._show()
	
func _hide():
	hide()
	$OQ_UI2DCanvas_Keyboard._hide()
	$OQ_UI2DCanvas_TextInput._hide()

func _set_cancelable(value):
	cancelable = value
	if _keyboard != null:
		_keyboard.set_cancelable(cancelable)

func _on_OQ_UI2DKeyboard_visibility_changed():
	if visible and show_text_input and focus_on_visible:
		_text_edit.grab_focus()

func _on_TextEdit_text_changed():
	var text_len = _text_edit.text.length()
	var disable_enter = text_len < min_chars_to_enable_enter
	_keyboard.enter_button_disabled(disable_enter)
	
	if is_name_input:
		# default first letter of each 'word' to a capital
		var upper_case = text_len == 0
		if text_len > 0:
			upper_case = _text_edit.text[-1] == ' '
		_keyboard.set_upper_case(upper_case)
