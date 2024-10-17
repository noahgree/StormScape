extends Node
## An autoload singleton file for flagging certain debug features like print statements and audio device switches.

class PrintFlags:
	static var char_state_machine_swaps: bool = true

class MainMenuFlags:
	static var skip_main_menu: bool = false

class AudioFlags:
	static var set_debug_output_device: bool = true
