extends EffectSource
class_name NormalES
## The normal type of effect source that offers all features. Does not originate from condition ticks.

@export var source_type: SourceType ## A tag used to determine the source of the effect source.
@export var source_tags: Array[Tag] = [] ## Additional information to pass to whatever receieves this effect source to make sure it should apply.
@export var can_hit_self: bool = true ## Whether or not this effect source can be applied to what created it.
@export_flags("Enemies", "Allies") var teams_hit_by_bad: int = Globals.BadAffectedTeams.ENEMIES ## Which entity teams in relation to who produced this source are affected by this damage.
@export_flags("Enemies", "Allies") var teams_hit_by_good: int = Globals.GoodAffectedTeams.ALLIES ## Which entity teams in relation to who produced this source are affected by this healing.
@export var conditions: Array[Condition] = [] ## The array of conditions that can be applied to the receiving entity.

@export_group("Advanced")
@export_flags_2d_physics var scanned_phys_layers: int = 0b1101111 ## The collision mask that this source scans in order to apply affects to.
