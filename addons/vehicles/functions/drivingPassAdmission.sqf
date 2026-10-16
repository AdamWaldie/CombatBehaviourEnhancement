/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe sustained ordinary-road obstruction and prepare an opt-in automatic pass.
 * Locality/authority: Internal current driving owner only. OBSERVE reads the existing traffic
 * sample; STEP runs finite geometry/consent work on the shared scheduler. No movement or speed
 * writes: successful preparation enters DrivingPassBegin and the existing operation FSM.
 * Repeat/JIP: One two-second preparation per owner, eight-second observation and 60-second
 * context cooldown. Original deadlines never renew; owner/route/crew changes cancel. Private
 * jobs never migrate or replay. Late replies require the still-current request serial/context.
 * Arguments: 0 mode <STRING>, OBSERVE/STEP/CANCEL; 1 group <GROUP>, grpNull;
 * 2 vehicle <OBJECT>, objNull; 3 driving brain <HASHMAP>, empty;
 * 4 traffic observation <ARRAY>, []; 5 proposed m/s <NUMBER>, 0;
 * 6 preparation job <HASHMAP>, empty, internal STEP only.
 * Return: BOOL for OBSERVE/CANCEL; NUMBER next shared-scheduler delay or -1 for STEP.
 * Bounds: one 12-station geometry slice (<=243 rays) or traffic query per 0.1-second job step,
 * <=2 seconds total. No added world discovery, permanent scheduler or collision exemption.
 * Current callers: DrivingAssistStart, DrivingAssistRelease and this finite scheduled job.
 * Example: ["OBSERVE",_group,_vehicle,_brain,_traffic,15] call WAIT_fnc_DrivingPassAdmission;
 */
params [["_mode","OBSERVE",[""]],["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]],["_traffic",[],[[]]],["_speed",0,[0]],
    ["_job",createHashMap,[createHashMap]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {if (_mode == "STEP") then {-1} else {false}};
if (_mode == "STEP") then {
    _group=_job getOrDefault ["group",grpNull];_vehicle=_job getOrDefault ["vehicle",objNull];
    _brain=_job getOrDefault ["brain",createHashMap];
};
if (_mode != "STEP" && {isNull _vehicle}) exitWith {false};
private _finish={
    params ["_reason",["_started",false]];
    private _context=_job getOrDefault ["context",[]];
    _job set ["done",true];
    if (!isNull _vehicle && {(_vehicle getVariable ["WAIT_DrivingPass_Admission",createHashMap]) isEqualTo _job}) then {
        if (!_started) then {
            private _request=_vehicle getVariable ["WAIT_DrivingPass_Request",[]];
            private _requestOwned=count _request == 3 && {(_request select 0) isEqualTo _context}
                && {(_request select 2) == (_job getOrDefault ["serial",-1])};
            if (_requestOwned) then {
                private _consent=_vehicle getVariable ["WAIT_DrivingPass_Consent",[]];
                if (count _consent == 5 && {(_consent select 1) isEqualTo _context}) then {
                    [_vehicle,_group,_consent select 0] call WAIT_fnc_DrivingPassAgreementRelease;
                };
                if ((_vehicle getVariable ["WAIT_DrivingPass_Request",[]]) isEqualTo _request) then {
                    _vehicle setVariable ["WAIT_DrivingPass_Request",nil];
                };
            };
        };
        _vehicle setVariable ["WAIT_DrivingPass_Admission",nil];
        _vehicle setVariable ["WAIT_DrivingPass_AutoCooldown",[_context,serverTime+60]];
        _vehicle setVariable ["WAIT_DrivingPass_AdmissionResult",[_reason,serverTime]];
    };
    if ((missionNamespace getVariable ["WAIT_DrivingPass_Preparing",createHashMap]) isEqualTo _job) then {
        missionNamespace setVariable ["WAIT_DrivingPass_Preparing",nil];
    };
    -1
};
if (_mode == "CANCEL") exitWith {
    _job=_vehicle getVariable ["WAIT_DrivingPass_Admission",createHashMap];
    if (count _job > 0 && {!isNull _group} && {(_job get "group") != _group}) exitWith {false};
    if (count _job > 0) then {["CANCELLED"] call _finish};
    private _seen=_vehicle getVariable ["WAIT_DrivingPass_AutoSeen",[]];
    if (count _seen == 3 && {isNull _group || {((_seen select 0) select 0) == _group}}) then {
        _vehicle setVariable ["WAIT_DrivingPass_AutoSeen",nil];
    };
    private _cruise=_vehicle getVariable ["WAIT_DrivingPass_AutoCruise",[]];
    if (count _cruise == 3 && {isNull _group || {((_cruise select 0) select 0) == _group}}) then {
        _vehicle setVariable ["WAIT_DrivingPass_AutoCruise",nil];
    };true
};
if !(_mode in ["OBSERVE","STEP"]) exitWith {false};
private _enabled=[_group,"WAIT_AIPass_DrivingAssist_Passing_Enable",false] call WAIT_fnc_CortexFeatureEnabled;
if (_mode == "OBSERVE" && {!_enabled} && {isNil {_vehicle getVariable "WAIT_DrivingPass_Admission"}}
    && {isNil {_vehicle getVariable "WAIT_DrivingPass_AutoSeen"}}) exitWith {false};
private _current=_enabled && {!isNull _group} && {local _group} && {!isNull _vehicle} && {local _vehicle}
    && {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isEqualTo _brain}
    && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {vehicle leader _group == _vehicle} && {!(behaviour leader _group in ["COMBAT","STEALTH"])}
    && {[_vehicle] call WAIT_fnc_DrivingPassCanConsent};
if (_mode == "STEP") exitWith {
    if (!_current || {_job getOrDefault ["done",false]}
        || {(_vehicle getVariable ["WAIT_DrivingPass_Admission",createHashMap]) isNotEqualTo _job}
        || {(missionNamespace getVariable ["WAIT_DrivingPass_Preparing",createHashMap]) isNotEqualTo _job}
        || {(_brain getOrDefault ["generation",-1]) != (_job get "generation")}
        || {serverTime >= (_job get "deadline")}) exitWith {["OWNER_ORDER_OR_DEADLINE"] call _finish};
    private _request=_vehicle getVariable ["WAIT_DrivingPass_Request",[]];
    if (_job getOrDefault ["requested",false] && {count _request != 3
        || {(_request select 0) isNotEqualTo (_job get "context")}
        || {(_request select 2) != (_job get "serial")}}) exitWith {["REQUEST_REPLACED"] call _finish};
    private _proposal=_job get "proposal";
    private _prepared=[_proposal,_job get "prepared"] call WAIT_fnc_DrivingPassPrepare;
    _job set ["prepared",_prepared];
    private _phase=_prepared getOrDefault ["phase","REFUSED"];
    if (_phase in ["REFUSED","EXPIRED"]) exitWith {[_prepared getOrDefault ["reason",_phase]] call _finish};
    if (_phase == "READY_PROPOSAL") then {
        if !(_job getOrDefault ["requested",false]) then {
            if ([_proposal,_prepared] call WAIT_fnc_DrivingPassAgreementRequest) then {
                _job set ["requested",true];
                _job set ["serial",(_vehicle getVariable ["WAIT_DrivingPass_Request",[]]) param [2,-1]];
            };
        } else {
            private _agreement=_vehicle getVariable ["WAIT_DrivingPass_Agreement",[]];
            if (count _agreement == 5 && {(_agreement select 2) isEqualTo (_job get "context")}
                && {(_agreement select 4) == "AGREED"}) then {
                private _started=[_proposal,_prepared] call WAIT_fnc_DrivingPassBegin;
                [["BEGIN_REFUSED","ADMITTED"] select _started,_started] call _finish;
            };
        };
    };
    if (_job getOrDefault ["done",false]) then {-1} else {0.1}
};
private _old=_vehicle getVariable ["WAIT_DrivingPass_Admission",createHashMap];
if (count _old > 0 && {!(_old getOrDefault ["done",false])} && {serverTime < (_old get "deadline")}) exitWith {true};
if (count _old > 0) then {_job=_old;["EXPIRED"] call _finish};
private _peer=_traffic param [1,objNull,[objNull]];
private _cruiseIdentity=[_group,_brain getOrDefault ["ownerEpoch",-1],_brain getOrDefault ["generation",-1],
    speedMode _group,[_group] call WAIT_fnc_DrivingRouteReceipt];
private _cruise=_vehicle getVariable ["WAIT_DrivingPass_AutoCruise",[]];
private _cruiseValid=count _cruise == 3 && {(_cruise select 0) isEqualTo _cruiseIdentity}
    && {serverTime >= (_cruise select 2)} && {serverTime-(_cruise select 2) <= 30};
if (_current && {isNull _peer} && {speed _vehicle > 2}) then {
    private _seenSpeed=(speed _vehicle)/3.6;
    _cruise=[_cruiseIdentity,_seenSpeed,serverTime];_cruiseValid=true;
    _vehicle setVariable ["WAIT_DrivingPass_AutoCruise",_cruise];
};
private _seenCruise=if (_cruiseValid) then {_cruise select 1} else {0};
private _capability=((getNumber (configOf _vehicle >> "maxSpeed"))*0.65/3.6) max _seenCruise;
if (speedMode _group == "LIMITED") then {_capability=_seenCruise};
_speed=_speed min _capability min (((speed _peer) max 0)/3.6+30/3.6);
private _candidate=_current && {finite _speed} && {_speed >= 5/3.6} && {_speed <= 120/3.6}
    && {!isNull _peer} && {_peer != _vehicle} && {alive _peer} && {!isNull driver _peer}
    && {group driver _peer != _group}
    && {!(behaviour driver _peer in ["COMBAT","STEALTH"])}
    && {speed _peer > 2} && {speed _peer+10 < _speed*3.6}
    && {_vehicle distance2D _peer <= 60} && {!isNull roadAt _vehicle} && {!isNull roadAt _peer};
if (!_candidate) exitWith {_vehicle setVariable ["WAIT_DrivingPass_AutoSeen",nil];false};
private _context=[[_vehicle,_peer]] call WAIT_fnc_DrivingPassContext;
if (_context isEqualTo []) exitWith {false};
private _identity=[_group,_brain get "generation",_brain get "ownerEpoch",_context];
private _seen=_vehicle getVariable ["WAIT_DrivingPass_AutoSeen",[]];
private _continuous=count _seen == 3 && {(_seen select 0) isEqualTo _identity}
    && {serverTime >= (_seen select 2)} && {serverTime-(_seen select 2) <= 6};
private _since=if (_continuous) then {_seen select 1} else {serverTime};
_vehicle setVariable ["WAIT_DrivingPass_AutoSeen",[_identity,_since,serverTime]];
if (serverTime-_since < 8) exitWith {false};
private _cooldown=_vehicle getVariable ["WAIT_DrivingPass_AutoCooldown",[]];
if (count _cooldown == 2 && {(_cooldown select 0) isEqualTo _context} && {serverTime < (_cooldown select 1)}) exitWith {false};
private _slot=missionNamespace getVariable ["WAIT_DrivingPass_Preparing",createHashMap];
if (count _slot > 0 && {!(_slot getOrDefault ["done",false])} && {serverTime < (_slot get "deadline")}) exitWith {false};
private _proposal=[_vehicle,_peer,_speed*3.6] call WAIT_fnc_DrivingPassPlan;
if ((_proposal getOrDefault ["status",""]) != "PROPOSAL") exitWith {
    _vehicle setVariable ["WAIT_DrivingPass_AutoCooldown",[_context,serverTime+60]];false
};
_job=createHashMapFromArray [["group",_group],["vehicle",_vehicle],["brain",_brain],
    ["ownerEpoch",_brain get "ownerEpoch"],["generation",_brain get "generation"],
    ["context",_proposal get "context"],["proposal",_proposal],["prepared",createHashMap],
    ["deadline",(_proposal get "observedAt")+2],["done",false],["requested",false],["serial",-1]];
_vehicle setVariable ["WAIT_DrivingPass_Admission",_job];
missionNamespace setVariable ["WAIT_DrivingPass_Preparing",_job];
[{params ["_job"];["STEP",grpNull,objNull,createHashMap,[],0,_job] call WAIT_fnc_DrivingPassAdmission},
    _job,0,format ["WAIT_PASS_PREP_%1_%2",str _vehicle,_brain get "generation"]] call WAIT_fnc_CortexQueueJob;
true
