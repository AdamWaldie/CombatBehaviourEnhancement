# Standalone boundary

Combat Behaviour Enhancement (CBE) owns the `CBE_fnc_*` API and `CBE_*` feature flags. It starts with guarded defaults,
locality ownership and JIP readiness without relying on a mission-side settings snapshot.

CBE deliberately excludes scenario-owned Dynamic AA/AO, logistics, transport, paradrop, economy and UI
systems. Their units can be observed when eligible, but spawning, tasking, fire gates and lifecycle stay
with the system that owns them. `Waldo_AI_ExternalControl` and `Waldo_AI_PrecisionExclude` provide the
public handover contract without coupling CBE to another implementation.

Integrations consume released CBE packages and public contracts. They must not copy addon source or
start a competing controller for an actor CBE already owns.
