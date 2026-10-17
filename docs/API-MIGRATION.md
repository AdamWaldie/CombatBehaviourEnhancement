# First-release CBE API

Combat Behaviour Enhancement uses `CBE_fnc_*` functions and `CBE_*` settings, state, events and module/addon class identifiers. There are no earlier product-name aliases. See [CBE namespace and packaging](CBE-MIGRATION.md).

Use CBE names in mission scripts, remote-execution allowlists, overrides, native module references and CBA presets. Addon functions are registered under one `CfgFunctions` tag, CBE. The virtual root is `z\cbe\addons`.

CBA Addon Options owns effective settings and JIP synchronization. Call `CBE_fnc_CortexTuning` on the authoritative server, or through its validated curator path, for runtime changes. Removed experimental settings transport functions are not restored by this naming change.

External provider APIs and cross-product ownership markers retain their providers' names. The permanent signing key and repository URL are unchanged. This is a source/package rename, not new gameplay acceptance.
