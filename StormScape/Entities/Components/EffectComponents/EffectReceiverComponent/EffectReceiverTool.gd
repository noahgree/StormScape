@tool
extends Node

func update_editor_children_exports(node: EffectReceiverComponent, children: Array[Node]) -> void:
	for child in children:
		if child is DmgHandler:
			node.dmg_handler = child
		if child is HealHandler:
			node.heal_handler = child
		if child is KnockbackHandler:
			node.knockback_handler = child
		if child is StunHandler:
			node.stun_handler = child
		if child is PoisonHandler:
			node.poison_handler = child
		if child is RegenHandler:
			node.regen_handler = child
		if child is FrostbiteHandler:
			node.frostbite_handler = child
		if child is BurningHandler:
			node.burning_handler = child
		if child is TimeSnareHandler:
			node.time_snare_handler = child

func update_editor_parent_export(node: EffectReceiverComponent, parent: Node) -> void:
	if parent is DynamicEntity or parent is RigidEntity or parent is StaticEntity:
		node.affected_entity = parent
	if parent.has_node("HealthComponent"):
		node.health_component = parent.get_node("HealthComponent")
