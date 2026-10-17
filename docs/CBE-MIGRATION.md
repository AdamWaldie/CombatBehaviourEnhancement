# Combat Behaviour Enhancement (CBE)

CBE is the sole product abbreviation and first-release namespace. There is no legacy product compatibility layer.

## Names and paths

- Public and internal function calls: `CBE_fnc_*`.
- CBA settings, mission/object state and addon events: `CBE_*`.
- Native Zeus module and addon dependency class IDs: `CBE_*`.
- Virtual addon root: `z\cbe\addons`.
- PBO prefix: `cbe`; optional turret policy folder: `@cbe_turret_aiming`.
- Build receipt: `cbe-build.json`; signed candidate filename: `cbe-candidate.zip`.

For example:

```sqf
[] call CBE_fnc_AITweaksDiagnosticReport;
```

The previous development namespace is not registered or forwarded. Development missions, allowlists and saved CBA presets must use the first-release CBE identifiers. Native engine command/phase strings such as `WAIT` keep their engine meaning. References to other products' actual APIs, including headless-client providers, keep those providers' names. Specialist-addon compatibility remains part of the product; the absence of legacy naming aliases does not remove those ownership boundaries.

The repository URL and local checkout location remain WaldosAITweaks until separately renamed. The permanent WaldoTheWarfighter signing key remains unchanged. Protected Workshop baselines and dated reference-review evidence retain their historical identifiers and are not rewritten.

## Artwork and validation

Selected logo: `artwork/branding/cbe-logo.png`. Selected banner: `artwork/branding/workshop-carousel-main.png`. Runtime texture: `images/branding/cbe-logo.paa`.

Use the complete local build gates for source, configuration, FSM and package consistency. Audits remain paused. A clean static build is not proof of in-engine movement, network execution or performance acceptance.
