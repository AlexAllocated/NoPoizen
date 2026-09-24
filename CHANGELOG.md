# NoPoizen changelog

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
