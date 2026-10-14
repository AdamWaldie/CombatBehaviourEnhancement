/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies only the current server driving snapshot and reports actual owner-local admission.
 * Locality / Authority: Only server dispatch is accepted; current local group/crew and monotonic local revision are rechecked.
 * Repeat/JIP: Revisioned group exclusion state is public; command effects are owner-local.
 * No JIP command replay. Repeated and stale acknowledgements cannot replace newer requests.
 * Arguments: 0 target <OBJECT>; 1 group <GROUP>; 2 revision <NUMBER>; 3 operation <STRING>; 4 exclusions <ARRAY>.
 * Return Value: Nothing.
 * Current callers: DrivingControlRequest.
 * Example: [truck1,group driver truck1,1,"INSPECT",[]] call WAIT_fnc_DrivingControlLocal;
 */
params [["_target",objNull,[objNull]],["_group",grpNull,[grpNull]],["_revision",-1,[0]],
    ["_operation","",[""]],["_disabled",[],[[]]]];
if (remoteExecutedOwner != 2 && {!(remoteExecutedOwner == 0 && {isServer})}) exitWith {};
if (isNull _group) exitWith {};
if (!local _group || {isNull _target} || {group driver _target != _group}) exitWith {
    [_group,_revision,"OWNER_OR_CREW_CHANGED",false] remoteExecCall ["WAIT_fnc_DrivingControlResult",2]
};
private _seen=_group getVariable ["WAIT_Driving_ControlSeen",-1];
if (_revision <= _seen || {_revision < (_group getVariable ["WAIT_Driving_ControlRevision",-1])}) exitWith {};
_group setVariable ["WAIT_Driving_ControlSeen",_revision];
// Ordered payload supplies state before activation, independently of public-variable arrival.
if (_operation != "INSPECT") then {_group setVariable ["WAIT_AIPass_DisabledFeatures",_disabled]};
private _admitted=false;private _reason="";
switch (_operation) do {
    case "ENABLE": {
        _admitted=[_group] call WAIT_fnc_DrivingOperationStart;
        _reason=if (_admitted) then {"Enabled; native-route driving FSM admitted. Physical movement is not yet verified."}
            else {"Group enabled, but admission is waiting for a valid route, global settings or movement ownership."};
    };
    case "RELEASE": {
        private _brain=_group getVariable ["WAIT_Driving_Brain",createHashMap];
        if (count _brain > 0) then {[_brain,"OPERATOR_RELEASE"] call WAIT_fnc_DrivingOperationFinish};
        {[_x,_group] call WAIT_fnc_DrivingAssistRelease} forEach (_group getVariable ["WAIT_DrivingAssist_Vehicles",[]]);
        _reason="Ordinary driving released and excluded for this group. Native orders remain authoritative.";
        _admitted=true;
    };
    case "INSPECT": {
        private _brain=_group getVariable ["WAIT_Driving_Brain",createHashMap];
        _reason=format ["%1: phase %2; reason %3; group gate %4; owner %5. State is not physical success.",
            groupId _group,_brain getOrDefault ["phase","NONE"],_brain getOrDefault ["cancelReason",""],
            [_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled,clientOwner];
        _admitted=true;
    };
};
[_group,_revision,_reason,_admitted] remoteExecCall ["WAIT_fnc_DrivingControlResult",2];
