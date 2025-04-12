@tool
## Helps manage auto assigning export references to nodes added as children of an EffectReceiverComponent.


func update_editor_children_exports(node: EffectReceiverComponent, children: Array[Node]) -> void:
	for child: Node in children:
		if child is DmgHandler:
			node.dmg_handler = child
		if child is HealHandler:
			node.heal_handler = child

func ensure_effect_handler_resource_unique_to_scene(node: EffectReceiverComponent) -> void:
	if node.storm_syndrome_handler: node.storm_syndrome_handler.resource_local_to_scene = true
	if node.knockback_handler: node.knockback_handler.resource_local_to_scene = true
	if node.stun_handler: node.stun_handler.resource_local_to_scene = true
	if node.poison_handler: node.poison_handler.resource_local_to_scene = true
	if node.regen_handler: node.regen_handler.resource_local_to_scene = true
	if node.frostbite_handler: node.frostbite_handler.resource_local_to_scene = true
	if node.burning_handler: node.burning_handler.resource_local_to_scene = true
	if node.time_snare_handler: node.time_snare_handler.resource_local_to_scene = true
	if node.life_steal_handler: node.life_steal_handler.resource_local_to_scene = true

func update_editor_parent_export(node: EffectReceiverComponent, parent: Node) -> void:
	if parent is DynamicEntity or parent is RigidEntity or parent is StaticEntity:
		node.affected_entity = parent
	if parent.has_node("HealthComponent"):
		node.health_component = parent.get_node("HealthComponent")
	if parent.has_node("StaminaComponent"):
		node.stamina_component = parent.get_node("StaminaComponent")
	if parent.has_node("LootTableComponent"):
		node.loot_table_component = parent.get_node("LootTableComponent")
	if parent.has_node("StatusEffectsComponent"):
		parent.get_node("StatusEffectsComponent").effect_receiver = node

func _init(node: EffectReceiverComponent) -> void:
	if Engine.is_editor_hint():
		return
	if node.storm_syndrome_handler: node.storm_syndrome_handler.initialize(node)
	if node.knockback_handler: node.knockback_handler.initialize(node)
	if node.stun_handler: node.stun_handler.initialize(node)
	if node.poison_handler: node.poison_handler.initialize(node)
	if node.regen_handler: node.regen_handler.initialize(node)
	if node.frostbite_handler: node.frostbite_handler.initialize(node)
	if node.burning_handler: node.burning_handler.initialize(node)
	if node.time_snare_handler: node.time_snare_handler.initialize(node)
	if node.life_steal_handler: node.life_steal_handler.initialize(node)
