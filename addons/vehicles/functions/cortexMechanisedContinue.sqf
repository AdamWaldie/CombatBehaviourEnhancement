/*
 * Author: WaldoTheWarfighter
 * Purpose: Admit another support bound only after the exact previous native worker has finished.
 * Locality/authority: Read-only on the original local vehicle/crew owner. No movement or deadline change.
 * Repeat/JIP: At most three legs under one original source/contact/deadline; owner migration refuses replay.
 * Requires finite native return acknowledgement/observation, empty movement reference and completed FSM,
 * not merely a RETIRED marker. A different task, crew, source or native mission order refuses continuation.
 * Arguments: group GROUP grpNull; vehicle OBJECT objNull; proposed context ARRAY [] or context5.
 * Return: [original context,previous leg count] or[]. Current callers: CortexVehicles, MechanisedSupport, VehicleTacticalMoveStart.
 * Example: private _previous=[_group,_apc] call CBE_fnc_CortexMechanisedContinue;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],["_proposed",[],[[]]]];
if (isRemoteExecuted || {isNull _group} || {!local _group} || {isNull _vehicle} || {!local _vehicle}) exitWith {[]};
private _work=_vehicle getVariable ["CBE_VehicleTacticalMove_Work",createHashMap];
private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
private _context=_work getOrDefault ["supportContext",[]];
private _leg=_work getOrDefault ["supportLeg",1];
private _executor=_vehicle getVariable ["CBE_VehicleTacticalMove_FSM",[]];
if ((_work getOrDefault ["kind",""]) != "MECH_SUPPORT"
    || {(_work getOrDefault ["group",grpNull]) != _group}
    || {(_work getOrDefault ["owner",-1]) != clientOwner} || {(_work getOrDefault ["epoch",-2]) != _epoch}
    || {(_work getOrDefault ["phase",""]) != "RETIRED"}
    || {!((_work getOrDefault ["result",""]) in ["NATIVE_RETURN_ACKNOWLEDGED","NATIVE_RETURN_OBSERVED_AFTER_WORKER"])}
    || {_work getOrDefault ["retirementOnly",false]}
    || {(_work getOrDefault ["carriageSerial",-1]) != (_vehicle getVariable ["CBE_Cortex_MechBoardSerial",0])}
    || {!(_leg isEqualType 0)} || {!finite _leg} || {_leg < 1} || {_leg >= 3}
    || {count _context != 5} || {!((_context select 3) isEqualType 0)} || {!finite (_context select 3)}
    || {(_context select 3) < serverTime+5}
    || {!((_context select 2) isEqualType [])} || {count (_context select 2) != 3}
    || {(_context select 2) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []}
    || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_work getOrDefault ["route",[]])}
    || {(_work getOrDefault ["crew",[]]) isNotEqualTo [driver _vehicle,effectiveCommander _vehicle]}
    || {count _executor != 5} || {(_executor select 0) != (_work getOrDefault ["serial",-1])}
    || {(_executor select 2) != clientOwner} || {(_executor select 3) != _epoch}
    || {!((_executor select 1) isEqualType 0)} || {!finite (_executor select 1)}
    || {(_executor select 1) < 0} || {!completedFSM (_executor select 1)}) exitWith {[]};
// A fresh genuine own-group exit supersedes the consumed old incident.
private _live=_group getVariable ["CBE_Cortex_DismountContinuation",[]];
if ((_context select 4) isEqualTo [] && {_live isNotEqualTo []}
    && {_live isNotEqualTo (_context select 0)}) exitWith {[]};
if (_proposed isNotEqualTo [] && {count _proposed != 5
    || {[0,1,3,4] findIf {(_proposed select _x) isNotEqualTo (_context select _x)} >= 0}
    || {!((_proposed select 2) isEqualType [])} || {count (_proposed select 2) != 3}
    || {(_proposed select 2) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {(_proposed select 2) vectorDistance (_context select 2) < 15}}) exitWith {[]};
[+_context,_leg]
