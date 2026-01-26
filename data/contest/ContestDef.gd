class_name ContestDef
extends Resource

@export var id: String = ""
@export var scope: String = "WEEKLY"
@export var currency: String = "USD"
@export var price: int = 0
@export var time_slice: String = ""
@export var mode: String = "TIME_PUZZLE"
@export var status: String = "OPEN"
@export var prize_pool_cents: int = 0

@export var name: String = ""
@export var start_ts: int = 0
@export var end_ts: int = 0
@export var published: bool = false
@export var map_ids: PackedStringArray = []
@export var buff_cap_per_map: int = 0
@export var bonus_rules: Dictionary = {}
