# NoPoizen changelog

## 1.2.0 — 2026-09-24

Enable real Forever weapon-poison monitoring using verified client spell/enchant data. Add Era/Hardcore/SoD, TBC, Mists and Titan adapters, hand-aware warnings, charge/expiry polling, Classic load metadata and six-client offline coverage. Preserve Retail aura/talent behavior and shared diagnostics. Live validation remains pending.

Validation: 140 tests pass in both orders on Lua 5.1 and 5.2, with six client profiles, Lua parsing and exact private-library vendor checks. NoPoizen client smoke checks and package verification also pass. Live validation of the new adapters remains pending.

See [CLIENT_COMPATIBILITY.md](CLIENT_COMPATIBILITY.md) for source evidence, scope and validation limits.

## 1.1.1 — 2026-09-24

Keep overlapping debug consoles and their controls in one native stacking group through private libchev 1.1.3. Category menus stay with their owning console.

Validation: 123 tests pass in both orders under Lua 5.1/5.2, plus Retail/Forever smoke simulations, packaging and runtime-source checks. Live multi-window interaction remains a separate client check. Forever poison monitoring remains unsupported; diagnostics and tests are available.

## 1.1.0 — 2026-09-24

Use the same private libchev 1.1.2 debug console across all three addons, including category/search filters, copy controls, test results, diagnostic reports, timestamps when available, and a single final test summary. Fix stretched native frame artwork with explicit texture bounds.

Includes poison-state and lifecycle hardening, public Edit Mode integration, and corrected Forever test fixtures that no longer construct NaN with division by zero. NaN rejection remains covered offline. Run `/np test`, `/np debug`, or `/np diagnostics`.

Validation: 123 tests pass in both orders on Lua 5.1/5.2, plus offline NaN checks and Retail/Forever smoke simulations. The user confirmed the corrected shared frame appearance in-game. Forever poison monitoring remains unsupported; diagnostics and tests are available.

## 1.1.0-beta.3

- Update the private shared library to libchev 1.1.1 for native WoW-style console artwork on addon-owned frames and one test summary per run.

- Fix the Forever 1.60.1 test failure caused by constructing NaN through division by zero. In-game core and diagnostic fixtures now use supported infinity constants and invalid primitive values.
- Keep NaN rejection coverage in the offline harness for settings, saved anchors, numeric guards, diagnostic clocks, and weapon-slot enums. These extra checks are explicitly separate from the 123-test in-game count.
- Add an offline source regression that rejects literal zero-division fixtures in every TOC-loaded file. Test throwing clocks separately from clocks that successfully return a nonfinite value.

**Compatibility:** This fixes the reported test-fixture failure; fresh live client validation remains pending. Forever poison monitoring remains unsupported. This release is distributed on GitHub; no CurseForge/Wago upload is included.

**Install:** extract `NoPoizen-1.1.0-beta.3.zip` into `Interface/AddOns`, preserving the single `NoPoizen` folder. Reload and run `/np test`; expect 123 passed, 0 failed, and one summary in the shared console.

## 1.1.0-beta.2

- Adopt the shared libchev debug controller and console for test results, diagnostics, log filtering/search, copying, scrolling, and common debug commands.
- Fix `/np test` and `/nopoizen test` to open current results in that console, including addon/library versions, suite purpose, pass/fail totals, and permitted failure names/details. Reuse the console on subsequent runs and fall back to chat when UI is restricted, unavailable, or fails to open.
- Add `/np debug`, `/np dump CATEGORY`, and `/np dump clear`. Poison-specific diagnostics remain addon-owned and bounded to 32,768 characters; the session log retains at most 60 entries of 240 characters.
- Keep programmatic `RunTests(reverse)` headless with its existing return values. Regression tests use detached fixtures and never patch live Blizzard globals or addon state.
- Validate 123 isolated tests in both orders under Lua 5.1/5.2, plus Retail/Forever startup and actual slash-command UI simulations.

**Compatibility:** Live client validation remains pending. Forever poison monitoring remains unsupported; tests and diagnostics are available. This release is distributed on GitHub; no CurseForge/Wago upload is included.

**Install:** extract `NoPoizen-1.1.0-beta.2.zip` into `Interface/AddOns`, preserving the single `NoPoizen` folder. Reload and run `/np test`; expect a copyable report with 123 passed and 0 failed.

## 1.1.0-beta.1

- Update Retail interface support for 12.1 and harden poison detection around restricted or unavailable aura data.
- Respect learned poison categories and detect poisons retained across spec changes. Unknown observations do not issue missing-poison alerts.
- Fix startup audio baselines, stale loading/enable callbacks, warning cleanup, and invalid saved settings.
- Restore Blizzard Edit Mode discovery through public notifications, with NoPoizen-owned drag/scale and Save/Cancel controls. `/np edit` remains available. Use **Save in NoPoizen's panel**; closing Edit Mode cancels its unsaved changes.
- Replace temporary global sound-volume changes with independent 0–100% volume assets that respect Master volume.
- Add copyable, bounded diagnostics and privately embed validated libchev 1.0.0 for diagnostic/test helpers and callback fences.
- Add 113 isolated addon/library tests, Retail/Forever offline simulations, packaging checks, and Lua 5.1/5.2 CI.

**Compatibility:** Retail is the supported monitoring target. Forever beta loads for tests and diagnostics only; poison monitoring is explicitly unsupported until its coating identities and mechanics are verified. Offline tests do not establish live poison detection, sound, rendering, or engine-level taint safety. Those client checks remain pending.

**Install:** extract `NoPoizen-1.1.0-beta.1.zip` into the desired client's `Interface/AddOns` directory, preserving the single `NoPoizen` folder. No separate libchev installation is required. Reload and run `/np test` (113 passed expected); `/np diagnostics` produces a copyable report.
