@icon("res://Utilities/Debug/EditorIcons/loot_table_component.svg")
extends Node
class_name LootTableComponent
## When attached to an entity, this determines what drops from both normal interactions like damage and on death.

@export var loot_table: LootTable
@export_range(0, 100, 0.1, "suffix:%") var hit_spawn_chance: float = 100.0
@export_range(0, 100, 0.1, "suffix:%") var die_spawn_chance: float = 100.0
@export var remove_when_dropped: bool = false
@export var require_dmg_on_hit: bool = true ## When true, this will not trigger the "Hit" loot table when receiving a hit unless that hit dealt damage.
@export_range(0, 100, 1) var hit_chance_scale: int = 1 ## When above 0, the drop chance will scale up over time based on how long it has been since the last drop, all multiplied by this scaling factor. This prevents the off-chance of there being a long drought of no drops. 0 < x < 1 lowers the scaling factor. 1 < x <= 100 increases it.
@export var rarity_scaling_factors: Dictionary[Globals.ItemRarity, float] = {
		Globals.ItemRarity.COMMON: 0.5,
		Globals.ItemRarity.UNCOMMON: 0.4,
		Globals.ItemRarity.RARE: 0.3,
		Globals.ItemRarity.EPIC: 0.1,
		Globals.ItemRarity.LEGENDARY: 0.05,
		Globals.ItemRarity.SINGULAR: 0.005
	}

@onready var effect_receiver: EffectReceiverComponent = get_parent().effect_receiver

var hit_loot_table_total_weight: float = 0
var die_loot_table_total_weight: float = 0
var times_since_drop: int = 0
var is_dying: bool = false


func _ready() -> void:
	loot_table = loot_table.duplicate() # Because it is shared amongst scenes
	for i: int in range(loot_table.hit_loot_table.size()):
		hit_loot_table_total_weight += loot_table.hit_loot_table[i].weighting
	for i: int in range(loot_table.die_loot_table.size()):
		die_loot_table_total_weight += loot_table.die_loot_table[i].weighting

func handle_effect_source(_effect_source: EffectSource) -> void:
	if is_dying:
		return
	if not _roll_to_check_if_should_drop(true):
		return

	if loot_table.hit_loot_table != null and not loot_table.hit_loot_table.is_empty():
		var entry: LootTableEntry = _get_random_loot_entry(true)
		Item.spawn_on_ground(entry.item, entry.quantity, get_parent().global_position, 15.0, false)

func handle_death() -> void:
	is_dying = true

	if not _roll_to_check_if_should_drop(false):
		return

	var most_recent_effect_src: EffectSource = null
	if effect_receiver: most_recent_effect_src = effect_receiver.most_recent_effect_src

	if loot_table.die_loot_table != null and not loot_table.die_loot_table.is_empty():
		var entry: LootTableEntry = _get_random_loot_entry(false)
		Item.spawn_on_ground(entry.item, entry.quantity, get_parent().global_position, 15.0, false)

func _roll_to_check_if_should_drop(was_hit: bool) -> bool:
	var spawn_chance: float = (hit_spawn_chance if was_hit else die_spawn_chance) / 100.0
	var should_spawn: bool = false
	var random_num: float = randf()
	var increase_factor: float = (times_since_drop * 0.10 * float(hit_chance_scale)) * spawn_chance
	if random_num <= (spawn_chance + increase_factor):
		should_spawn = true
		times_since_drop = 0
	else:
		times_since_drop += 1

	return should_spawn

func _get_random_loot_entry(was_hit: bool) -> LootTableEntry:
	var table_selection: Array[LootTableEntry] = loot_table.hit_loot_table if was_hit else loot_table.die_loot_table
	var total_weight: float = 0.0
	var selected_entry: LootTableEntry = null

	var effective_weights: Array[float] = []
	for entry: LootTableEntry in table_selection:
		var rarity_factor: float = rarity_scaling_factors.get(entry.item.rarity, 1.0)
		var time_factor: float = 1.0 + (entry.last_used * rarity_factor)
		var effective_weight: float = entry.weighting * time_factor
		effective_weights.append(effective_weight)
		total_weight += effective_weight

	var random_value: float = randf() * total_weight
	var cumulative_weight: float = 0.0

	var removal_index: int = -1
	for i: int in range(table_selection.size()):
		cumulative_weight += effective_weights[i]
		if random_value < cumulative_weight and selected_entry == null:
			table_selection[i].last_used = 0
			table_selection[i].spawn_count += 1
			selected_entry = table_selection[i]
			if remove_when_dropped:
				removal_index = i
		else:
			table_selection[i].last_used += 1

	if removal_index != -1:
		table_selection.remove_at(removal_index)

	table_selection.shuffle()

	if DebugFlags.PrintFlags.loot_table_updates:
		_print_table(true)

	return selected_entry

## Debug function used to print out the current loot table data.
func _print_table(use_hit: bool) -> void:
	var table: Array[LootTableEntry] = loot_table.hit_loot_table if use_hit else loot_table.die_loot_table
	print("-----------------------------------------------------------------------------------")
	for i: int in range(table.size()):
		print_rich("+++++++++++++++ " + str(table[i].item) + " | Last Used: " + str(table[i].last_used) + " | Weighting: " + str(table[i].weighting) + " | Spawn Count: [b]" + str(table[i].spawn_count) + "[/b] +++++++++++++++")
