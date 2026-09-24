# NoPoizen development

- Keep runtime and UI state on addon-owned objects. Never attach state to Blizzard frames, C_* tables, mixins, shared pools, or secure delegates.
- Treat foreign aura, unit, weapon-enchant, and frame data as potentially secret, inaccessible, forbidden, or protected. Gate access before comparisons, table indexing, iteration, or formatting. `pcall` contains errors; it is not a taint barrier.
- Use capability checks and the installed client API documentation. Forever's low interface number does not imply legacy Classic restrictions or Retail poison mechanics.
- Unknown observations are not confirmed missing poisons. Keep unsupported mechanics explicit until verified.
- Defer restricted/protected UI mutations and audit teardown, stale timers, and edit callbacks alongside setup.
- Keep `/np test` safe in a live session. Use detached addon fixtures and addon-owned wrappers. Never replace Blizzard globals, shared UI tables, C_* methods, secret/access helpers, or live addon state in tests. Offline global stand-ins belong only in `scripts/test.lua` and `scripts/smoke.lua`, which must stay out of the TOC.
- Run `lua scripts/test.lua` and `lua scripts/test.lua . reverse`, the Retail/Forever `scripts/smoke.lua` simulations, parse Lua files, and check TOC paths and `git diff --check` after relevant changes. Offline results do not prove client rendering, audio, or engine-level taint safety.
- Do not run `scripts/bump_version.sh` for a local audit: it commits, pushes, and tags a release. Do not publish releases without user authorization.

- `Libs/libchev` is an immutable private dependency. Never edit embedded files; request upstream changes and vendor an explicitly validated revision with its `scripts/vendor.py`. Run vendor manifest/hash checks after changes.
