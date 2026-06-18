# ORAMBO Face Tools 0.1.1 Geometry Context Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Исправить общий контракт геометрических контекстов, чтобы Break To Segments по умолчанию разрывал кривые, Flatten действительно укладывал вершины на мировую Z, а Make Faces создавал грани без ошибок `intersect_with`.

**Architecture:** `Utils.collect_edge_contexts` остаётся единственной точкой обхода выбранной геометрии, но каждый контекст получает настоящий `Sketchup::Entities`. Make Faces отделяет необязательное пересечение от основного создания граней, чтобы сбой одного этапа не останавливал остальные контексты. Версия 0.1.1 выпускается существующим GitHub Release pipeline и применяется установленным updater через горячую перезагрузку.

**Tech Stack:** Ruby 2.7, SketchUp Ruby API, Minitest 5.13, PowerShell, GitHub Actions, GitHub Releases.

---

## Карта файлов

- `src/orambo_face_tools/utils.rb` — правильное преобразование родителя ребра в `Sketchup::Entities` и общий контракт контекста.
- `src/orambo_face_tools/break_to_segments.rb` — включённое по умолчанию преобразование кривых.
- `src/orambo_face_tools/flatten_edges_to_z.rb` — использование исправленного контекста и диагностическая проверка коллекции Entities.
- `src/orambo_face_tools/make_faces.rb` — безопасная последовательность intersect → gaps → find_faces.
- `test/utils_test.rb` — регрессия Model/ComponentDefinition вместо Entities.
- `test/break_to_segments_test.rb` — регрессия значения переключателя кривых.
- `test/flatten_edges_to_z_test.rb` — проверка пакетного перемещения вершин через Entities.
- `test/make_faces_test.rb` — проверка необязательного intersect и продолжения find_faces.
- `test/loader_test.rb` — метаданные версии 0.1.1.
- `src/orambo_face_tools.rb`, `src/orambo_face_tools/main.rb` — версия расширения.
- `scripts/build_rbz.ps1`, `scripts/verify_rbz.ps1`, `scripts/verify_update_manifest.ps1` — значения версии по умолчанию для локальной сборки.
- `CHANGELOG.md`, `README.md` — пользовательское описание исправлений и обновления.
- `dist/ORAMBO_Face_Tools_0.1.1.rbz`, `dist/update_manifest.json` — проверенные артефакты релиза.

### Task 1: Исправить общий контракт `Sketchup::Entities`

**Files:**
- Modify: `test/utils_test.rb`
- Modify: `src/orambo_face_tools/utils.rb:76-111`

- [ ] **Step 1: Написать падающие тесты преобразования родителя в Entities**

Добавить в `test/utils_test.rb`:

```ruby
  def test_entities_for_parent_uses_active_entities_for_model
    active_entities = Object.new
    model = Struct.new(:active_entities).new(active_entities)

    assert_same active_entities, U.entities_for_parent(model, model)
  end

  def test_entities_for_parent_uses_definition_entities
    entities = Object.new
    definition = Struct.new(:entities).new(entities)
    model = Struct.new(:active_entities).new(Object.new)

    assert_same entities, U.entities_for_parent(definition, model)
  end

  def test_entities_for_parent_rejects_unknown_parent
    model = Struct.new(:active_entities).new(Object.new)

    assert_raises(ArgumentError) { U.entities_for_parent(Object.new, model) }
  end
```

- [ ] **Step 2: Запустить RED для Utils**

Run:

```powershell
ruby -Itest test/utils_test.rb
```

Expected: 3 errors with `undefined method 'entities_for_parent'`.

- [ ] **Step 3: Реализовать минимальный преобразователь родителя**

Добавить в `Utils` перед `collect_edge_contexts`:

```ruby
      def entities_for_parent(parent, model)
        return model.active_entities if parent.equal?(model)
        return parent.entities if parent.respond_to?(:entities)

        raise ArgumentError, "Не удалось определить Sketchup::Entities для #{parent.class}."
      end
```

В ветке обработки `Sketchup::Edge` заменить вычисление ключа и запись контекста:

```ruby
              entities = entities_for_parent(entity.parent, model)
              key = entities.object_id
              record = (contexts[key] ||= {
                entities: entities,
                edges: [],
                transform: transform,
                container: container
              })
              record[:edges] << entity
```

- [ ] **Step 4: Запустить GREEN для Utils и полную матрицу**

Run:

```powershell
ruby -Itest test/utils_test.rb
ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require File.expand_path(f) }"
```

Expected: все тесты проходят, 0 failures, 0 errors.

- [ ] **Step 5: Зафиксировать общий контракт**

```powershell
git add src/orambo_face_tools/utils.rb test/utils_test.rb
git commit -m "fix: pass SketchUp entities to geometry tools"
```

### Task 2: Включить преобразование кривых по умолчанию

**Files:**
- Modify: `test/break_to_segments_test.rb`
- Modify: `src/orambo_face_tools/break_to_segments.rb:7-36`

- [ ] **Step 1: Написать падающий тест значения по умолчанию**

Добавить в `test/break_to_segments_test.rb`:

```ruby
  def test_curve_conversion_is_enabled_by_default
    assert_equal true, B::DEFAULT_CONVERT_CURVES
  end
```

- [ ] **Step 2: Запустить RED**

Run:

```powershell
ruby -Itest test/break_to_segments_test.rb
```

Expected: error `uninitialized constant ... DEFAULT_CONVERT_CURVES`.

- [ ] **Step 3: Добавить именованную настройку и подключить её к диалогу**

В начале `BreakToSegments` добавить:

```ruby
      DEFAULT_CONVERT_CURVES = true
```

Заменить четвёртое значение массива `defaults` с `false` на константу:

```ruby
        defaults = [true, true, true, DEFAULT_CONVERT_CURVES, false,
                    ORAMBO::FaceTools::DUPLICATE_EDGE_TOLERANCE_MM.mm, false]
```

Не менять существующий код `convert_curves`: он уже сохраняет сегменты, слой, материал, hidden/soft/smooth и выполняется только при включённом переключателе.

- [ ] **Step 4: Запустить GREEN**

Run:

```powershell
ruby -Itest test/break_to_segments_test.rb
ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require File.expand_path(f) }"
```

Expected: все тесты проходят.

- [ ] **Step 5: Зафиксировать изменение поведения**

```powershell
git add src/orambo_face_tools/break_to_segments.rb test/break_to_segments_test.rb
git commit -m "fix: convert curves by default in break tool"
```

### Task 3: Закрепить пакетное перемещение Flatten тестом

**Files:**
- Modify: `test/flatten_edges_to_z_test.rb`
- Modify: `src/orambo_face_tools/flatten_edges_to_z.rb:99-124`

- [ ] **Step 1: Написать падающий тест отдельного контракта перемещения**

Добавить в `test/flatten_edges_to_z_test.rb`:

```ruby
  def test_move_vertices_uses_entities_transform_by_vectors
    entities = Class.new do
      attr_reader :vertices, :vectors

      def transform_by_vectors(vertices, vectors)
        @vertices = vertices
        @vectors = vectors
      end
    end.new
    vertices = [Object.new, Object.new]
    vectors = [Object.new, Object.new]

    F.move_vertices(entities, vertices, vectors)

    assert_same vertices, entities.vertices
    assert_same vectors, entities.vectors
  end

  def test_move_vertices_rejects_non_entities_context
    error = assert_raises(ArgumentError) do
      F.move_vertices(Object.new, [Object.new], [Object.new])
    end

    assert_match(/Sketchup::Entities/, error.message)
  end
```

- [ ] **Step 2: Запустить RED**

Run:

```powershell
ruby -Itest test/flatten_edges_to_z_test.rb
```

Expected: errors for missing `move_vertices`.

- [ ] **Step 3: Выделить и использовать проверяемую операцию перемещения**

Добавить перед `flatten_context`:

```ruby
      def move_vertices(entities, vertices, vectors)
        unless entities.respond_to?(:transform_by_vectors)
          raise ArgumentError, 'Контекст Flatten не содержит Sketchup::Entities.'
        end
        unless vertices.length == vectors.length
          raise ArgumentError, 'Количество вершин и векторов перемещения не совпадает.'
        end

        entities.transform_by_vectors(vertices, vectors) unless vertices.empty?
      end
```

В конце `flatten_context` заменить существующую проверку и прямой вызов:

```ruby
        move_vertices(context[:entities], movable, vectors)
        report.increment(:vertices_moved, movable.length)
```

- [ ] **Step 4: Запустить GREEN и регрессию вычислений Z**

Run:

```powershell
ruby -Itest test/flatten_edges_to_z_test.rb
ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require File.expand_path(f) }"
```

Expected: все тесты проходят; существующие тесты target Z и округления остаются зелёными.

- [ ] **Step 5: Зафиксировать контракт Flatten**

```powershell
git add src/orambo_face_tools/flatten_edges_to_z.rb test/flatten_edges_to_z_test.rb
git commit -m "fix: move flattened vertices through entities"
```

### Task 4: Сделать Make Faces устойчивым к необязательному intersect

**Files:**
- Modify: `test/make_faces_test.rb`
- Modify: `src/orambo_face_tools/make_faces.rb:99-166`

- [ ] **Step 1: Написать падающие тесты пересечения**

Добавить в `test/make_faces_test.rb`:

```ruby
  class RecordingEntities
    attr_reader :intersect_calls

    def initialize(edges, fail_intersect: false)
      @edges = edges
      @fail_intersect = fail_intersect
      @intersect_calls = 0
    end

    def intersect_with(*_arguments)
      @intersect_calls += 1
      raise 'DWG intersection failed' if @fail_intersect
    end

    def grep(type)
      type == Sketchup::Edge ? @edges : []
    end
  end

  class RecordingReport
    attr_reader :warnings

    def initialize
      @warnings = []
    end

    def warn(message)
      @warnings << message
    end
  end

  def test_intersect_edges_uses_entities_and_refreshes_edges
    edge_class = Struct.new(:valid?)
    edges = [edge_class.new(true), edge_class.new(true)]
    entities = RecordingEntities.new(edges)
    report = RecordingReport.new

    result = M.intersect_edges(entities, edges, report)

    assert_equal 1, entities.intersect_calls
    assert_equal edges, result
    assert_empty report.warnings
  end

  def test_intersect_failure_becomes_warning_and_returns_current_edges
    edges = [Struct.new(:valid?).new(true)]
    entities = RecordingEntities.new(edges, fail_intersect: true)
    report = RecordingReport.new

    result = M.intersect_edges(entities, edges, report)

    assert_equal edges, result
    assert_match(/Пересечения пропущены/, report.warnings.first)
  end
```

Если тест запускается отдельно и `Sketchup::Edge` ещё не определён, добавить в начало тестового файла минимальный stub:

```ruby
module Sketchup
  class Edge; end unless const_defined?(:Edge)
end
```

- [ ] **Step 2: Запустить RED**

Run:

```powershell
ruby -Itest test/make_faces_test.rb
```

Expected: errors for missing `intersect_edges`.

- [ ] **Step 3: Реализовать безопасный этап intersect**

Добавить перед `process_context`:

```ruby
      def intersect_edges(entities, edges, report)
        identity = Geom::Transformation.new
        entities.intersect_with(false, identity, entities, identity, false, edges)
        entities.grep(Sketchup::Edge).select(&:valid?)
      rescue StandardError => error
        report.warn("Пересечения пропущены: #{error.message}")
        entities.grep(Sketchup::Edge).select(&:valid?)
      end
```

Для независимости unit-теста от SketchUp geometry изменить сигнатуру так, чтобы identity можно было передать только в тесте:

```ruby
      def intersect_edges(entities, edges, report, identity = nil)
        identity ||= Geom::Transformation.new
```

И в тестах вызывать `M.intersect_edges(entities, edges, report, Object.new)`.

- [ ] **Step 4: Перестроить `process_context` в утверждённом порядке**

В начале метода получить текущие рёбра и выполнить intersect до расчёта открытых вершин:

```ruby
        entities = context[:entities]
        edges = entities.grep(Sketchup::Edge).select(&:valid?)
        edges = intersect_edges(entities, edges, report) if intersect && edges.length > 1
```

После добавления `closing_edges` снова обновить список:

```ruby
        edges = entities.grep(Sketchup::Edge).select(&:valid?)
```

Удалить старый незащищённый блок `if intersect && edges.any?`. Для `faces_before`, `new_faces` и ориентации использовать локальную переменную `entities`, а `find_faces` вызывать по `(edges + closing_edges).uniq`.

- [ ] **Step 5: Запустить GREEN и всю матрицу**

Run:

```powershell
ruby -Itest test/make_faces_test.rb
ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require File.expand_path(f) }"
```

Expected: все тесты проходят; ошибка intersect фиксируется как предупреждение и не становится критической.

- [ ] **Step 6: Зафиксировать Make Faces**

```powershell
git add src/orambo_face_tools/make_faces.rb test/make_faces_test.rb
git commit -m "fix: continue face creation when intersect fails"
```

### Task 5: Поднять версию и подготовить локальный релиз 0.1.1

**Files:**
- Modify: `test/loader_test.rb`
- Modify: `src/orambo_face_tools.rb`
- Modify: `src/orambo_face_tools/main.rb`
- Modify: `scripts/build_rbz.ps1`
- Modify: `scripts/verify_rbz.ps1`
- Modify: `scripts/verify_update_manifest.ps1`
- Modify: `CHANGELOG.md`
- Modify: `README.md`

- [ ] **Step 1: Сначала изменить ожидаемую версию в тесте**

В `test/loader_test.rb` заменить:

```ruby
    assert_equal '0.1.1', extension.version
```

- [ ] **Step 2: Запустить RED метаданных**

Run:

```powershell
ruby -Itest test/loader_test.rb
```

Expected: FAIL, expected `0.1.1`, actual `0.1.0`.

- [ ] **Step 3: Изменить версию runtime и packaging**

Заменить `0.1.0` на `0.1.1` только в значениях версии по умолчанию:

```ruby
EXTENSION_VERSION = '0.1.1' unless const_defined?(:EXTENSION_VERSION)
```

Сделать это в `src/orambo_face_tools.rb` и `src/orambo_face_tools/main.rb`. В трёх PowerShell-скриптах заменить значения параметров по умолчанию на `0.1.1` и имя RBZ по умолчанию на `ORAMBO_Face_Tools_0.1.1.rbz`.

- [ ] **Step 4: Описать пользовательские исправления**

Добавить в начало `CHANGELOG.md`:

```markdown
## 0.1.1 — 2026-06-19

- Исправлена передача геометрии верхнего уровня и внутри групп в Flatten и Make Faces.
- Исправлена критическая ошибка `intersect_with` в Make Faces.
- Flatten снова перемещает вершины на выбранную мировую Z.
- Преобразование кривых и дуг в отрезки включено по умолчанию в Break To Segments.
```

В README уточнить, что переключатель кривых можно отключить, но по умолчанию он включён.

- [ ] **Step 5: Запустить GREEN, синтаксис и сборку**

Run:

```powershell
ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require File.expand_path(f) }"
Get-ChildItem -Path src,test -Recurse -Filter *.rb | ForEach-Object {
  ruby -c $_.FullName
  if ($LASTEXITCODE -ne 0) { throw "Syntax failed: $($_.FullName)" }
}
./scripts/build_rbz.ps1 -Version 0.1.1
./scripts/generate_update_manifest.ps1 -Version 0.1.1 -Tag v0.1.1
./scripts/verify_rbz.ps1 -Path dist/ORAMBO_Face_Tools_0.1.1.rbz
./scripts/verify_update_manifest.ps1 -Version 0.1.1 -Tag v0.1.1
```

Expected: 0 failures/errors, все Ruby-файлы `Syntax OK`, RBZ содержит 17 runtime-файлов, manifest подтверждает 17 файлов и version 0.1.1.

- [ ] **Step 6: Зафиксировать версию и документацию**

```powershell
git add src/orambo_face_tools.rb src/orambo_face_tools/main.rb test/loader_test.rb scripts/build_rbz.ps1 scripts/verify_rbz.ps1 scripts/verify_update_manifest.ps1 CHANGELOG.md README.md
git add -f dist/ORAMBO_Face_Tools_0.1.1.rbz dist/update_manifest.json
git commit -m "release: prepare ORAMBO Face Tools 0.1.1"
```

### Task 6: Ручная приёмка на DWG-фрагменте пользователя

**Files:**
- Verify: `sketchup_test/manual_acceptance.rb`
- Verify: `dist/ORAMBO_Face_Tools_0.1.1.rbz`

- [ ] **Step 1: Установить локальный RBZ в SketchUp**

Через `Window → Extension Manager → Install Extension` выбрать `dist/ORAMBO_Face_Tools_0.1.1.rbz`. Для проверки именно горячего обновления сначала можно оставить установленную 0.1.0 и выполнить Task 7.

- [ ] **Step 2: Проверить Break To Segments**

На копии проблемного DWG-фрагмента выделить геометрию, запустить первый инструмент и оставить включённым «Кривые и дуги перевести в отдельные отрезки». Выбрать бывший сегмент кривой.

Expected: Entity Info показывает обычное ребро, а не объект «Кривая»; при отключённом переключателе кривая сохраняется.

- [ ] **Step 3: Проверить Flatten**

На исходной копии выбрать весь фрагмент, запустить Flatten с мировой Z = 0 и включённым глубоким обходом.

Expected: нет критической ошибки `transform_by_vectors`; вид сбоку показывает все обработанные рёбра на одной высоте; отчёт показывает перемещённые вершины и остаточный разброс в пределах допуска.

- [ ] **Step 4: Проверить Make Faces**

После Flatten запустить Make Faces сначала без разбиения пересечений, затем на отдельной копии с включённым разбиением.

Expected: замкнутые участки получают грани; нет критической ошибки `intersect_with`; сбой отдельного пересечения, если он возникнет, отображается только как предупреждение, а обработка остальных контуров продолжается.

- [ ] **Step 5: При несовпадении результата сохранить диагностику**

Сохранить точный текст итогового отчёта, скриншот вида сверху и сбоку и копию минимального проблемного `.skp`. Не добавлять новые исправления без отдельного RED-теста, воспроизводящего найденный случай.

### Task 7: Опубликовать и проверить автообновление 0.1.1

**Files:**
- Publish: Git tag `v0.1.1`
- Publish: GitHub Release assets

- [ ] **Step 1: Проверить чистоту и соответствие ветки**

Run:

```powershell
git status --short
git log --oneline -6
git diff v0.1.0..HEAD --check
```

Expected: рабочее дерево чистое, diff не содержит whitespace errors, исправления и release commit присутствуют после v0.1.0.

- [ ] **Step 2: Отправить master и тег**

```powershell
git push origin master
git tag -a v0.1.1 -m "ORAMBO Face Tools 0.1.1"
git push origin v0.1.1
```

- [ ] **Step 3: Дождаться зелёного GitHub Actions**

```powershell
$run = gh run list --workflow release.yml --limit 1 --json databaseId,status,conclusion | ConvertFrom-Json
gh run watch $run[0].databaseId --exit-status
```

Expected: unit tests, Ruby syntax, build artifacts и Publish GitHub Release завершаются успешно.

- [ ] **Step 4: Проверить опубликованные assets**

```powershell
gh release view v0.1.1 --json url,tagName,isDraft,isPrerelease,assets
$verify = Join-Path $env:TEMP 'orambo-0.1.1-release'
New-Item -ItemType Directory -Force -Path $verify | Out-Null
gh release download v0.1.1 --pattern '*.rbz' --pattern 'update_manifest.json' --dir $verify --clobber
./scripts/verify_rbz.ps1 -Path (Join-Path $verify 'ORAMBO_Face_Tools_0.1.1.rbz')
```

Expected: стабильный release `v0.1.1`, два assets, RBZ проходит проверку.

- [ ] **Step 5: Проверить удалённые SHA-256 манифеста**

Прочитать скачанный `update_manifest.json` через `ConvertFrom-Json`, скачать каждый `entry.url` во временный файл и сравнить `Get-FileHash -Algorithm SHA256` с `entry.sha256`.

Expected: version `0.1.1`, 17 файлов, все URL указывают на tag `v0.1.1`, все SHA-256 совпадают.

- [ ] **Step 6: Проверить пользовательский путь автообновления**

В SketchUp с установленной 0.1.0 открыть `Extensions → ORAMBO Face Tools → Check for Updates`, нажать «Обновить», затем повторить три пользовательских сценария без переустановки RBZ.

Expected: появляется плашка 0.1.1, обновление применяется без переустановки и перезапуска, исправленные команды работают в текущем сеансе SketchUp.
