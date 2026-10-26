/*
 * Author: WaldoTheWarfighter
 * Purpose: Exchange one finite gate-intent challenge with the exact current operating owner.
 * Locality/authority: REQUEST is local server only; PROBE accepts server2 only on crew owner;
 * REPLY accepts only the recorded owner on server. This function never animates or moves objects.
 * Repeat/JIP: No JIP replay. At most16 pending tickets, deduplicated by exact context, original
 * deadline only, consumed once. Expired entries prune on new requests; no permanent worker.
 * Arguments: 0 mode STRING empty (REQUEST/PROBE/REPLY); 1 data ARRAY empty.
 * REQUEST data: [context HASHMAP] from gate server handlers; PROBE/REPLY internal arrays.
 * Return: BOOL whether accepted, not gate clearance or physical success.
 * Current callers: DrivingGateOpenServer deferred request, DrivingGateCloseServer, own remote reply.
 * Example: ["REQUEST",[_context]] call CBE_fnc_DrivingGateOwnerEvidence;
 */
params [["_evidenceMode","",[""]],["_evidenceData",[],[[]]]];
if (_evidenceMode == "PROBE") exitWith {
    if (remoteExecutedOwner != 2 || {count _evidenceData != 11}) exitWith {false};
    _evidenceData params ["_evidenceToken","_evidenceGroup","_evidenceVehicle","_evidenceGate",
        "_evidenceRoute","_evidenceRevision","_evidenceUntil","_evidenceBefore","_evidenceTasks","_evidenceSeats","_evidenceDirection"];
    if (!(_evidenceUntil isEqualType 0) || {!finite _evidenceUntil} || {serverTime >= _evidenceUntil}
        || {!(_evidenceGroup isEqualType grpNull)} || {!(_evidenceVehicle isEqualType objNull)}
        || {!(_evidenceGate isEqualType objNull)} || {isNull _evidenceVehicle}
        || {!(_evidenceSeats isEqualType [])} || {count _evidenceSeats != 2}) exitWith {false};
    private _evidenceCommander=effectiveCommander _evidenceVehicle;
    if (isNull _evidenceCommander) then {_evidenceCommander=driver _evidenceVehicle};
    private _evidenceFrame=[];
    if ([driver _evidenceVehicle,_evidenceCommander] isEqualTo _evidenceSeats) then {
        _evidenceFrame=[_evidenceGroup,_evidenceVehicle,_evidenceRoute,_evidenceRevision,
            _evidenceBefore,_evidenceTasks,_evidenceDirection] call CBE_fnc_DrivingGateOwnerCheck;
    };
    ["REPLY",[_evidenceToken,_evidenceFrame]] remoteExecCall ["CBE_fnc_DrivingGateOwnerEvidence",2];
    true
};
if (!isServer) exitWith {false};
private _evidenceRegistry=missionNamespace getVariable ["CBE_DrivingGate_OwnerTickets",createHashMap];
if (_evidenceMode == "REQUEST") exitWith {
    if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}
        || {count _evidenceData != 1} || {!((_evidenceData select 0) isEqualType createHashMap)}) exitWith {false};
    private _evidenceContext=_evidenceData select 0;
    private _evidenceVehicle=_evidenceContext getOrDefault ["vehicle",objNull];
    private _evidenceGroup=_evidenceContext getOrDefault ["group",grpNull];
    private _evidenceUntil=_evidenceContext getOrDefault ["until",-1];
    if (isNull _evidenceVehicle || {isNull _evidenceGroup} || {!(_evidenceUntil isEqualType 0)}
        || {!finite _evidenceUntil} || {serverTime >= _evidenceUntil}
        || {_evidenceUntil > serverTime+5}) exitWith {false};
    private _evidenceOwner=owner _evidenceVehicle;
    private _evidenceCommander=effectiveCommander _evidenceVehicle;
    if (isNull _evidenceCommander) then {_evidenceCommander=driver _evidenceVehicle};
    if (_evidenceOwner != groupOwner _evidenceGroup || {_evidenceOwner != owner driver _evidenceVehicle}
        || {_evidenceOwner != owner _evidenceCommander}) exitWith {false};
    {if (serverTime >= ((_evidenceRegistry get _x) get "until")) then {_evidenceRegistry deleteAt _x}} forEach keys _evidenceRegistry;
    private _evidenceDuplicate=keys _evidenceRegistry findIf {
        private _ticket=_evidenceRegistry get _x;
        (_ticket get "vehicle") == _evidenceVehicle && {(_ticket get "gate") == (_evidenceContext get "gate")}
            && {(_ticket get "action") == (_evidenceContext get "action")}
    } >= 0;
    if (_evidenceDuplicate || {count _evidenceRegistry >= 16}) exitWith {false};
    private _evidenceSerial=1+(missionNamespace getVariable ["CBE_DrivingGate_OwnerSerial",0]);
    missionNamespace setVariable ["CBE_DrivingGate_OwnerSerial",_evidenceSerial];
    private _evidenceToken=str _evidenceSerial;
    _evidenceContext set ["owner",_evidenceOwner];
    _evidenceContext set ["seats",[driver _evidenceVehicle,_evidenceCommander]];
    _evidenceRegistry set [_evidenceToken,_evidenceContext];
    missionNamespace setVariable ["CBE_DrivingGate_OwnerTickets",_evidenceRegistry];
    ["PROBE",[_evidenceToken,_evidenceGroup,_evidenceVehicle,_evidenceContext get "gate",
        _evidenceContext get "route",_evidenceContext get "revision",_evidenceUntil,
        _evidenceContext getOrDefault ["native",[]],_evidenceContext getOrDefault ["tasks",[]],
        _evidenceContext get "seats",_evidenceContext getOrDefault ["direction",1]]] remoteExecCall ["CBE_fnc_DrivingGateOwnerEvidence",_evidenceOwner];
    true
};
if (_evidenceMode != "REPLY" || {count _evidenceData != 2}) exitWith {false};
_evidenceData params ["_evidenceToken","_evidenceFrame"];
if (!(_evidenceToken isEqualType "") || {!(_evidenceFrame isEqualType [])}) exitWith {false};
private _evidenceContext=_evidenceRegistry getOrDefault [_evidenceToken,createHashMap];
if (count _evidenceContext == 0 || {remoteExecutedOwner != (_evidenceContext get "owner")}) exitWith {false};
_evidenceRegistry deleteAt _evidenceToken;
missionNamespace setVariable ["CBE_DrivingGate_OwnerTickets",_evidenceRegistry];
private _evidenceVehicle=_evidenceContext get "vehicle";
private _evidenceGroup=_evidenceContext get "group";
private _evidenceCommander=effectiveCommander _evidenceVehicle;
if (isNull _evidenceCommander) then {_evidenceCommander=driver _evidenceVehicle};
if (serverTime >= (_evidenceContext get "until") || {isNull _evidenceVehicle}
    || {owner _evidenceVehicle != remoteExecutedOwner} || {groupOwner _evidenceGroup != remoteExecutedOwner}
    || {owner driver _evidenceVehicle != remoteExecutedOwner} || {owner _evidenceCommander != remoteExecutedOwner}
    || {[driver _evidenceVehicle,_evidenceCommander] isNotEqualTo (_evidenceContext get "seats")}
    || {count _evidenceFrame != 2} || {!((_evidenceFrame select 0) isEqualType [])}
    || {count (_evidenceFrame select 0) != 2} || {!((_evidenceFrame select 1) isEqualType [])}
    || {count (_evidenceFrame select 1) != 2}) exitWith {false};
if ((_evidenceContext get "action") == "OPEN") exitWith {
    _evidenceVehicle setVariable ["CBE_DrivingGate_OpenWitness",[_evidenceToken,_evidenceContext,_evidenceFrame]];
    [_evidenceContext get "payload",_evidenceToken] call CBE_fnc_DrivingGateOpenServer;
    true
};
private _evidenceJob=_evidenceContext get "job";
private _evidenceGate=_evidenceContext get "gate";
if ((_evidenceGate getVariable ["CBE_DrivingGate_CloseWork",createHashMap]) isNotEqualTo _evidenceJob
    || {_evidenceJob getOrDefault ["done",true]}) exitWith {false};
_evidenceJob set ["ownerReply",[_evidenceContext get "until",_evidenceFrame]];
true
