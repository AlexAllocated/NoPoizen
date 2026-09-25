# NoPoizen client compatibility

One source tree supports these current client families. Interface metadata permits loading; API capabilities still decide which adapter can run. PTR/beta builds in the same family use those adapters when their contracts match. This does not claim support for arbitrary historical/private-server clients.

| Client family | Source snapshot | Interface targets |
| --- | --- | --- |
| Retail | Installed 12.1.0.69933 UI export | 120100 (existing older Retail targets retained) |
| Forever | Installed 1.60.1.69977 UI export; 1.60.1.70009 spell data | 16001 |
| Era / Hardcore / Season of Discovery | [1.15.9.69722](https://github.com/Gethe/wow-ui-source/tree/33e177d9bf38d76d5c6c6e05d5da78db1899659a) | 11509 |
| Anniversary / Burning Crusade | [2.5.6.69795](https://github.com/Gethe/wow-ui-source/tree/1463c686270b6c64e2c5c228f447c4597c0f8ba6) | 20506 |
| Mists Classic | [5.5.4.69934](https://github.com/Gethe/wow-ui-source/tree/cde55d0033e89b246381385b2f063cd6c6047ef8) | 50504 |
| Titan Reforged (China) | [3.80.2.69874](https://github.com/Gethe/wow-ui-source/tree/84ef503f0d2617494db84cc9c7e7b530e976f6e7) | 38001, 38002 |

The Classic references are mirrored Blizzard UI/API source. Source inspection and offline fixtures establish expected contracts, not engine-level taint safety, rendering or gameplay validation. The user requested source-backed implementation without waiting to level a Forever rogue. Live poison application, expiry, charge exhaustion and audio checks remain pending; no live test result is inferred from these fixtures. No SavedVariables were changed externally.

## Monitoring behavior

- Retail retains learned lethal/nonlethal aura checks and Dragon-Tempered Blades requirements.
- Forever uses **all** accessible rows (including sparse or zero-based tables) from `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot)`, requiring one verified poison on each equipped melee weapon. It recognizes both poison training spells (`2842`, `1298494`), reads time in milliseconds, and checks charges only for poisons whose client data defines charges. Other coatings do not satisfy poison requirements. A valid poison can coexist with another coating.
- Era/Hardcore/SoD and TBC use per-weapon temporary enchants. The exact client catalog controls rank and charge handling. SoD-specific Sebacious, Numbing, Atrophic and Occult poisons are in the Era catalog only. TBC has its additional ranks and Anesthetic Poison, with no charge requirement.
- Titan uses its Wrath-derived weapon poison catalog, including ranks VIII/IX. Vendor poisons become usable at level 20; eligibility does not require the retired crafting skill. `ItemSparse` item `6947` explicitly requires level 20, rogue class mask 8, and no required skill.
- Mists uses its own lethal/nonlethal aura catalog, including Leeching and Paralytic Poison, without Retail's Dragon-Tempered Blades rules.

Empty hands, shields and holdables do not need poison. A missing item query, inaccessible enchant result or failed restriction check stays **unknown**, with no missing alert. Weapon reads pause during combat/restrictions; recovery establishes a quiet audio baseline. Enchant/equipment events refresh immediately, with a one-second poll covering expiry and charge changes. Disable removes polling; loading/logout prevent further observations.

HUD hand/category rows, settings, startup grace, transition audio, restriction policy and the private libchev debug console remain shared across clients. `/np edit` works independently of native Edit Mode; the native callback bridge is optional.

## Poison identity evidence

The generated `PoisonData.lua` comes from the actual client DB2 records, mirrored by Wago, rather than copying a Classic lookup into Forever:

- [Forever SpellItemEnchantment](https://wago.tools/db2/SpellItemEnchantment?build=1.60.1.70009), [SpellEffect](https://wago.tools/db2/SpellEffect?build=1.60.1.70009), [SpellName](https://wago.tools/db2/SpellName?build=1.60.1.70009).
- Matching tables for Era `1.15.9.69722`, TBC `2.5.6.69795`, and Titan `3.80.2.69874` are pinned in `scripts/poison-data-sources.json`, including SHA-256 digests and selected spell/enchant pairs.
- Forever's actual application records use effect **360** (for example spell `8679` -> enchant `323`); Era/TBC/Titan use effect **54**. Only explicitly named rogue poison families with matching enchant records enter the catalog. Generic poison, NPC toxin, rune engraving, sharpening stone, oil and shaman imbue records are excluded. This also prevents dormant SoD spell records in Forever's data from being mistaken for active Forever coatings.
- Enchantment `Charges` is positive for charged Forever/Era poisons, zero for Crippling and for TBC/Titan poisons. Presence, icon or enchant type alone never establishes poison identity.
- Forever `Spell`/`SpellEffect` records `2842` and `1298494` describe poison crafting and skill lines 40/2988. Mists `Spell`/`SpellEffect` records `2823`, `8679`, `3408`, `5761`, `108211`, `108215` explicitly describe lethal/nonlethal coatings implemented as player auras.

To reproduce the catalog, download `https://wago.tools/db2/<table>/csv?build=<build>` as `<build>-<table>.csv`, run `python3 scripts/build_poison_catalog.py /path/to/csv-cache`, then format `PoisonData.lua` with StyLua. Raw CSV files are research inputs, not runtime payloads. The generated Lua and provenance JSON are committed.

## Validation

Run `lua scripts/test.lua` and `lua scripts/test.lua . reverse`. Run `lua scripts/smoke.lua . <client>` for `retail`, `forever`, `era`, `tbc`, `mists`, `titan` under Lua 5.1 and 5.2. The smoke checks load the real TOC and exercise startup, warning/satisfied transitions, restriction recovery, polling, settings/editing, console isolation, loading, disable/re-enable and logout. Private in-game fixtures cover secrets, malformed results, wrong coatings, charge policy, hand swaps, rank catalogs and Mists talent differences.

Follow up with actual poison application on each relevant client when characters are available. In particular, confirm Forever exposes trained poison abilities through the spell-knowledge API and returns the documented weapon rows. Any unexpected runtime shape fails quietly and appears in `/np diagnostics`; it must not be treated as a successful live observation.
