class_name LooksDate
extends RefCounted
## Formato de fechas para listas y galería.


static func format(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t))
	return "%02d/%02d/%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]
