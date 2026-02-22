extends II
class_name ConsumableII

@export_group("Consumable Specific")
@export_storage var esi: ESI = ESI.new() ## The effect source instance to use on consumption.


## Sets up the effect source instances to copy the effect sources from the stats.
func initialize_esis() -> void:
	esi.es = stats.effect_source
