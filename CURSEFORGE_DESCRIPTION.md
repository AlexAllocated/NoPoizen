# NoPoizen

NoPoizen is a focused quality-of-life addon for **Rogues** that helps you avoid fighting without proper poisons active.

On supported Retail clients, it watches your current poison state and warns when you are missing required poisons. Unreadable or restricted observations do not trigger missing-poison warnings.

## What It Does

- Monitors **lethal** and **non-lethal** poison categories.
- Shows a center-screen reminder widget when your poison setup is incomplete.
- Supports talent-based poison limits:
  - Default: up to `1 lethal + 1 non-lethal`, limited to learned poison categories
  - With `Dragon-Tempered Blades`: `2 lethal + 2 non-lethal`
- Uses a two-row display:
  - Row 1: Lethal Poisons
  - Row 2: Non-Lethal Poisons
- Removes already-applied poisons from each row.
- Hides an entire row once that category is fully satisfied.

## Indicator Position and Scale

Open Blizzard **Edit Mode** to see NoPoizen alongside your other HUD elements. Drag its preview or click it to open position and scale controls. `/np edit` also opens those controls directly.

- Drag the indicator to place it where you want.
- Scale the indicator up/down in real time.
- Use **Save** in the NoPoizen panel to keep changes, or Cancel/Revert/Reset as needed.
- NoPoizen changes are independent of Blizzard layout Save/Revert. Closing Edit Mode cancels any unsaved NoPoizen changes.
- Entering combat, loading a new area, or disabling the addon cancels unsaved edits.

## Options (Blizzard AddOns Panel)

Path: `Options -> AddOns -> NoPoizen`

Current options:

- Enable NoPoizen
- Show visual indicator when poisons are missing
- Play audio indicator when poisons are missing
- Audio indicator volume
- Play sound when poison requirements are satisfied
- Satisfied sound volume

Notes:

- The volume slider is disabled when audio is turned off.
- Default volume is `50%`.

## Audio Alert

- Plays the bundled NoPoizen missing-poison sound and a separate satisfied sound.
- Plays when you enter a missing-poison state.
- Each sound has its own 0–100% slider. Pre-attenuated sound files respect the game master volume without changing shared sound settings.
- Loading, unavailable observations, and enable transitions seed a quiet baseline.

## Slash Commands

- `/nopoizen options` or `/np options` - Open NoPoizen settings
- `/nopoizen edit` or `/np edit` - Move and scale the indicator
- `/nopoizen test` or `/np test` - Run isolated addon tests and open results in the shared debug console (chat fallback when unavailable)
- `/np debug` or `/np dump` - Open the shared console with category filters, fuzzy/quoted search, copying, and live log scrolling
- `/np dump CATEGORY` - Show one category; `/np dump clear` clears the session log and filters
- `/np diagnostics` - Copy client capabilities, poison state, bounded recent history, and safe weapon-coating observations
- `/np enable` or `/np disable` - Enable or disable reminders

## Scope and Philosophy

NoPoizen is intentionally small and specific.

- No profile system
- No cluttered configuration tree
- No extra modules unrelated to poison readiness

Everything is built around one goal: **keep your poisons correct with minimal friction**.

## Saved Settings

All settings are **per-character**, including:

- visual/audio toggles
- audio volume
- widget position
- widget scale

## Compatibility Notes

- Retail WoW: updated for the installed 12.1 client; live validation of this beta is pending.
- Forever beta: experimental loading and diagnostics only. Poison/coating identifiers are not yet verified, so poison warnings remain disabled there.
- Rogue-only behavior by design
- Indicator logic automatically reacts to spec/talent changes and aura updates

## Feedback

If you find a poison/talent edge case, report it with:

- your spec
- your selected poison talents
- which poisons were active
- expected vs actual indicator behavior

That makes fixes very fast and precise.
