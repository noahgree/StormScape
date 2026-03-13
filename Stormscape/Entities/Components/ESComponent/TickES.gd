extends EffectSource
class_name TickES
## As specific kind of effect source that tailors to those being applied from ticks during a condition.

@export_storage var source_type: SourceType = SourceType.FROM_CONDITION_TICK ## A tag used to determine the source of the effect source.
@export_storage var source_tags: Array[Tag] = [] ## Additional information to pass to whatever receieves this effect source to make sure it should apply.
@export_storage var can_hit_self: bool = true ## Whether or not this effect source can be applied to what created it.

@export_custom(PROPERTY_HINT_FLAGS, "Enemies, Allies", PROPERTY_USAGE_STORAGE) var teams_hit_by_bad: int = Globals.BadAffectedTeams.ENEMIES | Globals.BadAffectedTeams.ALLIES ## Which entity teams in relation to who produced this source are affected by this damage.
@export_custom(PROPERTY_HINT_FLAGS, "Enemies, Allies", PROPERTY_USAGE_STORAGE) var teams_hit_by_good: int = Globals.GoodAffectedTeams.ALLIES | Globals.GoodAffectedTeams.ENEMIES ## Which entity teams in relation to who produced this source are affected by this healing.
@export_storage var conditions: Array[Condition] = [] ## The array of conditions that can be applied to the receiving entity. Should be empty here.

@export_custom(PROPERTY_HINT_LAYERS_2D_PHYSICS, "", PROPERTY_USAGE_STORAGE) var scanned_phys_layers: int = 0b1101111 ## The collision mask that this source scans in order to apply affects to.
