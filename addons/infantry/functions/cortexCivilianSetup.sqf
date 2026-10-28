/*
 * Author: WaldoTheWarfighter
 * Installs the event-driven CBE civilian danger response on one owner-local unarmed civilian.
 * Player, Zeus, specialist and neutral external-control ownership is left completely untouched.
 * No per-frame or periodic civilian scan is created. FiredNear, Suppressed, Explosion and Hit request a
 * priority-aware finite reaction through the shared scheduler. A positive local Hit also permits
 * at most two nearby own-group distress probes/reactions per ten seconds, within30m. This is
 * an injury approximation, not a native scream detector; it shares no attacker identity.
 * No new event handler, world scan, sound, inventory or secondary movement controller.
 *
 * Locality / Authority: Shared all-machine class/Local hook calls setup; only the actual owner
 * installs reactions/adopts observation. Group Local handles split arrival order.
 * Repeat/JIP: handler IDs are removed before replacement. Actor and group Local edges
 * reconstruct only the original finite observer; shared retry consumption and deadline survive.
 * Disabling retires the observer and consumes the current eight-field reaction retry;
 * re-enabling may observe that original leg but cannot reissue a cancelled retry.
 * Native Local receipt checks are finite; there is no periodic civilian/world scan.
 *
 * Arguments:
 * 0: civilian <OBJECT>, default objNull
 * 1: remove <BOOL>, default false
 * 2: actual native Local edge <BOOL>, false; internal shared class-hook caller only
 *
 * Return Value:
 * Boolean - true when handlers are installed or removed, false when the unit is ineligible.
 *
 * Current callers: Cortex init, EntityCreated, shared CAManBase class/Local hook and group Local.
 *
 * Example:
 * [_civilian] call CBE_fnc_CortexCivilianSetup;
 * Result: gunfire near that owner-local civilian can trigger one bounded escape command.
 */

params [["_unit",objNull,[objNull]],["_remove",false,[true]],["_localEdge",false,[true]]];
if (isNull _unit || {!(_unit isKindOf "CAManBase")}) exitWith {false};
// The shared CAManBase Local hook runs on every machine; invalidate only this
// machine's stale observer/tickets on either edge, never another owner's public receipt.
if (_localEdge) then {
    private _observer=_unit getVariable ["CBE_Cortex_CivilianObserver",[]];
    if (count _observer == 5) then {(_observer select 4) set ["cancelled",true]};
    _unit setVariable ["CBE_Cortex_CivilianObserver",nil];
    _unit setVariable ["CBE_Cortex_CivilianAdoptTicket",nil];
    _unit setVariable ["CBE_Cortex_CivilianAdoptQueued",nil];
};
private _handlers=_unit getVariable ["CBE_Cortex_CivilianHandlers",[]];
{_unit removeEventHandler _x} forEach _handlers;
_unit setVariable ["CBE_Cortex_CivilianHandlers",nil];
if (_remove) exitWith {
    private _observer=_unit getVariable ["CBE_Cortex_CivilianObserver",[]];
    if (count _observer == 5) then {(_observer select 4) set ["cancelled",true]};
    _unit setVariable ["CBE_Cortex_CivilianObserver",nil];
    _unit setVariable ["CBE_Cortex_CivilianAdoptTicket",nil];
    _unit setVariable ["CBE_Cortex_CivilianAdoptQueued",nil];
    // Disabling cancels retry permission; re-enable may observe, never replay old movement.
    private _receipt=_unit getVariable ["CBE_Cortex_CivilianReaction",[]];
    if (local _unit && {count _receipt == 8}) then {
        _unit setVariable ["CBE_Cortex_CivilianRetrySpent",[_receipt select 2,_receipt select 0,_receipt select 6,true],true];
    };
    private _group=group _unit;
    private _groupLocal=_group getVariable ["CBE_Cortex_CivilianGroupLocalHandler",-1];
    if (_groupLocal >= 0) then {_group removeEventHandler ["Local",_groupLocal]};
    _group setVariable ["CBE_Cortex_CivilianGroupLocalHandler",nil];
    true
};
if (!local _unit || {isPlayer _unit} || {side group _unit != civilian}
    || {primaryWeapon _unit != "" || {secondaryWeapon _unit != ""} || {handgunWeapon _unit != ""}}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true])}
    || {[group _unit] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
private _fired=_unit addEventHandler ["FiredNear",{
    params ["_unit","_firer","_distance"];
    if (_distance <= (missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Radius",45])) then {
        [_unit,_firer,"FIRED_NEAR",1] call CBE_fnc_CortexCivilianReact;
    };
}];
// Native pass-by warnings can exist without a nearby firing event. Infer only an
// incoming direction; a distant shooter is not automatically visible to this civilian.
private _suppressed=_unit addEventHandler ["Suppressed",{
    params ["_unit",["_distance",1e6,[0]],["_shooter",objNull,[objNull]],
        ["_instigator",objNull,[objNull]],["_ammoObject",objNull,[objNull]]];
    if (!finite _distance || {_distance < 0}
        || {_distance > ((missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Radius",45]) min 30)}
        || {_unit == _shooter} || {_unit == _instigator}) exitWith {};
    private _threat=getPosATL _unit;
    if (!isNull _ammoObject) then {
        private _incoming=velocity _ammoObject;
        if (_incoming findIf {!finite _x} < 0 && {vectorMagnitude _incoming > 0.1}) then {
            _threat=_threat vectorDiff ((vectorNormalized _incoming) vectorMultiply 30);
        };
    };
    [_unit,_threat,"SUPPRESSED",2] call CBE_fnc_CortexCivilianReact;
}];
private _explosion=_unit addEventHandler ["Explosion",{
    params ["_unit","_damage","_explosionSource"];
    private _threat=if (isNull _explosionSource) then {getPosATL _unit} else {getPosATL _explosionSource};
    [_unit,_threat,"EXPLOSION",2] call CBE_fnc_CortexCivilianReact;
}];
private _hit=_unit addEventHandler ["Hit",{
    params ["_unit","_source",["_damage",0,[0]]];
    [_unit,_source,"HIT",3] call CBE_fnc_CortexCivilianReact;
    // Positive local injury is a distress approximation, not native scream detection.
    // Share the casualty location only; never disclose the attacker to nearby civilians.
    private _group=group _unit;
    if (!finite _damage || {_damage <= 0} || {!local _unit} || {!local _group}
        || {side _group != civilian} || {!([_unit] call CBE_fnc_CortexCombatEffective)}
        || {isPlayer _unit} || {!simulationEnabled _unit} || {isObjectHidden _unit}
        || {!isNull objectParent _unit}
        || {primaryWeapon _unit != "" || {secondaryWeapon _unit != ""} || {handgunWeapon _unit != ""}}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {!(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true])}
        || {[] call CBE_fnc_CortexIsPaused} || {[_group] call CBE_fnc_CortexExternalTakeover}
        || {serverTime < (_group getVariable ["CBE_Cortex_CivilianAlarmAfter",0])}) exitWith {};
    private _peers=units _group;
    if (count _peers > 16) exitWith {};
    // Coalesce the group, not each wounded actor. Suppressed hits never renew this clock.
    _group setVariable ["CBE_Cortex_CivilianAlarmAfter",serverTime+10];
    private _injuryATL=getPosATL _unit;private _injuryEye=eyePos _unit;
    private _radius=(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Radius",45]) max 0 min 30;
    private _probes=0;
    {
        if (_probes >= 2) exitWith {};
        private _peer=_x;
        private _active=_peer getVariable ["CBE_Cortex_CivilianReaction",[]];
        private _reacting=_active isNotEqualTo [] && {serverTime < (_active param [0,0,[0]])}
            && {(_active param [1,0,[0]]) >= 1};
        if (_peer != _unit && {!_reacting} && {local _peer} && {!isPlayer _peer}
            && {[_peer] call CBE_fnc_CortexCombatEffective} && {simulationEnabled _peer}
            && {!isObjectHidden _peer} && {isNull objectParent _peer}
            && {primaryWeapon _peer == "" && {secondaryWeapon _peer == ""} && {handgunWeapon _peer == ""}}
            && {currentCommand _peer in ["","WAIT","FOLLOW"]}
            && {_peer distance _unit <= _radius}) then {
            _probes=_probes+1;
            private _eye=eyePos _peer;
            // Conservative unobstructed proximity; no arbitrary wall/floor sound propagation.
            // No gaze restriction: this models distress, not locating an attacker visually.
            if (!terrainIntersectASL [_eye,_injuryEye]
                && {lineIntersectsSurfaces [_eye,_injuryEye,_peer,_unit,true,1,"VIEW","NONE"] isEqualTo []}) then {
                [_peer,_injuryATL,"INJURY_NEAR",1] call CBE_fnc_CortexCivilianReact;
            };
        };
    } forEach _peers;
}];
_unit setVariable ["CBE_Cortex_CivilianHandlers",[["FiredNear",_fired],["Suppressed",_suppressed],["Explosion",_explosion],["Hit",_hit]]];
// Group and actor ownership can arrive in either order. This group-scoped native edge
// checks only its roster; it does not create another movement controller or world scan.
private _group=group _unit;
if (isNil {_group getVariable "CBE_Cortex_CivilianGroupLocalHandler"}) then {
    private _local=_group addEventHandler ["Local",{
        params ["_taskGroup","_isLocal"];
        // Group-only migration can discard the old scheduler job while its actors
        // remain local. Invalidate that private observer on loss, so a return to the
        // same machine cannot mistake the discarded job for a live observation.
        if (!_isLocal) then {
            {if (local _x) then {
                private _observer=_x getVariable ["CBE_Cortex_CivilianObserver",[]];
                if (count _observer == 5) then {(_observer select 4) set ["cancelled",true]};
                _x setVariable ["CBE_Cortex_CivilianObserver",nil];
                _x setVariable ["CBE_Cortex_CivilianAdoptTicket",nil];
                _x setVariable ["CBE_Cortex_CivilianAdoptQueued",nil];
            }} forEach units _taskGroup;
        };
        if (_isLocal && {local _taskGroup}) then {
            {if (local _x) then {
                [_x] call CBE_fnc_CortexCivilianSetup;
                [_x,true] call CBE_fnc_CortexCivilianAdopt;
            }} forEach units _taskGroup;
        };
    }];
    _group setVariable ["CBE_Cortex_CivilianGroupLocalHandler",_local];
};
[_unit,_localEdge] call CBE_fnc_CortexCivilianAdopt;
true
