# Французский шеф

Игра про шеф-повара ресторана французской кухни. Рецепты нелинейные: порядок шагов
и варианты приготовления влияют на результат. Рецепты лежат в JSON-файлах (`data/recipes/`).

## Как запустить
1. Установи Godot 4 (https://godotengine.org/download/macos/).
2. В окне Godot нажми «Импорт» и выбери файл `project.godot` из этой папки.
3. Нажми кнопку ▶ (или F5) в правом верхнем углу.

## Состояние
Шаг 4: экраны выбора рецепта и готовки. Логика: scripts/cooking_logic.gd, тесты: tests/.

## Проверка логики без окна
```
/Users/mac/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_cooking_logic.gd
```
