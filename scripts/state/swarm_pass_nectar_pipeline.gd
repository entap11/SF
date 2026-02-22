class_name SwarmPassNectarPipeline
extends RefCounted

func pass_xp_from_nectar(nectar_amount: int, pass_multiplier: float) -> float:
	var safe_nectar: int = maxi(0, nectar_amount)
	var safe_multiplier: float = maxf(1.0, pass_multiplier)
	return float(safe_nectar) * safe_multiplier

