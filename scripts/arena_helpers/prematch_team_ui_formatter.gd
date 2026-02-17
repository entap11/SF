class_name ArenaPrematchTeamUiFormatter
extends RefCounted

func format_team_banner_line(active_seats: Array[int], team_for_seat_cb: Callable, local_seat: int) -> String:
	if active_seats.is_empty():
		return "Teams: --"
	var team_to_seats: Dictionary = _build_team_to_seats(active_seats, team_for_seat_cb)
	var team_ids: Array[int] = []
	for team_id_any in team_to_seats.keys():
		team_ids.append(int(team_id_any))
	team_ids.sort()
	var resolved_local_seat: int = local_seat if local_seat > 0 else 1
	var local_team: int = _resolve_team_id(resolved_local_seat, team_for_seat_cb)
	if team_ids.size() == 2:
		var left_team_id: int = team_ids[0]
		var right_team_id: int = team_ids[1]
		var left_team_seats: Array = (team_to_seats.get(left_team_id, []) as Array).duplicate()
		var right_team_seats: Array = (team_to_seats.get(right_team_id, []) as Array).duplicate()
		left_team_seats.sort()
		right_team_seats.sort()
		var teammate: String = "solo"
		var local_team_seats: Array = (team_to_seats.get(local_team, []) as Array).duplicate()
		local_team_seats.sort()
		for seat_any in local_team_seats:
			var seat_int: int = int(seat_any)
			if seat_int != resolved_local_seat:
				teammate = "P%d" % seat_int
				break
		return "Teams: T%d %s vs T%d %s | You: P%d + %s" % [
			left_team_id,
			format_team_seats_text(left_team_seats),
			right_team_id,
			format_team_seats_text(right_team_seats),
			resolved_local_seat,
			teammate
		]
	var chunks: Array[String] = []
	for team_id in team_ids:
		var seats_for_team: Array = (team_to_seats.get(team_id, []) as Array).duplicate()
		seats_for_team.sort()
		chunks.append("T%d %s" % [team_id, format_team_seats_text(seats_for_team)])
	return "Teams: %s | You: P%d" % [" | ".join(chunks), resolved_local_seat]

func format_team_arrow_line(active_seats: Array[int], team_for_seat_cb: Callable) -> String:
	if active_seats.is_empty():
		return ""
	var team_to_seats: Dictionary = _build_team_to_seats(active_seats, team_for_seat_cb)
	var team_ids: Array[int] = []
	for team_id_any in team_to_seats.keys():
		team_ids.append(int(team_id_any))
	team_ids.sort()
	var chunks: Array[String] = []
	for team_id in team_ids:
		var seats_for_team: Array = (team_to_seats.get(team_id, []) as Array).duplicate()
		seats_for_team.sort()
		if seats_for_team.size() >= 2:
			var members: Array[String] = []
			for seat_any in seats_for_team:
				members.append("P%d" % int(seat_any))
			chunks.append("T%d %s" % [team_id, " --> ".join(members)])
	if chunks.is_empty():
		return "Team Links: --"
	return "Team Links: %s" % "  |  ".join(chunks)

func format_team_seats_text(seats: Array) -> String:
	if seats.is_empty():
		return "-"
	var out: Array[String] = []
	for seat_any in seats:
		out.append("P%d" % int(seat_any))
	return "+".join(out)

func _build_team_to_seats(active_seats: Array[int], team_for_seat_cb: Callable) -> Dictionary:
	var team_to_seats: Dictionary = {}
	for seat in active_seats:
		var team_id: int = _resolve_team_id(seat, team_for_seat_cb)
		if not team_to_seats.has(team_id):
			team_to_seats[team_id] = []
		var seats_for_team: Array = team_to_seats[team_id] as Array
		seats_for_team.append(seat)
		seats_for_team.sort()
		team_to_seats[team_id] = seats_for_team
	return team_to_seats

func _resolve_team_id(seat: int, team_for_seat_cb: Callable) -> int:
	var team_id: int = seat
	if team_for_seat_cb.is_valid():
		team_id = int(team_for_seat_cb.call(seat))
	if team_id <= 0:
		team_id = seat
	return team_id
