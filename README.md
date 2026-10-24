# Combat Behaviour Enhancement (CBE)

Combat Behaviour Enhancement (CBE) is a standalone CBA mod for Arma 3. Its goal is aggressive, dynamic and tactically
sound AI with bounded, locality-aware work that remains subordinate to Zeus and authored mission
orders.

Skill profiling is opt-in. By default, mission-authored skills and difficulty remain in control while tactical behaviours stay independently enabled. See [skill ownership and tuning](docs/Waldos-AI-Tweak.md).

## Current foundation

The repository now builds as a conventional `z\cbe\addons\main` addon:

- CBA extended pre-init loads guarded defaults on every machine;
- CBA extended post-init starts only the systems enabled for that owner;
- public functions use the sole `CBE_fnc_*` namespace through `CfgFunctions`;
- CBA Settings owns global addon configuration and JIP synchronization;
- Native Zeus orders are included; optional ZEN supplies an extended convoy dialog;
- the standalone settings request validates the requesting curator and updates the CBA server layer;
- HEMTT owns packaging and version metadata.

Run `hemtt build` from the repository root to create the mod package. Arma 3 2.18+ and CBA_A3 are required; ZEN is optional. CBE supplies the base-soldier danger FSM and treats another replacement of that engine slot as incompatible. No external AI addon is required or bundled.

This first release uses `CBE_fnc_*` functions and `CBE_*` settings/state. No previous product-name aliases are registered. See
[API migration](docs/API-MIGRATION.md), [addon lifecycle](docs/ADDON-LIFECYCLE.md) and the
[capability registry](docs/CAPABILITY-REGISTRY.md) and the [delivery goal](docs/DELIVERY-GOAL.md).

## Product boundary

This repository owns AI behaviour:

- skill, lighting/equipment heuristics and dispersion;
- infantry contact, cover, flank, advance, assault, withdrawal, regroup, surrender and CQB;
- multi-squad and combined-arms coordination;
- convoy, passenger, vehicle gunnery and recovery behaviour;
- aircraft attack, defence, countermeasures, landing and deceleration;
- artillery support and counter-battery decisions;
- civilian, naval and airborne reactions;
- AI diagnostics, ZEN controls and the Cortex QA suite.

Mission-specific systems retain Dynamic AA, Dynamic AO, logistics, transport, paradrop, economy,
UI and their diagnostics. CBE may mark an object, unit or group with the public
`Waldo_AI_ExternalControl` flag while another system owns its behaviour. Independent weapon systems
may set `Waldo_AI_PrecisionExclude` when they intentionally own lethality. AI Tweaks contains no
Dynamic AA or Dynamic AO implementation and does not inspect their private state.

An integrating mission must yield AI skill, convoy, landing, deceleration and Cortex ownership when
`CBE_AI_Tweaks_Main` is present. CBE will release its work immediately when another eligible system
records external ownership.

## Authority and Zeus

The server owns public settings and cross-group decisions, including ordered replay for JIP clients.
The current unit, group or vehicle owner
executes physical behaviour. Direct Zeus selection, editing and waypoints interrupt Cortex control;
the addon restores only state it changed. Locality changes retire stale jobs and repeat owner-local
setup.

## Validation

Static validation lives under `releaseVerificationAndDeployment`. It checks SQF structure, the addon
layout, product boundaries, feature coverage and implementation contracts. Aircraft, convoy, CQB,
performance and multiplayer locality still require the generated dedicated-server/client audit in
batched runs. Static success is not an in-engine acceptance claim.

See [the current inventory](docs/CURRENT-INVENTORY.md), [the CBA migration plan](docs/CBA-MIGRATION.md)
and [the standalone boundary](docs/EXTRACTION-BOUNDARY.md).

See [modding and operations](docs/MODDING-AND-OPERATIONS.md) for packaged local audits,
signed release promotion and the execution-method assessment.
See [matched performance validation](docs/PERFORMANCE-VALIDATION.md) for native/CBE patrol pairs and their acceptance limits.

See [contribution and documentation requirements](CONTRIBUTING.md) and [all CBA settings](docs/SETTINGS-REFERENCE.md).

Native Zeus provides **Convoy: start / resume**, **Convoy: hold and unload passengers**, and
**Convoy: release control** under Combat Behaviour Enhancement (CBE). Place the order directly on a crewed AI land
vehicle; group at least two AI-driven vehicles and give the leader its route before starting.
New convoys use the CBA default speed, separation and push-through options. Resume preserves
existing convoy settings. Optional ZEN adds a dialog for per-convoy settings. Neither interface
replaces ordinary Zeus waypoints. Missions still determine which addons/modules a curator may use.

The audit launcher defaults to CBA only. Use `-WithZen` for the optional-dialog compatibility batch.
Native module placement, late Zeus assignment and both dependency variants remain queued for
physical acceptance; static validation alone does not establish those behaviours.

CBA Addon Options is split into **General**, **Skills**, **Infantry**, **Coordination**, **Vehicles**,
**Convoys**, **Aircraft**, and **Support and civilians**. Each page groups related controls and
places enable switches before tuning. Existing saved option keys and defaults are preserved.
Vehicles covers general combat and passenger decisions. Convoys covers explicitly registered
columns, their spacing, driving assistance and halt/unload rules. Convoy driving assistance does
not enable a standalone general driving controller. See the [settings reference](docs/SETTINGS-REFERENCE.md).

Current implementation, physical acceptance and progression blockers are recorded in [the completion status](docs/COMPLETION-STATUS.md).

## Optional engine policy

The packaged optionals folder contains a separate AI Turret Aiming addon. Load that optional mod alongside CBE to apply a restart-required AI turret aiming-error ceiling of 0.12 radians. It changes no weapon dispersion, ammunition, projectile or recoil properties. CBA switches cannot unload an engine configuration patch; remove the optional mod and restart to restore the base configuration. Default CBE installation does not load it. Physical lethality, player precision and compatibility acceptance remain pending.

For packaged audit comparisons, use the checked-in launcher with -EnginePolicies turret_aiming for the policy arm and omit it for the default arm. The launcher records the selection and uses the same sealed optional addon on every participating machine; native baseline runs reject CBE engine policies.

Navigation corridors are available as a native Zeus behaviour task and optional ZEN dialog.
They define an explicit area, facing, dimensions and task speed for ordinary/convoy lead routing;
CBA still owns addon settings. See [corridor controls and limitations](docs/Smart-AI-Pass.md#navigation-corridor-operator-controls).
Physical corridor/module acceptance remains pending.

### Permanent signing authority

Signed candidates reuse the external `WaldoTheWarfighter` pair. The pinned public-key SHA-256 is `297f847320561498d0c04e8db2e0570f60b770f1f932adcdcc20c45c2275c889`; a missing or mismatched key stops signing. Never regenerate or rename this authority. HEMTT release packing uses `--no-sign --no-archive`; signing is a separate step.

The encrypted Actions secret `WALDO_SIGNING_KEYPAIR` contains JSON fields `privateKey` and `publicKey`, each base64 encoded. Configure it through stdin, never a command-line value or committed file. Signing removes the secret from the environment before invoking tools, decodes into a temporary directory outside the checkout and removes that directory afterward. Only the public `.bikey` and PBO `.bisign` files enter the package.

The candidate workflow pins armake2 commit `3cc3362101900ff41504db3e780dd1625634cf94` with the retained file-ordering and compiled-SQF patch. Local signing may use the fingerprint-pinned Bohemia DSSignFile executable. `sign_release.py` independently checks every PBO with HEMTT, rejects damaged signature copies, seals file hashes and exports `cbe-candidate.zip`, its SHA-256 and `signing-verification.json`. Promotion repeats pinned-key verification on the exact candidate. These checks prove packaging/signatures, not AI or performance acceptance. Candidate generation does not publish a release or upload to Steam.


Candidate signing and independent verification cover every PBO recursively, including optional addon folders. An unsigned optional addon prevents export just as an unsigned main addon does. The earlier local `permanent-key-final-20261016` artifact omitted the optional turret policy signature and is superseded; do not distribute it.

## CBE naming and artwork

CBE abbreviates Combat Behaviour Enhancement. The selected logo and Workshop banner are in `artwork/branding/`. See [CBE migration](docs/CBE-MIGRATION.md) for function names and retained mission contracts.


The separate **Native Suppression Recovery** optional addon supplies a native AI recovery baseline alongside the scripted danger reactions. Load `optionals/@cbe_suppression` with CBE on every participating machine. At the minimum/maximum skill endpoints, suppression decay uses 25/4 seconds and aim settling uses 3.5/0.6 seconds; explosion influence is 1.5 and turning influence is 1.2. These are engine configuration parameters, not guaranteed observed timings under continued fire. The policy does not change mission-set skills, maximum aim-error angles, weapons or ammunition. It is global to the default soldier brain, including actors excluded from CBE tactics, and remains active when CBA tactics switches are off. Remove the optional addon and restart to remove its overrides. Other configuration addons can override the same properties; diagnostics report effective values. Balance and performance remain unverified. The audit launcher accepts `-EnginePolicies suppression` or both policies, records the selection and rejects policies in a native-baseline run.


The separate **Native Launcher Policy** optional addon (`optionals/@cbe_launcher_policy`) changes native AI RPG-7/RPG-32 firing preferences, cadence and AI-only dispersion, plus target-use flags for PG-7, PG-32, SPG-9 HEAT and MAAWS HEAT ammunition. PG-7/PG-32 permit native consideration of infantry, light vehicles, aircraft and armour; the other two omit the air flag. Flags are AI usage preferences, not guaranteed shots or a replacement for native target knowledge and ROE.

This selected native policy preserves player dispersion/recoil/sounds, ammunition cost, projectile physics and damage. It does not implement CUP/RHS/SOG adapters or change lock behaviour. Its short minimum firing distances and target preferences need physical balance and friendly-safety validation; native autonomous shots do not pass through CBE's scripted launcher line-of-fire gate. It applies globally to affected config classes, including AI excluded from CBE tactics, and remains loaded when CBA tactics are disabled. It is **not loaded by default**: load it consistently on every participating machine, and remove it and restart to remove the overrides. Diagnostics read the effective values and report mismatches from other configuration addons. The paused audit launcher supports `-EnginePolicies launcher_policy`; no audit has been run for this policy.
