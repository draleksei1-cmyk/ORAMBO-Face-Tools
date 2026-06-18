# ORAMBO Face Tools 0.1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, test, document, and package ORAMBO Face Tools 0.1.0 as a SketchUp 2021–2026 RBZ extension.

**Architecture:** A thin SketchUp loader and toolbar delegate to three focused command modules. Shared traversal, geometry algorithms, safety, progress, and reporting live in isolated modules; pure Ruby algorithms are tested outside SketchUp, while an in-SketchUp smoke script verifies API integration.

**Tech Stack:** Ruby 2.7-compatible syntax, SketchUp Ruby API, Minitest, PowerShell packaging, PNG toolbar assets.

---

## File map

- `src/orambo_face_tools.rb`: SketchUp extension registration.
- `src/orambo_face_tools/main.rb`: constants and dependency loading.
- `src/orambo_face_tools/toolbar.rb`: commands, menu, toolbar, icon fallback.
- `src/orambo_face_tools/utils.rb`: traversal, transforms, pure geometry helpers.
- `src/orambo_face_tools/safety.rb`: validation, confirmation, operation wrapper.
- `src/orambo_face_tools/progress.rb`: throttled status updates.
- `src/orambo_face_tools/report.rb`: counters, warnings, console/UI output.
- `src/orambo_face_tools/break_to_segments.rb`: destructive repair command.
- `src/orambo_face_tools/flatten_edges_to_z.rb`: world-Z flatten command.
- `src/orambo_face_tools/make_faces.rb`: gap closing and face creation command.
- `src/orambo_face_tools/icons/*.png`: six toolbar assets.
- `test/test_helper.rb`: Minitest bootstrap and SketchUp-independent stubs.
- `test/*_test.rb`: focused unit tests.
- `sketchup_test/manual_acceptance.rb`: in-SketchUp geometry scenarios.
- `scripts/build_rbz.ps1`: deterministic RBZ packaging.
- `README.md`: install, use, safety, and test instructions.

### Task 1: Test harness and shared constants

**Files:**
- Create: `test/test_helper.rb`
- Create: `test/main_test.rb`
- Create: `src/orambo_face_tools/main.rb`

- [ ] **Step 1: Write the failing loader test**

```ruby
require_relative 'test_helper'
require_relative '../src/orambo_face_tools/main'

class MainTest < Minitest::Test
  def test_public_identity
    assert_equal 'ORAMBO Face Tools', ORAMBO::FaceTools::EXTENSION_NAME
    assert_equal '0.1.0', ORAMBO::FaceTools::EXTENSION_VERSION
  end
end
```

- [ ] **Step 2: Run RED**

Run: `ruby -Itest test/main_test.rb`
Expected: failure because `main.rb` does not exist.

- [ ] **Step 3: Implement constants and SketchUp-aware dependency loading**

Define `ORAMBO::FaceTools`, version constants, processing limits, and load internal command files only after the namespace exists. Guard UI registration so unit tests can load pure modules without SketchUp.

- [ ] **Step 4: Run GREEN**

Run: `ruby -Itest test/main_test.rb`
Expected: 1 run, 2 assertions, 0 failures.

- [ ] **Step 5: Commit**

Run: `git add src test && git commit -m "feat: add extension core and test harness"`

### Task 2: Pure geometry utilities

**Files:**
- Create: `test/utils_test.rb`
- Create: `src/orambo_face_tools/utils.rb`

- [ ] **Step 1: Write failing tests**

Test these public functions with simple point doubles: `grid_key`, `canonical_edge_key`, `nearest_gap_pairs`, `z_spread_values`, and `mirrored_axes?`. Include reversed endpoints, negative cells, exclusive pairing, maximum distance, pair limit, empty Z values, and negative determinant.

- [ ] **Step 2: Run RED**

Run: `ruby -Itest test/utils_test.rb`
Expected: missing-method failures.

- [ ] **Step 3: Implement minimal pure algorithms**

Use quantized endpoint tuples for duplicate keys, a 3×3 neighboring-cell scan for gap candidates, deterministic distance ordering, min/max for Z spread, and scalar triple product for mirrored transforms. Add SketchUp-facing traversal helpers behind runtime constant checks.

- [ ] **Step 4: Run GREEN**

Run: `ruby -Itest test/utils_test.rb`
Expected: all utility tests pass.

- [ ] **Step 5: Commit**

Run: `git add src/orambo_face_tools/utils.rb test/utils_test.rb && git commit -m "feat: add geometry utilities"`

### Task 3: Reports, progress, and safety

**Files:**
- Create: `test/report_test.rb`
- Create: `test/safety_test.rb`
- Create: `src/orambo_face_tools/report.rb`
- Create: `src/orambo_face_tools/progress.rb`
- Create: `src/orambo_face_tools/safety.rb`

- [ ] **Step 1: Write failing report and operation tests**

Assert counter increments, warning truncation at 30 lines, Russian summary text, and `with_operation` committing on success or aborting and re-raising on failure using a recording model double.

- [ ] **Step 2: Run RED**

Run: `ruby -Itest test/report_test.rb test/safety_test.rb`
Expected: missing class/module failures.

- [ ] **Step 3: Implement the services**

`Report` stores named integer counters and warnings, prints full details, and formats a bounded dialog. `Safety.with_operation` owns the start/commit/abort lifecycle. `Progress` updates `Sketchup.status_text` only after a configurable item interval and always restores it.

- [ ] **Step 4: Run GREEN**

Run: `ruby -Itest test/report_test.rb test/safety_test.rb`
Expected: all service tests pass.

- [ ] **Step 5: Commit**

Run: `git add src/orambo_face_tools/{report,progress,safety}.rb test && git commit -m "feat: add safety and reporting services"`

### Task 4: Flatten Edges To Z

**Files:**
- Create: `test/flatten_edges_to_z_test.rb`
- Create: `src/orambo_face_tools/flatten_edges_to_z.rb`
- Modify: `src/orambo_face_tools/utils.rb`

- [ ] **Step 1: Write failing transformation tests**

Use point and affine-transform doubles to assert that local points are converted to world space, receive the target world Z, and return through the inverse transform. Test identity, translation, rotation, and mirrored transforms; assert that one shared vertex is moved once.

- [ ] **Step 2: Run RED**

Run: `ruby -Itest test/flatten_edges_to_z_test.rb`
Expected: missing flatten planner failures.

- [ ] **Step 3: Implement command**

Collect contexts recursively, unique only changed component instances, plan vertex moves by persistent identity, apply `entities.transform_by_vectors`, verify residual Z spread, find micro-edges, request deletion confirmation, retain selection, and report skipped locked/hidden geometry.

- [ ] **Step 4: Run GREEN and regression**

Run: `ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require_relative f }"`
Expected: all tests pass.

- [ ] **Step 5: Commit**

Run: `git add src test && git commit -m "feat: implement world-Z edge flattening"`

### Task 5: Make Faces

**Files:**
- Create: `test/make_faces_test.rb`
- Create: `src/orambo_face_tools/make_faces.rb`
- Modify: `src/orambo_face_tools/utils.rb`

- [ ] **Step 1: Write failing gap-planning tests**

Assert: a 0.5 mm gap closes at a 1 mm threshold; a 5 mm gap does not; each endpoint is used once; existing endpoint pairs are rejected; `MAX_GAP_CLOSERS` stops creation and reports remaining candidates; tag name is `ORAMBO_Gap_Closers`.

- [ ] **Step 2: Run RED**

Run: `ruby -Itest test/make_faces_test.rb`
Expected: missing planner/constant failures.

- [ ] **Step 3: Implement command**

Validate coplanarity per entities context, identify degree-one vertices, use spatial-grid gap pairing, add bounded closing edges on the named tag, snapshot face IDs, call `find_faces`, identify new faces, orient them toward camera or world +Z, retain selection, and include unclosed counts in the report.

- [ ] **Step 4: Run GREEN and regression**

Run: `ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require_relative f }"`
Expected: all tests pass.

- [ ] **Step 5: Commit**

Run: `git add src test && git commit -m "feat: implement bounded face creation"`

### Task 6: Break To Segments

**Files:**
- Create: `test/break_to_segments_test.rb`
- Create: `src/orambo_face_tools/break_to_segments.rb`

- [ ] **Step 1: Write failing repair-helper tests**

Assert canonical duplicate detection treats A–B and B–A equally, keeps one edge, skips hidden records unless enabled, respects explode pass limits, and preserves the ordered vertex chain returned for curve conversion.

- [ ] **Step 2: Run RED**

Run: `ruby -Itest test/break_to_segments_test.rb`
Expected: missing helper failures.

- [ ] **Step 3: Implement command**

Show destructive confirmation and options, group multiple selected objects, recursively make component instances unique before explode, stop at the configured pass limit, optionally call `explode_curve` on Curve/Arc edges without redrawing them, optionally erase duplicate edges, preserve hidden state when processing hidden geometry, retain the working group selection, and report every limit/skip.

- [ ] **Step 4: Run GREEN and regression**

Run: `ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require_relative f }"`
Expected: all tests pass.

- [ ] **Step 5: Commit**

Run: `git add src test && git commit -m "feat: implement destructive segment repair"`

### Task 7: Loader, menu, toolbar, and icons

**Files:**
- Create: `test/loader_test.rb`
- Create: `src/orambo_face_tools.rb`
- Create: `src/orambo_face_tools/toolbar.rb`
- Create: `src/orambo_face_tools/icons/break_segments_16.png`
- Create: `src/orambo_face_tools/icons/break_segments_24.png`
- Create: `src/orambo_face_tools/icons/flatten_edges_16.png`
- Create: `src/orambo_face_tools/icons/flatten_edges_24.png`
- Create: `src/orambo_face_tools/icons/make_faces_16.png`
- Create: `src/orambo_face_tools/icons/make_faces_24.png`

- [ ] **Step 1: Write failing registration tests**

Stub `SketchupExtension`, `Sketchup.register_extension`, `UI::Command`, `UI.menu`, and `UI::Toolbar`. Assert exact extension metadata, three menu items in order, three toolbar items in order, English command labels, and successful registration when icon files are absent.

- [ ] **Step 2: Run RED**

Run: `ruby -Itest test/loader_test.rb`
Expected: loader/toolbar missing failures.

- [ ] **Step 3: Implement registration and assets**

Register the extension from the root loader, guard toolbar creation with `file_loaded?`, attach icon paths only when present, set Russian tooltips/status text, and generate clean monochrome PNG assets with transparent backgrounds.

- [ ] **Step 4: Run GREEN and inspect icons**

Run: `ruby -Itest test/loader_test.rb`
Expected: all registration tests pass. Open the 24 px contact sheet and verify legibility.

- [ ] **Step 5: Commit**

Run: `git add src test && git commit -m "feat: add extension UI and icons"`

### Task 8: In-SketchUp acceptance suite and documentation

**Files:**
- Create: `sketchup_test/manual_acceptance.rb`
- Create: `README.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Define executable acceptance scenarios**

Create named Ruby methods that clear only their own test group, generate each geometry scenario from sections 19.1–19.3 of the source specification, select the relevant container, and print expected results. Do not auto-run destructive commands.

- [ ] **Step 2: Validate Ruby syntax**

Run Ruby syntax checks over every `.rb` file. Expected: `Syntax OK` for all files.

- [ ] **Step 3: Document installation and workflow**

Document RBZ installation, safe and repair workflows, option meanings, Undo behavior, hidden/locked policy, limits, Ruby Console diagnostics, manual acceptance commands, and known limitation that automated CI cannot host the SketchUp process.

- [ ] **Step 4: Run full unit suite**

Run: `ruby -Itest -e "Dir['test/*_test.rb'].sort.each { |f| require_relative f }"`
Expected: 0 failures and 0 errors.

- [ ] **Step 5: Commit**

Run: `git add README.md CHANGELOG.md sketchup_test && git commit -m "docs: add acceptance suite and user guide"`

### Task 9: RBZ build and final verification

**Files:**
- Create: `scripts/build_rbz.ps1`
- Create: `dist/ORAMBO_Face_Tools_0.1.0.rbz`

- [ ] **Step 1: Write a failing package-content test**

Add a PowerShell assertion that opens the ZIP-compatible RBZ and requires root entries `orambo_face_tools.rb` and `orambo_face_tools/`, all Ruby modules, and all six icons.

- [ ] **Step 2: Run RED**

Run: `powershell -ExecutionPolicy Bypass -File scripts/build_rbz.ps1 -VerifyOnly`
Expected: failure because the RBZ does not exist.

- [ ] **Step 3: Implement deterministic packaging**

Copy only runtime files to a temporary staging directory, create `dist/ORAMBO_Face_Tools_0.1.0.rbz` with `System.IO.Compression.ZipFile`, remove staging in `finally`, and invoke the package-content assertions after creation.

- [ ] **Step 4: Run complete verification**

Run unit tests, Ruby syntax checks, `git diff --check`, RBZ build, RBZ content verification, and inspect archive size/hash. If SketchUp automation is unavailable, install and run `manual_acceptance.rb` interactively in SketchUp 2026 and record that as the remaining user-visible check.

- [ ] **Step 5: Commit**

Run: `git add scripts dist && git commit -m "build: package ORAMBO Face Tools 0.1.0"`

## Completion checklist

- [ ] Every production behavior was introduced by a failing test.
- [ ] All unit tests pass with no warnings or errors.
- [ ] Every Ruby source reports `Syntax OK`.
- [ ] RBZ contains the exact loader/module/icon layout.
- [ ] Menu and toolbar registration are verified with API doubles.
- [ ] Manual SketchUp 2026 acceptance script is documented and runnable.
- [ ] README maps the safe and repair workflows from the source specification.
- [ ] `git diff --check` is clean and the working tree contains no accidental files.
