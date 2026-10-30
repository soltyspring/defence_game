extends RefCounted
## Clock boundary. Services never read the OS clock directly so tests stay deterministic.
## Owner: 06-services. Subclass (see tests/services/fake_clock.gd) to control time.
## Daily caps use the LOCAL calendar day. A user changing the device clock can reset caps;
## this is an accepted low-value exploit (RELEASE_DESIGN_REVIEW.md §3) because there is no server.

func now_unix() -> int:
	return int(Time.get_unix_time_from_system())

## "YYYY-MM-DD" in device local time.
func local_day() -> String:
	var d := Time.get_date_dict_from_system(false)
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]
