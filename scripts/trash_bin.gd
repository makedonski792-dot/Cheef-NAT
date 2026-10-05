class_name TrashBin
extends Station
# Мусорка: сюда можно выбросить предмет, который держит повар.


func verb(chef: Chef) -> String:
	return "Выбросить" if chef.held != null else ""


func target_name(chef: Chef) -> String:
	return chef.held.display_name() if chef.held != null else _label


func interact(chef: Chef) -> void:
	if chef.held != null:
		chef.drop()
