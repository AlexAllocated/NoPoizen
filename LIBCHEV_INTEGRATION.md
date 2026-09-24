# Shared library integration

NoPoizen privately embeds **libchev 1.0.0**, pinned to immutable commit [`09ac76eb6fe8e9589b809188652950c3cd9e444c`](https://github.com/AlexAllocated/libchev/commit/09ac76eb6fe8e9589b809188652950c3cd9e444c). The vendored files and SHA-256 manifest live in `Libs/libchev/`; the loader binds `namespace.LibChev`. There is no global library registry or compatibility alias.

## Scope

The extraction shares bounded structured diagnostic histories, a common diagnostic header and copy window, the test runner and its ten safe self-tests, and primitive generation/fence helpers. Poison interpretation, supported Edit Mode behavior, saved-variable policy, loading/combat/restriction decisions, and audio lifecycle stay owned by NoPoizen. Forever poison monitoring remains explicitly unsupported.

Review fixes:

- Keep the entire diagnostic report under a single 32,768-character bound, including capability lines and history; remove duplicate report headers.
- Read build/locale through addon-owned adapters so regression tests never read the live client's environment.
- Contain diagnostic clock failures without losing the original error message.
- Verify structured log sequence/category/time fields, bounded entries, and independent fixture histories.
- Preserve all three deferred-callback fences and addon-owned loading, enable, and logout guards.

## Validation

- **113/113 tests pass normally and in reverse under actual Lua 5.1.5 and 5.2.4.** This comprises 99 existing addon regressions, ten library self-tests, and four new diagnostic integration regressions.
- Retail and Forever offline startup/UI/lifecycle simulations pass under both interpreters. Each runs both test orders against an initialized addon and verifies its live timer/audio adapters, state identities, and structured log entries/sequence/drop counters remain unchanged.
- All 18 Lua files parse under both versions; all 16 TOC paths resolve in order and exclude offline scripts. Consumer formatting and diff whitespace checks pass.
- `vendor.py --check` verifies the manifest and embedded bytes. Each embedded payload also matches `git show 09ac76e:<file>` from the validated upstream commit. The migration verified the legacy manifest against Git before removing the old copy; embedded files were not edited.

Runtime files are `Libs/libchev/libchev.lua`, `ReportWindow.lua`, and `SelfTests.lua`, loaded before `Core.lua`. Update the dependency only through the upstream `scripts/vendor.py` against an explicitly reviewed immutable commit. The addon version remains the existing `1.0.8-beta.2`; no addon release tag is created.

## Live validation still required

Offline fixtures do not establish engine-level taint safety, client rendering, audio, or actual poison detection. In Retail, run `/np test` (expect 113 passed, 0 failed), copy `/np diagnostics`, verify loading/audio/restriction transitions, and check Blizzard Edit Mode drag/click/Save/Cancel and `/np edit`. Verify report copying/scrolling/closing around combat/restriction transitions. In Forever, confirm the unsupported-monitor message and safe diagnostic captures; poison mechanics still require the observations described in the audit.
