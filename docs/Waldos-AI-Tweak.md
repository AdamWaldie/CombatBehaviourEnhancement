# CBE skill and lethality tuning

> **Use this page when:** you need to configure the skill, visibility and precision
> policy applied by Combat Behaviour Enhancement (CBE).

## Configuration authority

Configure CBE through **Options > Addon Options > Combat Behaviour Enhancement (CBE)**. CBA owns
saved values, server enforcement and replay to joining clients. The effective
`CBE_*` variables remain available to scripts for inspection, but editing
`addons/main/settings/aiConfig.sqf` changes only the packaged defaults; it is
not a mission-time settings interface.

CBA is required. ZEN is optional and adds an extended per-convoy dialog; it is
not needed for AI tuning, native Zeus orders or ordinary AI behaviour.

Every option states when it takes effect:

| Timing | Meaning |
| --- | --- |
| **Live** | The next owner-local update adopts the value. |
| **Next operation** | A newly started action is guaranteed to use it. A running action keeps its committed route and roles unless a safety check requires an earlier change. |
| **Restart required** | Requires a mission restart. No current CBE option uses this timing. |

Do not add a second settings store or a startup call in `init.sqf`. The addon
installs and replays owner-local work as AI groups move between the server and
headless clients.

## Skill profiles

Skill profiling is **off by default**. Existing saved CBA server/mission choices are retained, so turn it off explicitly if a saved configuration enabled it. Tactical behaviours remain independently enabled. Leave it off when the mission or another addon controls difficulty. To give CBE that role explicitly, enable **Apply CBE skill profiles** under **Skills** and choose a profile:

| Profile | Intended behaviour |
| --- | --- |
| `LEGACY` | Preserves the established compatibility balance. |
| `MILITIA` | Slow acquisition and forgiving lethality. |
| `LINE` | Trained regulars with restrained precision. |
| `VETERAN` | Faster, capable opposition without superhuman precision. |
| `ELITE` | Highly capable sensing, decision-making and weapon handling. |

The tactical behaviour profile is separate from the skill profile. Skill values
determine the engine's perception and weapon handling inputs; tactical settings
control whether CBE may use actions such as cover selection, movement and
coordination.

CBE applies the supported Arma skill inputs: `aimingAccuracy`, `aimingShake`,
`aimingSpeed`, `spotDistance`, `spotTime`, `commanding`, `general`, `courage`
and `reloadSpeed`. Arma difficulty and `CfgAISkill` interpolation affect the
final result. Assess live units with `skillFinal`; do not assume a requested
value is the final engine value.

## Visibility and equipment

The **Lighting** option supports Automatic, Daylight override and Low light
modes. Automatic samples ambient conditions and applies the appropriate
low-light adjustment. Equipped night-vision devices use a gentler penalty than
unaided units. The equipment check is heuristic so it works with compatible
content without requiring a fixed classname list.

Filtering options can limit tuning to selected sides or factions, exclude
factions or exact unit classes, and opt out one unit with:

```sqf
this setVariable ["CBE_AI_Exclude", true, true];
```

## Precision and dispersion

CBE deliberately separates decision quality from weapon lethality:

- **Infantry weapon dispersion** affects dismounted AI and vehicle cargo.
- **Vehicle crew precision** applies a final skill multiplier to drivers,
  commanders and gunners operating ground vehicles or aircraft.
- **Ground vehicle dispersion** applies only to ground-vehicle operators.
- **Aircraft weapon dispersion** applies only to aircraft operators.

Cargo keeps its normal infantry profile. Units marked with the public
`Waldo_AI_PrecisionExclude` marker are not modified by CBE's additional
precision layer. This avoids stacking two systems that intentionally own a
specialist weapon model.

Changing these values does not alter player projectile accuracy. They are
owner-local AI settings and remain bounded by the engine's normal skill system.

## Custom profiles

Mission makers may define an additional profile before the addon applies it:

```sqf
private _profiles = missionNamespace getVariable ["CBE_AI_Profiles", createHashMap];
_profiles set ["RECON", createHashMapFromArray [
    ["aimingSpeed", 0.45], ["aimingAccuracy", 0.38], ["aimingShake", 0.52],
    ["spotTime", 0.65], ["spotDistance", 0.75], ["commanding", 0.78],
    ["general", 0.70], ["courage", 0.78], ["reloadSpeed", 0.72]
]];
missionNamespace setVariable ["CBE_AI_Profiles", _profiles, true];
```

Define custom data consistently before AI can become local to the server or a
headless client. Use the CBA profile selection for normal operator changes.

## Ownership and handover

CBE never owns a unit simply because it is enabled. The local owner executes
physical actions, while the server coordinates authoritative settings and
cross-group opportunities. Zeus control, a newer authored order, player control
or an external owner cancels the conflicting CBE operation before another
movement command is issued. Cleanup restores only values owned by that operation.

If a unit appears unchanged, check its filter settings, locality, current
external owner and the operation diagnostics before changing its skill values.

## Related documentation

- [Settings reference](SETTINGS-REFERENCE.md)
- [Addon lifecycle](ADDON-LIFECYCLE.md)
- [Capability registry](CAPABILITY-REGISTRY.md)
- [Modding and operations](MODDING-AND-OPERATIONS.md)

<!-- CBE-WIKI-NAV -->
---
[Wiki home](https://github.com/AdamWaldie/CombatBehaviourEnhancement/wiki/Home) · [Installation and setup](../README.md) · [Capability registry](CAPABILITY-REGISTRY.md)

## Mission-authored skills and handover

CBE does not require its skill profiles for tactical movement, CQB or coordination. With skill profiling disabled, CBE applies no profile, lighting skill penalty, variance or crew/infantry aim coefficient. Arma difficulty and mission scripts retain those values.

When profiling is explicitly enabled, CBE records original and applied subskills and aim coefficient. Every later application checks those receipts before writing. If a mission or another addon changes a value, CBE preserves the edit, restores only its other still-unchanged effects and yields the entire optional profile for that unit. It records `CBE_AI_SkillOwner = "OBSERVED_EXTERNAL_CHANGE"`; this means a value changed, not that CBE identified the writer. This ownership marker follows the unit across locality and survives global profile changes or stop/restart. Identical-value writes cannot be identified.

A mission can reserve skill control in advance, without excluding tactical behaviour:

```sqf
// Run where the unit is local before configuring its custom skills.
_unit setVariable ["CBE_AI_SkillOwner","MISSION",true];
[_unit] call CBE_fnc_AIProfileYield;
_unit setSkill ["aimingAccuracy",0.22];
```

To deliberately return this unit to the enabled CBE profile, clear its owner label on its current owner, then apply once. This is an explicit ownership change, not an automatic timeout:

```sqf
_unit setVariable ["CBE_AI_SkillOwner",nil,true];
[_unit] call CBE_fnc_AIApplyProfile;
```

Custom partial profiles are calculated from the original snapshot on every refresh. Lighting, variance and crew multipliers therefore do not repeatedly multiply the previous CBE result. There is one final native settings commit, with current locality, profile generation and mission ownership checked again. The ownership check reads at most nine skill entries; no new watcher or world scan is installed. The existing lighting/seat job remains bounded to ten registered units per callback.

The separately maintained mission framework also writes absolute values at startup and owner adoption, and its stop path restores captured values unconditionally. Run one skill authority. CBE's default and yield rule prevent CBE from reclaiming later mission edits, but cannot stop another script from overwriting values itself. Its source was examined read-only. Helicopter landing/deceleration and taxi tasks are separate movement-authority review items; a skill label does not grant or release those tasks. Physical custom-script, JIP, owner-transfer and performance checks remain pending while audits are paused.
