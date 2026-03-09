@tool
extends PhysicsBody2D
class_name Entity
## Base class for all entities in the game.

enum ClassType { DYNAMIC = 1, RIGID = 2, STATIC = 4 } ## The kinds of subclasses, used for comparisons and matches.

@export var team: Globals.Teams = Globals.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export var is_object: bool = false ## When true, this entity's collision logic will follow that of a world object, regardless of team. It will also not have an auto_decrementer in its inv, as it shouldn't be holding things that need one.
@export var inv: InvResource ## The inventory data resource for this entity.
@export var loot: LootTableResource ## The loot table resource for this entity.
@export var current_wearables: Array[StringName] = [&"", &"", &"", &"", &""] ## The equipped wearables on this entity.

@onready var sprite: EntitySprite = %EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var esi_receiver: ESIReceiverComponent = get_node_or_null("ESIReceiverComponent") ## The component that handles incoming effect source instances.
@onready var conditions_component: ConditionsComponent = get_node_or_null("ConditionsComponent") ## The node that will cache and manage all conditions for this entity.
@onready var particle_mgr: ParticleEmissionComponent = $ParticleEmissionComponent ## The component responsible for determining the extents and origins of different particle placements.
@onready var detection_component: DetectionComponent = $DetectionComponent ## The component that defines the radius around this entity that an enemy must enter for that enemy to be alerted.
@onready var hp_component: HPComponent = $HPComponent ## The component in charge of entity health and shield.
@onready var item_receiver: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent") ## The item receiver for this entity.
@onready var hands: HandsComponent = get_node_or_null("%HandsComponent") ## The hands item component for the entity.

@export_storage var sc: StatModsCache = StatModsCache.new() ## The resource that will cache and work with all stat mods for this entity. Stands for "stat cache".

const AUTO_DEC_PROCESS_INTERVAL: float = 0.1 ## How often we should process the auto decrementer. Helps with perf.

var class_type: ClassType = ClassType.STATIC ## Used for comparisons and match statements.
var invulnerable: bool = false ## When true, this entity cannot receive ESIs or conditions.
var auto_dec_tick_accumulator: float ## Tracks how long since we have processed the auto decrementer.


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if is_object:
		collision_layer = 0b100000
		match team:
			Globals.Teams.PLAYER:
				add_to_group("player_entities")
			Globals.Teams.ENEMY:
				add_to_group("enemy_entities")
	elif team == Globals.Teams.PLAYER:
		collision_layer = 0b10
		add_to_group("player_entities")
	elif team == Globals.Teams.ENEMY:
		add_to_group("enemy_entities")
		collision_layer = 0b100
	elif team == Globals.Teams.PASSIVE:
		collision_layer = 0b1000

	collision_mask = 0b1101111

	sc.affected_entity = self
	sprite.entity = self
	if inv:
		inv = inv.duplicate()
		inv.initialize_inventory(self)
	if loot:
		loot = loot.duplicate()
		loot.initialize(self)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and inv and not is_object:
		auto_dec_tick_accumulator += delta

		while auto_dec_tick_accumulator >= AUTO_DEC_PROCESS_INTERVAL:
			auto_dec_tick_accumulator -= AUTO_DEC_PROCESS_INTERVAL
			inv.auto_decrementer.process(delta)

## Checks to see if the entity has the passed in wearable already.
## Leaving index as -1 means check every slot, otherwise only check a certain slot index.
func has_wearable(wearable_id: StringName, index: int = -1) -> bool:
	var i: int = 0
	for wearable_stats: WearableStats in get_all_wearables_as_stats(true):
		if wearable_stats and wearable_stats.id == wearable_id:
			if index != -1:
				if i == index:
					return true
				else:
					i += 1
					continue
			else:
				return true
		i += 1
	return false

## Returns an array of variable size containing all verified wearable stats in the current_wearables array.
func get_all_wearables_as_stats(include_empty_slots: bool = false) -> Array[WearableStats]:
	var results: Array[WearableStats] = []
	for wearable_key: StringName in current_wearables:
		if wearable_key != &"":
			var wearable: WearableStats = Items.cached_items.get(wearable_key, null)
			if wearable:
				results.append(wearable)
		elif include_empty_slots:
			results.append(null)
	return results

#region Debug
func _get_configuration_warnings() -> PackedStringArray:
	if (not get_node_or_null("%EntitySprite")) or (not %EntitySprite is EntitySprite):
		return ["This entity must have an EntitySprite typed sprite node. Make sure its name is unique with a %."]
	return []
#endregion
