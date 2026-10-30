/*
 * Author: WaldoTheWarfighter
 * Purpose: Read one bounded native believed aircraft contact, shared by initial planning
 * and active attack geometry. Prefer personal evidence, then newer native observation;
 * retain legitimate group-shared contacts without exact position/velocity fallback or reveal.
 * Locality/authority: Read-only on the pilot owner; considers at most8 local combat-effective
 * group members, pilot first. No native commands, world scans, timers or replicated permissions.
 * Repeat/JIP: Stateless; callers retain their original finite operation deadlines and ownership.
 * Arguments: 0 pilot <OBJECT, objNull>; 1 target <OBJECT, objNull>.
 * Return Value: ARRAY [believed ASL position3, observer OBJECT, native observation time NUMBER,
 * personal evidence BOOL], or [] when native evidence is unavailable/ignored/malformed.
 * Current callers: CortexAirAttackPlan and CortexAirAttack.
 * Example: private _contact=[driver _plane,_hostile] call CBE_fnc_CortexAirContact;
 * Limits: Native belief can be wrong or extrapolated. This does not prove visibility, a hit,
 * safe fire or how the engine executes an object-associated DESTROY order.
 */
params [["_pilot",objNull,[objNull]],["_target",objNull,[objNull]]];
if (isNull _pilot || {!local _pilot} || {isNull _target} || {!alive _target}) exitWith {[]};
private _targetPos=[];
private _knower=objNull;
private _latestObservation=-1;
private _personalWitness=false;
private _observers=([_pilot]+((units group _pilot)-[_pilot])) select [0,8];
{
    if (local _x && {[_x] call CBE_fnc_CortexCombatEffective} && {_x knowsAbout _target >= 1}) then {
        private _knowledge=_x targetKnowledge _target;
        private _observedAt=(_knowledge param [2,-1,[0]]) max (_knowledge param [3,-1,[0]]);
        private _personal=_knowledge param [1,false,[true]];
        private _preferred=_targetPos isEqualTo [] || {_personal && {!_personalWitness}}
            || {_personal isEqualTo _personalWitness && {_observedAt > _latestObservation}};
        if ((_knowledge param [0,false,[true]]) && {!(_knowledge param [7,false,[true]])}
            && {finite _observedAt} && {_preferred}) then {
            private _belief=_x getHideFrom _target;
            if (count _belief == 3 && {_belief isNotEqualTo [0,0,0]}
                && {_belief findIf {!(_x isEqualType 0) || {!finite _x}} < 0}) then {
                _targetPos=+_belief;
                _knower=_x;
                _latestObservation=_observedAt;
                _personalWitness=_personal;
            };
        };
    };
} forEach _observers;
if (_targetPos isEqualTo []) exitWith {[]};
[ATLToASL _targetPos,_knower,_latestObservation,_personalWitness]
