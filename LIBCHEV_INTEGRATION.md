# Shared library integration

NoPoizen privately embeds **libchev 1.1.0**, pinned to immutable commit [`1f2cd0eaabb692fd0befd51dbdadeb7e07beb3c6`](https://github.com/AlexAllocated/libchev/commit/1f2cd0eaabb692fd0befd51dbdadeb7e07beb3c6). The vendored bytes and SHA-256 manifest live in `Libs/libchev/`; the loader binds `namespace.LibChev`. There is no global library registry or compatibility alias.

## Shared behavior and addon policy

The library owns the debug controller and full console: bounded logs, category filters, fuzzy/quoted search, batching, scrolling/tail behavior, copying, test presentation, diagnostic history export, and common debug command dispatch. `/np test` opens current results in the same console as `/np debug` and `/np diagnostics`. Restricted, missing, or throwing UI falls back to chat. NoPoizen no longer maintains separate generic test-report or diagnostic-window mechanics.

The consumer adapter supplies a private dynamic history store, version/environment, ordered test cases, poison-specific diagnostic fields, chat/reload callbacks, and frame ownership/restriction policy. NoPoizen permits sanitized failure details and retains its existing log limits of 60 entries, 240 characters each. Diagnostic export is bounded to 32,768 characters by the library and retains newest history when a domain report is oversized.

`RunTests(reverse)` remains headless, returns exactly success/passed/failed, and uses a transient controller so it does not create persistent controller, history, or UI state. Every addon regression uses detached fixtures; UI stand-ins remain in the offline smoke harness. Poison interpretation, native Edit Mode behavior, saved-variable policy, loading/combat/restriction decisions, and audio lifecycle remain NoPoizen-owned. Forever poison monitoring remains unsupported.

## Validation

- **123/123 tests pass normally and in reverse under actual Lua 5.1.5 and 5.2.4**, including 13 library self-tests and seven shared debug integration regressions added to the prior addon suite.
- Retail and Forever offline startup/UI/lifecycle simulations pass under both interpreters. Actual slash dispatch and console buttons exercise current results, reuse after diagnostics, shared controls, category/search behavior, visible ALL preservation, failure details, and restricted chat fallback.
- Headless runs create no frames and preserve live history identity/content/sequence/drop counters, UI text, saved database/state identities, timers, and audio calls. Presented runs intentionally replace TEST history in the private console.
- All 20 Lua files parse under both interpreters; all 18 TOC paths resolve in order and exclude offline scripts. Consumer formatting and diff whitespace checks pass.
- Upstream `vendor.py --check` and packaging validate the immutable manifest and compare all six payloads to the upstream commit. The installable ZIP includes 63 runtime/package files; three packaging regressions check reproducibility, missing sounds, and tampered library rejection.

Runtime library load order is `libchev.lua`, `Debug.lua`, `DebugWindow.lua`, `ReportWindow.lua`, and `SelfTests.lua`, before consumer code. Update only with the upstream vendor script and a reviewed immutable revision; never edit embedded files. CI uses the same revision for independent source verification. Prepared addon version: `1.1.0-beta.2`; publication waits for the coordinated release gate.

## Live validation still required

Offline fixtures do not establish engine-level taint safety, client rendering, audio, or actual poison detection. In Retail, run `/np test` (123 passed, 0 failed expected), inspect/copy the shared console, use category/search/clear and diagnostics, and check restriction transitions. Verify native Edit Mode drag/click/Save/Cancel, `/np edit`, loading, and audio behavior. In Forever, confirm the unsupported-monitor message and diagnostic capture; poison mechanics still require the observations described in the audit.
