# ORAMBO Face Tools 0.1.2 Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Надёжно разрывать SketchUp Curve/Arc, показывать открытые концы и близкие зазоры двумя отдельными командами и выводить явный итог автообновления в строку состояния.

**Architecture:** Чистые алгоритмы диагностики живут в новом `diagnostics.rb` и тестируются без SketchUp. SketchUp-адаптер собирает контексты через `Utils`, преобразует точки в активный контекст и создаёт красные маркеры в изолированных группах. Diagnostics умеет идемпотентно добавить две кнопки в уже работающую панель после hot-reload; обычный запуск регистрирует все пять команд через toolbar.

**Tech Stack:** Ruby 2.7, SketchUp Ruby API, Minitest, PowerShell, PNG toolbar icons, GitHub Actions/Releases.

---

### Task 1: Нативно разрывать Curve/Arc

**Files:**
- Modify: `test/break_to_segments_test.rb`
- Modify: `src/orambo_face_tools/break_to_segments.rb`

- [ ] Добавить тесты: уникальная кривая вызывает ровно один `Edge#explode_curve`; hidden-кривая пропускается.
- [ ] Запустить `ruby -Itest test/break_to_segments_test.rb`; ожидается RED на старом коде удаления/перерисовки.
- [ ] Заменить snapshots/erase/add_line на выбор первого валидного edge каждой уникальной curve и `edge.explode_curve`.
- [ ] Увеличивать `curves_converted` только при успешном возврате; ошибку отдельной кривой писать в report.
- [ ] Запустить тест файла и всю матрицу; ожидается GREEN.
- [ ] Commit: `fix: explode SketchUp curves with native API`.

### Task 2: Чистые алгоритмы открытых концов и gap-пар

**Files:**
- Create: `test/diagnostics_test.rb`
- Create: `src/orambo_face_tools/diagnostics.rb`

- [ ] Написать RED-тесты для `open_vertex_indexes(edge_pairs)`: открытая цепочка возвращает два конца, квадрат — пустой список.
- [ ] Написать RED-тесты для `plan_gap_pairs(points, open_indexes, max_distance)`: выбираются ближайшие взаимоисключающие пары; превышение дистанции исключается; один конец не используется дважды.
- [ ] Реализовать подсчёт degree по индексам вершин и grid/hash-поиск кандидатов через `Utils.grid_key`.
- [ ] Добавить `marker_half_size(bounds_diagonal)` с формулой `diagonal * 0.002`, clamp 10–500 мм; протестировать нижнюю, среднюю и верхнюю границы.
- [ ] Запустить diagnostics test и всю матрицу; commit `feat: detect open ends and nearby gaps`.

### Task 3: Создавать безопасные диагностические группы

**Files:**
- Modify: `test/diagnostics_test.rb`
- Modify: `src/orambo_face_tools/diagnostics.rb`

- [ ] Через лёгкие fake entities написать RED-тест: `replace_marker_group` удаляет только группу с заданным именем и сохраняет другую диагностическую группу.
- [ ] Написать RED-тесты генераторов сегментов: крестик содержит две диагонали вокруг центра; gap-маркер содержит один сегмент между точками.
- [ ] Реализовать `SelectOpenEnds.run`: input selection → contexts → world points → красные крестики в `ORAMBO_Open_Ends`; исходные проблемные edges добавить в selection; показать report.
- [ ] Реализовать `HighlightGaps.run`: запрос distance → contexts → пары → красные линии в `ORAMBO_Gaps`; показать paired/unpaired counts.
- [ ] Создать/переиспользовать tag `ORAMBO_Diagnostics` и material `ORAMBO_Diagnostics_Red`; markers создавать только внутри отдельной group.
- [ ] Обе команды обернуть `Safety.with_operation`; повторный запуск заменяет только одноимённую группу.
- [ ] Запустить tests; commit `feat: add open-end and gap marker commands`.

### Task 4: Добавить две кнопки и hot-register

**Files:**
- Modify: `test/loader_test.rb`
- Modify: `src/orambo_face_tools/main.rb`
- Modify: `src/orambo_face_tools/toolbar.rb`
- Modify: `src/orambo_face_tools/updater.rb`
- Create: `src/orambo_face_tools/icons/open_ends_16.png`
- Create: `src/orambo_face_tools/icons/open_ends_24.png`
- Create: `src/orambo_face_tools/icons/highlight_gaps_16.png`
- Create: `src/orambo_face_tools/icons/highlight_gaps_24.png`
- Modify: `scripts/verify_rbz.ps1`

- [ ] Изменить loader test: toolbar и submenu содержат пять команд плюс Check for Updates; увидеть RED.
- [ ] Добавить diagnostics в список require до toolbar и в reload priority рядом с инструментами.
- [ ] Расширить `Toolbar::COMMANDS` двумя командами и выделить `build_command` для обычной и горячей регистрации.
- [ ] Реализовать `Diagnostics.register_hot_commands`: при наличии существующего `Toolbar.@toolbar` добавить только отсутствующие кнопки; повторный вызов ничего не дублирует.
- [ ] Сгенерировать четыре минималистичные PNG-иконки в существующей синей стилистике; добавить их в RBZ verification.
- [ ] Запустить loader/full tests и RBZ verification; commit `feat: add diagnostics toolbar commands`.

### Task 5: Показывать итог обновления в status bar

**Files:**
- Modify: `test/updater_test.rb`
- Modify: `src/orambo_face_tools/updater.rb`

- [ ] Написать RED-тест `status_message(message)` вызывает `Sketchup.status_text=` с префиксом ORAMBO Face Tools.
- [ ] Реализовать helper и вызывать его из `notify_result` и `update_error`.
- [ ] После `reload_installed_files` вызвать `Diagnostics.register_hot_commands`, если модуль доступен.
- [ ] Успех: `ORAMBO Face Tools: обновление <version> успешно`; restart/error получают отдельные короткие формулировки.
- [ ] Запустить updater/full tests; commit `feat: show update result in SketchUp status bar`.

### Task 6: Версия 0.1.2, сборка и публикация

**Files:**
- Modify: `src/orambo_face_tools.rb`
- Modify: `src/orambo_face_tools/main.rb`
- Modify: `test/core_test.rb`
- Modify: `test/loader_test.rb`
- Modify: `scripts/build_rbz.ps1`
- Modify: `scripts/verify_rbz.ps1`
- Modify: `scripts/verify_update_manifest.ps1`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `dist/update_manifest.json`
- Create: `dist/ORAMBO_Face_Tools_0.1.2.rbz`

- [ ] Сначала изменить version expectations на 0.1.2 и увидеть RED.
- [ ] Обновить runtime/package defaults и changelog; оставить `restart_required: false`.
- [ ] Запустить Ruby 2.7 full tests, syntax check, build RBZ, verify RBZ и manifest.
- [ ] Проверить содержимое RBZ: новый diagnostics.rb и 4 иконки, без dev-файлов.
- [ ] Commit `release: prepare ORAMBO Face Tools 0.1.2`.
- [ ] Push master, tag/push `v0.1.2`, дождаться зелёного release workflow.
- [ ] Проверить GitHub latest, два assets и SHA-256 всех manifest URLs.
- [ ] В SketchUp 0.1.1 нажать Check for Updates; убедиться, что строка состояния показывает успех, Curve реально становится edges, а две новые кнопки появляются без обязательной переустановки RBZ.
