/*
 * Author: WaldoTheWarfighter
 * Purpose: Register the original clearance producer on the server before later handover sealing.
 * Locality/authority: REGISTER accepts only the current group owner on server; ACK accepts only
 * server2 on the current producer. Identity registration never authorizes commands or resume.
 * Repeat/JIP: One original unexpired identity per visit. Exact duplicates retain serial/deadline;
 * conflicting same-visit producers refuse. At most512 group entries, pruned on registration,
 * no worker/timer, broadcast or JIP replay. New visits replace the same group's old entry.
 * Arguments: 0 mode STRING REGISTER/ACK default REGISTER; 1 data ARRAY default[].
 * REGISTER [group,visitContext,ownerEpoch,clearGeneration,operationGeneration];
 * ACK [group,producerOwner,visitContext,ownerEpoch,clearGeneration,operationGeneration,serial].
 * Return: BOOL registration/ack accepted; not producer quiescence, seal or incoming readiness.
 * Current callers: BuildingOperationStart after actual successful startup and own server reply.
 * Example: ["REGISTER",[_group,_visit,_epoch,_generation,_operationGeneration]]
 *   remoteExecCall ["CBE_fnc_BuildingProducerRegister",2];
 */
params [["_mode","REGISTER",[""]],["_data",[],[[]]]];
if (_data findIf {isNil "_x"} >= 0) exitWith {false};
// The direct server caller may be scheduled; registry duplicate/serial commit is atomic.
private _registrationResult=false;
isNil {
    _registrationResult=call {
if (_mode == "ACK") exitWith {
    if (!(remoteExecutedOwner == 2 || {isServer && {remoteExecutedOwner == 0} && {clientOwner == 2}})
        || {count _data != 7}) exitWith {false};
    _data params ["_group","_producer","_visit","_epoch","_generation","_operationGeneration","_serial"];
    if (!(_group isEqualType grpNull) || {isNull _group} || {!local _group}
        || {_producer isNotEqualTo clientOwner}) exitWith {false};
    private _brain=_group getVariable ["CBE_BuildingBrain",createHashMap];
    private _job=_brain getOrDefault ["job",createHashMap];
    if ((_brain getOrDefault ["producerOwner",-1]) != clientOwner
        || {(_brain getOrDefault ["ownerEpoch",-1]) isNotEqualTo _epoch}
        || {(_brain getOrDefault ["generation",-1]) isNotEqualTo _generation}
        || {(_job getOrDefault ["operationGeneration",-1]) isNotEqualTo _operationGeneration}
        || {(_job getOrDefault ["visitContext",[]]) isNotEqualTo _visit}
        || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
        || {!(["LIVE",_job] call CBE_fnc_BuildingProducerContext)}) exitWith {false};
    _job set ["producerRegistration",+_data];
    true
};
if (_mode != "REGISTER" || {!isServer} || {count _data != 5}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}) exitWith {false};
_data params ["_group","_visit","_epoch","_generation","_operationGeneration"];
private _sender=remoteExecutedOwner;
if (_sender == 0) then {_sender=clientOwner};
private _vector={_this isEqualType [] && {count _this == 3}
    && {_this findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} < 0}};
if (!(_group isEqualType grpNull) || {isNull _group} || {groupOwner _group != _sender}
    || {!(_visit isEqualType [])} || {count _visit != 4}
    || {[0,1,2,3] findIf {isNil {_visit select _x}} >= 0}
    || {[_epoch,_generation,_operationGeneration] findIf {!(_x isEqualType 0)
        || {!finite _x} || {_x < 0} || {_x != floor _x}} >= 0}
    || {!((_visit select 0) isEqualType objNull)} || {isNull (_visit select 0)}
    || {!alive (_visit select 0)} || {!((_visit select 1) isEqualType [])}
    || {count (_visit select 1) != 3} || {(_visit select 1) findIf {isNil "_x" || {!(_x call _vector)}} >= 0}
    || {!((_visit select 2) isEqualType 0)} || {!finite (_visit select 2)}
    || {serverTime >= (_visit select 2)}
    || {!((_visit select 3) isEqualType "")} || {(_visit select 3) == ""} || {count (_visit select 3) > 128}
    || {(_visit select 1) isNotEqualTo [getPosWorld (_visit select 0),vectorDir (_visit select 0),vectorUp (_visit select 0)]}) exitWith {false};
private _registry=missionNamespace getVariable ["CBE_ClearProducer_Registry",createHashMap];
{
    private _entry=_registry get _x;
    if (isNull (_entry select 0) || {serverTime >= ((_entry select 2) select 2)}) then {_registry deleteAt _x};
} forEach keys _registry;
private _key=netId _group;
if (_key in ["","0:0"]) exitWith {false};
private _existing=_registry getOrDefault [_key,[]];
private _identity=[_group,_sender,+_visit,_epoch,_generation,_operationGeneration];
if (_existing isNotEqualTo [] && {(_existing select 2) isEqualTo _visit}
    && {(_existing select [0,6]) isNotEqualTo _identity}) exitWith {false};
private _entry=+_existing;
if (_existing isEqualTo [] || {(_existing select 2) isNotEqualTo _visit}) then {
    if (_existing isEqualTo [] && {count _registry >= 512}) exitWith {};
    private _serial=1+(missionNamespace getVariable ["CBE_ClearProducer_Serial",0]);
    missionNamespace setVariable ["CBE_ClearProducer_Serial",_serial];
    _entry=_identity+[_serial];
    _registry set [_key,_entry];
};
if (count _entry != 7 || {(_entry select [0,6]) isNotEqualTo _identity}) exitWith {false};
missionNamespace setVariable ["CBE_ClearProducer_Registry",_registry];
if (_sender == 2) then {["ACK",_entry] call CBE_fnc_BuildingProducerRegister}
else {["ACK",_entry] remoteExecCall ["CBE_fnc_BuildingProducerRegister",_sender]};
true

    };
    false
};
_registrationResult
