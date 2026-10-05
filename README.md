# Французский шеф

Игра про шеф-повара ресторана французской кухни. Рецепты нелинейные: порядок шагов
и варианты приготовления влияют на результат. Рецепты лежат в JSON-файлах (`data/recipes/`).

## Как запустить
1. Установи Godot 4 (https://godotengine.org/download/macos/).
2. В окне Godot нажми «Импорт» и выбери файл `project.godot` из этой папки.
3. Нажми кнопку ▶ (или F5) в правом верхнем углу.

## Состояние
Шаг 5: сохранение монет (user://save.json). Экраны: выбор рецепта и готовка. Логика: scripts/cooking_logic.gd, тесты: tests/.

## Проверка логики без окна
```
/Users/mac/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_cooking_logic.gd
```

## Сборка APK
При каждом обновлении ветки `main` GitHub сам собирает APK (файл `.github/workflows/android.yml`)
и кладёт его на страницу Releases как «latest». Скачай `french-chef.apk` на телефон и установи.
