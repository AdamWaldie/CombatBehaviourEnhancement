/*
 * Author: WaldoTheWarfighter
 * Purpose: Reconstruct one finite civilian escape observer from its original public receipt.
 * Locality/authority: Actual actor/group owner; admission issues no native movement. The existing
 * CivilianStep rechecks current task/route and the shared once-per-generation retry receipt.
 * Repeat/JIP: Private observer serial and existing keyed scheduler prevent duplicate callbacks.
 * Indoor binding must still match the original visible living building and scale on adoption.
 * The original server-time deadline is never renewed. Native actor/group Local edges permit a
 * coalesced two-second receipt-delivery check; it cannot authorise travel or extend that deadline.
 * No permanent worker, world scan or periodic progress publication. A new owner samples fresh
 * local progress within the remaining original window; retry consumption survives migration.
 * Arguments: 0 civilian OBJECT objNull; 1 native locality edge BOOL false (internal callers only).
 * Return: BOOL true for an existing/new observer, false for missing/expired/refused receipt.
 * Current callers: CivilianReact, CivilianSetup, native Local handlers and finite delivery check.
 * Example: [_civilian] call CBE_fnc_CortexCivilianAdopt;
 */
params [["_unit",objNull,[objNull]],["_edge",false,[true]]];
if (isNull _unit || {!local _unit} || {isPlayer _unit}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true])}
    || {[] call CBE_fnc_CortexIsPaused}) exitWith {false};
private _ticket=_unit getVariable ["CBE_Cortex_CivilianAdoptTicket",[]];
if (_edge && {_ticket isEqualTo []}) then {
    private _edgeSerial=1+(_unit getVariable ["CBE_Cortex_CivilianAdoptSerial",0]);
    _unit setVariable ["CBE_Cortex_CivilianAdoptSerial",_edgeSerial];
    _ticket=[clientOwner,_edgeSerial,serverTime+2];
    _unit setVariable ["CBE_Cortex_CivilianAdoptTicket",_ticket];
};
private _wait={
    if (count _ticket != 3 || {(_ticket select 0) != clientOwner}
        || {serverTime >= (_ticket select 2)}) exitWith {
        _unit setVariable ["CBE_Cortex_CivilianAdoptTicket",nil];false
    };
    if ((_unit getVariable ["CBE_Cortex_CivilianAdoptQueued",[]]) isNotEqualTo _ticket) then {
        _unit setVariable ["CBE_Cortex_CivilianAdoptQueued",+_ticket];
        [{
            params ["_actor","_expected"];
            if (!isNull _actor && {local _actor}
                && {(_actor getVariable ["CBE_Cortex_CivilianAdoptTicket",[]]) isEqualTo _expected}
                && {(_actor getVariable ["CBE_Cortex_CivilianAdoptQueued",[]]) isEqualTo _expected}) then {
                _actor setVariable ["CBE_Cortex_CivilianAdoptQueued",nil];
                [_actor] call CBE_fnc_CortexCivilianAdopt;
            };
        },[_unit,+_ticket],0.5 min (((_ticket select 2)-serverTime) max 0)] call CBA_fnc_waitAndExecute;
    };
    false
};
private _group=group _unit;
private _receipt=_unit getVariable ["CBE_Cortex_CivilianReaction",[]];
if (!local _group || {_receipt isEqualTo []}) exitWith {call _wait};
private _typed=_receipt isEqualType [] && {count _receipt == 8}
    && {[0,1,2] findIf {!((_receipt select _x) isEqualType 0) || {!finite (_receipt select _x)}} < 0}
    && {(_receipt select 2) >= 0} && {(_receipt select 2) == floor (_receipt select 2)}
    && {(_receipt select 3) isEqualType ""} && {(_receipt select 4) isEqualType []}
    && {count (_receipt select 4) == 3}
    && {(_receipt select 4) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {(_receipt select 5) isEqualType []} && {(_receipt select 5) isNotEqualTo []}
    && {(_receipt select 6) isEqualType grpNull} && {(_receipt select 6) == _group};
// Binding is either absent for an exterior escape, or the exact current indoor geometry.
private _shelter=if (_typed) then {_receipt param [7,false]} else {false};
_typed=_typed && {_shelter isEqualType []} && {_shelter isEqualTo [] || {
    count _shelter == 2 && {(_shelter select 0) isEqualType objNull}
        && {!isNull (_shelter select 0)} && {alive (_shelter select 0)}
        && {!isObjectHidden (_shelter select 0)}
        && {(_shelter select 1) isEqualTo [getPosWorld (_shelter select 0),vectorDir (_shelter select 0),vectorUp (_shelter select 0),getObjectScale (_shelter select 0)]}
}};
if (!_typed || {serverTime >= (_receipt select 0)}
    || {(_receipt select 2) != (_unit getVariable ["CBE_Cortex_CivilianGeneration",-1])}
    || {side _group != civilian} || {!([_unit] call CBE_fnc_CortexCombatEffective)}
    || {primaryWeapon _unit != "" || {secondaryWeapon _unit != ""} || {handgunWeapon _unit != ""}}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {
    _unit setVariable ["CBE_Cortex_CivilianAdoptTicket",nil];false
};
private _observer=_unit getVariable ["CBE_Cortex_CivilianObserver",[]];
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
if (count _observer == 5 && {(_observer select [0,3]) isEqualTo [_receipt select 2,clientOwner,_epoch]}
    && {(_observer select 4) isEqualType createHashMap}
    && {!((_observer select 4) getOrDefault ["cancelled",false])}
    && {!((_observer select 4) getOrDefault ["completed",false])}) exitWith {
    _unit setVariable ["CBE_Cortex_CivilianAdoptTicket",nil];true
};
private _serial=1+(_unit getVariable ["CBE_Cortex_CivilianObserverSerial",0]);
_unit setVariable ["CBE_Cortex_CivilianObserverSerial",_serial];
private _generation=_receipt select 2;
private _until=_receipt select 0;
private _retry=_unit getVariable ["CBE_Cortex_CivilianRetrySpent",[]];
// Missing delayed budget is unknown, never permission to create another retry.
if (!(_retry isEqualType []) || {count _retry != 4}
    || {(_retry select [0,3]) isNotEqualTo [_generation,_until,_group]}
    || {!((_retry select 3) isEqualType true)}) exitWith {call _wait};
private _used=_retry select 3;
private _state=createHashMapFromArray [["group",_group],["unit",_unit],["generation",_generation],
    ["shelter",if (_shelter isEqualTo []) then {[]} else {[_shelter select 0,(_shelter select 1) apply {if (_x isEqualType []) then {+_x} else {_x}}]}],
    ["destination",+(_receipt select 4)],["until",_until],["nativeOrder",+(_receipt select 5)],
    ["lastPosition",getPosASL _unit],["lastProgressAt",serverTime],["reissued",_used],
    ["observerOwner",clientOwner],["observerSerial",_serial],["completed",false],["cancelled",false],["subsystem","TACTICS"]];
_unit setVariable ["CBE_Cortex_CivilianObserver",[_generation,clientOwner,_epoch,_serial,_state]];
_unit setVariable ["CBE_Cortex_CivilianAdoptTicket",nil];
[CBE_fnc_CortexCivilianStep,_state,2 min ((_until-serverTime) max 0),
    "CBE_CIVILIAN_"+netId _unit] call CBE_fnc_CortexQueueJob;
!(_state getOrDefault ["cancelled",false])
