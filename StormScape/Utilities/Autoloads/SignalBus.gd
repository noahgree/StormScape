extends Node
## An autoload singleton for managing the bussing of signals.
##
## This node acts as a middleman to keep multiple signal users from having to connect all over the place.
## For example, use this to create a "EnemyDied" signal and then wherever you need to
## depend on the value, you connect to this script and not all the enemies individually.

@warning_ignore("unused_signal") signal player_ready(player: Player)
@warning_ignore("unused_signal") signal focused_ui_opened
@warning_ignore("unused_signal") signal focused_ui_closed
@warning_ignore("unused_signal") signal slot_hovered(slot: Slot)
@warning_ignore("unused_signal") signal slot_not_hovered
@warning_ignore("unused_signal") signal alternate_inv_open_request(inv_source_node: Node2D)
@warning_ignore("unused_signal") signal player_in_safe_zone_changed(is_in_safe_zone: bool)
@warning_ignore("unused_signal") signal player_sneak_state_changed(is_sneaking: bool)
