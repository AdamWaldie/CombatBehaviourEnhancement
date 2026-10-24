# Standalone boundary

Combat Behaviour Enhancement (CBE) owns the `CBE_fnc_*` API and `CBE_*` feature flags. It starts with guarded defaults,
locality ownership and JIP readiness without relying on a mission-side settings snapshot.

CBE deliberately excludes scenario-owned Dynamic AA/AO, logistics, transport, paradrop, economy and UI
systems. Their units can be observed when eligible, but spawning, tasking, fire gates and lifecycle stay
with the system that owns them. `Waldo_AI_ExternalControl` and `Waldo_AI_PrecisionExclude` provide the
public handover contract without coupling CBE to another implementation.

Integrations consume released CBE packages and public contracts. They must not copy addon source or
start a competing controller for an actor CBE already owns.


Declare active ownership on the controlled actor or its group with `setVariable ["Waldo_AI_ExternalControl",true,true]`; set it to `false` when that controller releases authority. The actor classifier reads this declaration before its immutable class memo, including on repeated calls after an ordinary classification. Unknown/non-boolean declarations yield rather than granting CBE control. An actor declaration blocks group-wide CBE commands but does not exclude an unrelated actor from an explicitly actor-scoped request. A group declaration remains group-wide. Clearing the marker permits fresh classification; it does not prove the external controller has stopped its workers or resume an old CBE operation. The controlling integration remains responsible for real handover and shutdown. Live transitions and performance are unverified while audits are paused.
