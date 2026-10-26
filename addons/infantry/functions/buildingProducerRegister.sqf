/*
 * Author: WaldoTheWarfighter
 * Purpose: Register the original clearance producer and retain bounded unsealed server checkpoints.
 * Locality/authority: REGISTER accepts only the current group owner on server; ACK accepts only
 * server2 on the current producer. CAPTURE requires the registered original sender on server,
 * even after group ownership changes. Neither registration nor storage authorizes commands/resume.
 * Repeat/JIP: One original unexpired identity per visit. Exact duplicates retain serial/deadline;
 * conflicting same-visit producers refuse. At most512 group entries; deleted groups prune on registration,
 * no worker/timer, broadcast or JIP replay. Identity retention grants no deadline extension;
 * it remains available through original EGRESS. New visits replace the same group's old entry.
 * Arguments: 0 mode STRING REGISTER/ACK/CAPTURE default REGISTER; 1 data ARRAY default[].
 * REGISTER [group,visitContext,ownerEpoch,clearGeneration,operationGeneration];
 * ACK [group,producerOwner,visitContext,ownerEpoch,clearGeneration,operationGeneration,serial].
 * CAPTURE [registration ARRAY,original capture ARRAY,retiredAt NUMBER,writerCount NUMBER,incomingOwner NUMBER].
 * Server retains only an unsealed five-second candidate; no incoming executor consumes it.
 * Return: BOOL registration/ack/candidate accepted; not producer quiescence, seal or incoming readiness.
 * Current callers: BuildingOperationStart after actual successful startup, BuildingProducerRetire
 * after original-FSM/metadata checks, and own server reply.
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
if (_mode == "CAPTURE") exitWith {
    if (!isServer || {count _data != 5} || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}) exitWith {false};
    _data params ["_registration","_capture","_retiredAt","_writerCount","_incomingOwner"];
    if (!(_registration isEqualType []) || {count _registration != 7}
        || {[0,1,2,3,4,5,6] findIf {isNil {_registration select _x}} >= 0}
        || {!((_registration select 0) isEqualType grpNull)} || {isNull (_registration select 0)}) exitWith {false};
    private _group=_registration select 0;
    private _key=netId _group;
    private _registry=missionNamespace getVariable ["CBE_ClearProducer_Registry",createHashMap];
    private _original=_registry getOrDefault [_key,[]];
    private _sender=remoteExecutedOwner;
    if (_sender == 0) then {_sender=clientOwner};
    // Current ownership may already have moved: only the registered original sender can submit.
    if (_original isNotEqualTo _registration || {_sender != (_original select 1)}
        || {!(_incomingOwner isEqualType 0)} || {!finite _incomingOwner} || {_incomingOwner < 2}
        || {_incomingOwner != floor _incomingOwner} || {_incomingOwner == _sender}
        || {groupOwner _group != _incomingOwner}
        || {!(_capture isEqualType [])} || {count _capture != 17}
        || {[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16] findIf {isNil {_capture select _x}} >= 0}
        || {(_capture select [0,5]) isNotEqualTo [12,_sender,_original select 4,_original select 3,_original select 5]}
        || {!((_capture select 5) isEqualType 0)} || {!finite (_capture select 5)}
        || {(_capture select 5) > serverTime+1} || {serverTime > (_capture select 5)+5}
        || {(_capture select 6) isNotEqualTo ((_original select 2) select 2)}
        || {!((_capture select 10) in ["ENTRY","SWEEP","REPLAN","EGRESS"])}
        || {!(_retiredAt isEqualType 0)} || {!finite _retiredAt}
        || {_retiredAt < (_capture select 5)} || {_retiredAt > (_capture select 5)+3} || {_retiredAt > serverTime+1}
        || {!(_writerCount isEqualType 0)} || {!finite _writerCount}
        || {_writerCount < 1} || {_writerCount > 131} || {_writerCount != floor _writerCount}) exitWith {false};
    private _actors=_capture select 16;
    if (!(_actors isEqualType []) || {count _actors != 8}
        || {(_actors param [0,-1]) != 7} || {(_actors param [1,[]]) isNotEqualTo (_original select 2)}
        || {(_actors param [3,[]]) isNotEqualTo _original}) exitWith {false};
    private _recoveryState=_actors select 7;
    if (!(_recoveryState isEqualType []) || {count _recoveryState != 6}
        || {(_recoveryState param [0,-1]) isNotEqualTo 2}) exitWith {false};
    private _commonProgress=_recoveryState select 5;
    if (!(_commonProgress isEqualType []) || {count _commonProgress != 13}
        || {(_commonProgress param [0,-1]) isNotEqualTo 1}) exitWith {false};
    private _ownership=_actors select 6;
    if (!(_ownership isEqualType []) || {count _ownership != 7}
        || {(_ownership param [0,-1]) isNotEqualTo 1}) exitWith {false};
    private _policy=_actors select 5;
    if (!(_policy isEqualType []) || {count _policy != 6}
        || {[0,1,2,3,4,5] findIf {isNil {_policy select _x}} >= 0}
        || {(_policy select 0) isNotEqualTo 1}
        || {!((_policy select 1) in ["SAFE","AWARE","COMBAT","STEALTH","CARELESS"])}
        || {!((_policy select 2) isEqualType true)} || {!((_policy select 3) isEqualType true)}
        || {(_policy select 4) isNotEqualTo [_policy select 2,false]}
        || {!((_policy select 5) isEqualType [])} || {!(count (_policy select 5) in [2,3])}) exitWith {false};
    private _visit=_original select 2;
    private _building=_visit select 0;
    if (isNull _building || {!alive _building}
        || {(_visit select 1) isNotEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}) exitWith {false};
    private _until=_capture select 6;
    if ((_capture select 10) == "EGRESS") then {
        private _egress=_capture select 11;
        if (!(_egress isEqualType []) || {count _egress != 14}
            || {(_egress param [0,""]) != "EGRESS"} || {(_egress param [13,[]]) isNotEqualTo _visit}) exitWith {_until=-1};
        _until=_egress param [7,-1,[0]];
    };
    if (!(_until isEqualType 0) || {!finite _until} || {serverTime >= _until}) exitWith {false};
    // Typed bounded data only: no CODE, namespaces, HashMaps or script handles in transport.
    private _stack=[[_capture,0]];private _nodes=0;private _valid=true;
    while {_stack isNotEqualTo [] && {_valid} && {_nodes < 65536}} do {
        private _node=_stack deleteAt (count _stack-1);_node params ["_value","_depth"];
        _nodes=_nodes+1;
        if (_value isEqualType []) then {
            if (_depth >= 16 || {count _value > 4096}) exitWith {_valid=false};
            {if (isNil "_x") exitWith {_valid=false};_stack pushBack [_x,_depth+1]} forEach _value;
        } else {
            if (_value isEqualType 0) then {if (!finite _value) then {_valid=false}} else {
                if (_value isEqualType "") then {if (count _value > 512) then {_valid=false}} else {
                    if (!(_value isEqualType true || {_value isEqualType objNull} || {_value isEqualType grpNull})) then {_valid=false};
                };
            };
        };
    };
    if (!_valid || {_stack isNotEqualTo []}) exitWith {false};
    private _captures=missionNamespace getVariable ["CBE_ClearProducer_Candidates",createHashMap];
    {private _row=_captures get _x;if (serverTime >= (_row select 4) || {isNull ((_row select 0) select 0)}) then {_captures deleteAt _x}} forEach keys _captures;
    private _existing=_captures getOrDefault [_key,[]];
    private _candidate=[+_original,_capture,_retiredAt,_writerCount,((_capture select 5)+5) min _until,"CANDIDATE_UNSEALED",_incomingOwner];
    if (_existing isNotEqualTo []) exitWith {_existing isEqualTo _candidate};
    if (count _captures >= 512) exitWith {false};
    _captures set [_key,_candidate];
    missionNamespace setVariable ["CBE_ClearProducer_Candidates",_captures];
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
    if (isNull (_entry select 0)) then {_registry deleteAt _x};
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
    private _captures=missionNamespace getVariable ["CBE_ClearProducer_Candidates",createHashMap];
    _captures deleteAt _key;
    missionNamespace setVariable ["CBE_ClearProducer_Candidates",_captures];
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
