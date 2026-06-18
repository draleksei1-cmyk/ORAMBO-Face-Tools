# GitHub Auto Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add secure GitHub Release discovery, transactional file updates, native SketchUp notifications, hot-reload, automated releases, and publish v0.1.0.

**Architecture:** Pure updater logic handles versions, manifest validation, hashing, staging, installation, rollback, and reload order. A thin SketchUp adapter owns asynchronous HTTP requests, preferences, notifications, and menu integration. GitHub Actions generates the same manifest format exercised by unit tests and publishes RBZ assets from version tags.

**Tech Stack:** Ruby 2.7, SketchUp Ruby API (`Sketchup::Http::Request`, `UI::Notification`), Minitest, PowerShell, GitHub Actions, GitHub Releases.

---

### Task 1: Version and manifest validation

**Files:**
- Create: `test/updater_test.rb`
- Create: `src/orambo_face_tools/updater.rb`

- [ ] **Step 1: Write failing tests**

```ruby
assert ORAMBO::FaceTools::Updater.newer_version?('0.1.10', '0.1.9')
refute ORAMBO::FaceTools::Updater.newer_version?('0.1.0', '0.1.0')
assert_equal 'https://example/update_manifest.json', ORAMBO::FaceTools::Updater.manifest_url(release_json)
assert_raises(ArgumentError) { ORAMBO::FaceTools::Updater.validate_path('../evil.rb') }
assert_equal 'orambo_face_tools/updater.rb', ORAMBO::FaceTools::Updater.validate_path('orambo_face_tools/updater.rb')
```

- [ ] **Step 2: Run RED**

Run the Ruby 2.7 Minitest suite. Expected: missing `updater.rb` or missing methods.

- [ ] **Step 3: Implement pure parsing**

Implement numeric SemVer comparison, JSON parsing, stable-release filtering, manifest asset selection, schema validation, HTTPS-only URLs, exact 64-character SHA-256 validation, and the path allowlist (`orambo_face_tools.rb` or `orambo_face_tools/`).

- [ ] **Step 4: Run GREEN**

Run the full suite. Expected: all existing and updater tests pass.

### Task 2: Transactional installer and hot reload

**Files:**
- Modify: `test/updater_test.rb`
- Modify: `src/orambo_face_tools/updater.rb`

- [ ] **Step 1: Write failing filesystem tests**

Use temporary directories to assert that valid staged files replace installed files, invalid hashes replace nothing, a forced second-file failure restores the first file, and reload order ends with `updater.rb` while excluding root loader, `main.rb`, and `toolbar.rb`.

- [ ] **Step 2: Run RED**

Expected: missing staging/install/reload planner methods.

- [ ] **Step 3: Implement transaction**

Implement `verify_file`, `install_staged_files`, backup copies, rollback in reverse order, cleanup in `ensure`, and `reloadable_paths`. All destinations must be derived from validated relative paths beneath the extension root.

- [ ] **Step 4: Run GREEN**

Run updater tests and the full regression suite.

### Task 3: SketchUp networking and notification adapter

**Files:**
- Modify: `src/orambo_face_tools/updater.rb`
- Modify: `src/orambo_face_tools/main.rb`
- Modify: `src/orambo_face_tools/toolbar.rb`
- Modify: `test/loader_test.rb`

- [ ] **Step 1: Write failing registration tests**

Extend API doubles and assert a fourth menu-only command named `Check for Updates`, no fourth toolbar button, one delayed automatic check, and safe behavior when `UI::Notification` is unavailable.

- [ ] **Step 2: Run RED**

Expected: three menu items instead of four and missing updater scheduling.

- [ ] **Step 3: Implement SketchUp adapter**

Add asynchronous GitHub API and asset requests with timeout/User-Agent, quiet automatic checks, verbose manual checks, `UI::Notification` accept/dismiss callbacks, runtime version preferences, sequential file downloads to staging, install invocation, hot reload, and restart-required notification.

- [ ] **Step 4: Run GREEN**

Run the full suite and Ruby syntax checks.

### Task 4: Release manifest generator and workflow

**Files:**
- Create: `scripts/generate_update_manifest.ps1`
- Create: `scripts/verify_update_manifest.ps1`
- Create: `.github/workflows/release.yml`
- Modify: `scripts/build_rbz.ps1`

- [ ] **Step 1: Write a failing manifest verification**

Run `verify_update_manifest.ps1` before generation. Expected: failure because `dist/update_manifest.json` does not exist.

- [ ] **Step 2: Implement deterministic manifest generation**

Generate one entry for every runtime file under `src`, use raw GitHub URLs pinned to the supplied tag, calculate uppercase-insensitive SHA-256 values, sort entries by path, and write UTF-8 without BOM.

- [ ] **Step 3: Implement GitHub Actions release**

On `v*` tags, checkout, set up Ruby 2.7, run tests and syntax checks, build RBZ, generate and verify manifest, then publish `ORAMBO_Face_Tools_<version>.rbz` and `update_manifest.json` with `contents: write`.

- [ ] **Step 4: Verify locally**

Generate for `v0.1.0`, verify every path/hash/URL, and inspect YAML for unresolved placeholders.

### Task 5: Documentation, RBZ, and SketchUp smoke scenario

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `sketchup_test/smoke.rb`
- Modify: `scripts/verify_rbz.ps1`

- [ ] **Step 1: Document updates**

Explain automatic/manual checks, hot-reload boundaries, release process, rollback, network failures, repository URL, and the fact that v0.1.0 is the first updater-capable release.

- [ ] **Step 2: Extend package verification**

Require `orambo_face_tools/updater.rb` inside RBZ and reject workflow/development files.

- [ ] **Step 3: Build and verify**

Run all unit tests, syntax checks, placeholder scan, manifest generation/verification, RBZ build/verification, and `git diff --check`. Record the RBZ SHA-256.

- [ ] **Step 4: Commit implementation**

Commit updater, workflow, tests, documentation, manifest, and final RBZ on `codex/orambo-face-tools-0.1.0`.

### Task 6: Publish GitHub repository and v0.1.0

**External state:**
- Create public repository: `draleksei1-cmyk/ORAMBO-Face-Tools`
- Push branch and default branch
- Create release tag: `v0.1.0`
- Publish release assets

- [ ] **Step 1: Create repository**

Use authenticated GitHub tooling to create the public repository with description `SketchUp tools for preparing imported DWG geometry and creating faces.` and no generated README, license, or gitignore.

- [ ] **Step 2: Push reviewed history**

Merge the feature branch locally into `master`, add the new `origin`, push `master`, and verify repository visibility and default branch.

- [ ] **Step 3: Trigger and verify release**

Create and push annotated tag `v0.1.0`, watch the release workflow, inspect failed logs if needed, and verify the published release includes both RBZ and `update_manifest.json`.

- [ ] **Step 4: Verify public update metadata**

Fetch the public latest-release API and manifest asset, confirm version `0.1.0`, confirm all hashes, and ensure an installed 0.1.0 runtime does not offer itself as an update.

## Completion checklist

- [ ] Updater failures never prevent plugin startup.
- [ ] Downloaded paths cannot escape the ORAMBO extension directory.
- [ ] No installed file changes before every payload hash passes.
- [ ] Replacement failure restores the complete previous version.
- [ ] Normal updates reload command modules without restarting SketchUp.
- [ ] Loader/UI changes can require restart through manifest metadata.
- [ ] Automatic and manual update checks behave differently as designed.
- [ ] GitHub repository and v0.1.0 Release are public.
- [ ] Final RBZ contains updater and matches the release asset hash.
