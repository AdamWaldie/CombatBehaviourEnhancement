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

Enable **Apply CBE skill profiles** under **Skills** and choose a profile:

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
[Wiki home](https://github.com/AdamWaldie/WaldosAITweaks/wiki/Home) · [Installation and setup](../README.md) · [Capability registry](CAPABILITY-REGISTRY.md)
