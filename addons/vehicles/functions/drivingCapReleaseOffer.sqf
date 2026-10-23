/*
 * Author: WaldoTheWarfighter
 * Purpose: Offers a confirmed ordinary cap for cleanup when this machine actually loses vehicle locality.
 * Locality/authority: Internal native Local-loss callback only, never remote. Metadata publication
 * after loss grants no native command. Original issuer/seats were captured at confirmed cap application.
 * Repeat/JIP: Exact private loss edge and last confirmed receipts only. Existing pending deadline
 * is retained; a new release gets loss-edge time plus thirty seconds, never callback/retry time.
 * Publish the complete fact before retiring this machine's matching private cap/baseline/issuer.
 * Active passing may offer its exact original cleanup receipts/baseline at this loss edge,
 * never its executable path. All other child controllers retain their own handover paths; missing or incompatible proof stays unresolved.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 actual private loss edge <ARRAY, []> [epoch, server time].
 * Return: BOOL - complete metadata offered, not physical restoration or provider acknowledgement.
 * Current callers: DrivingRecoveryAdopt, actual native Local-loss branch only.
 * Example: [truck1,truck1 getVariable ["CBE_DrivingCap_LossEdge",[]]] call CBE_fnc_DrivingCapReleaseOffer;
 */
params [["_vehicle",objNull,[objNull]],["_lossEdge",[],[[]]]];
if (remoteExecutedOwner > 0 || {isNull _vehicle} || {local _vehicle}) exitWith {false};
private _offered=false;
isNil {
    if (count _lossEdge != 2 || {_lossEdge isNotEqualTo (_vehicle getVariable ["CBE_DrivingCap_LossEdge",[]])}
        || {_lossEdge findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} >= 0}
        || {serverTime < (_lossEdge select 1)} || {serverTime >= (_lossEdge select 1)+5}) exitWith {};
    private _source=_vehicle getVariable ["CBE_DrivingCap_Issuer",[]];
    private _state=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
    private _restore=_vehicle getVariable ["CBE_DrivingAssist_Restore",[]];
    if (!(_source isEqualType []) || {count _source != 3}
        || {!((_source select 0) isEqualType [])} || {count (_source select 0) != 3}
        || {(_source select 0) findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x != floor _x}} >= 0}
        || {((_source select 0) select 0) != clientOwner}
        || {!((_source select 1) isEqualType objNull)} || {!((_source select 2) isEqualType objNull)}
        || {!(_state isEqualType [])} || {!(count _state in [4,11,12])}
        || {!(_restore isEqualType [])} || {count _restore != 1}
        || {!((_state select 0) isEqualType 0)} || {!finite (_state select 0)} || {(_state select 0) < 0}
        || {!((_state select 3) isEqualType grpNull)} || {isNull (_state select 3)}
        || {!((_restore select 0) isEqualType 0)} || {!finite (_restore select 0)}
        || {(_restore select 0) < 0 && {(_restore select 0) != -1}}) exitWith {};
    private _retireSource={
        _vehicle setVariable ["CBE_DrivingAssist_State",nil];
        _vehicle setVariable ["CBE_DrivingAssist_Restore",nil];
        _vehicle setVariable ["CBE_DrivingCap_Issuer",nil];
        _vehicle setVariable ["CBE_DrivingAssist_Next",nil];
    };
    if (isNull (_source select 1) || {driver _vehicle != (_source select 1)}
        || {effectiveCommander _vehicle != (_source select 2)}
        || {group (_source select 1) != (_state select 3)}) exitWith {};
    private _pass=_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap];
    if (count _pass > 0) exitWith {
        private _leg=_vehicle getVariable ["CBE_DrivingPass_Leg",[]];
        private _tasks=if ((_pass getOrDefault ["handback",[]]) isNotEqualTo []) then {
            _pass getOrDefault ["handbackTasks",[]]
        } else {[_pass getOrDefault ["driverTask",""],_pass getOrDefault ["operatorTask",""]]};
        private _until=_pass getOrDefault ["deadline",-1];
        if (!(_leg isEqualType []) || {count _leg != 13} || {(_leg select [0,6]) isNotEqualTo
            ["PASS_LEG_V1",clientOwner,_state select 3,(_source select 0) select 1,(_source select 0) select 2,_pass getOrDefault ["token",""]]}
            || {!(_pass getOrDefault ["issued",false])}
            || {(_leg select [6,2]) isNotEqualTo [_source select 1,_source select 2]}
            || {(_pass getOrDefault ["epoch",-1]) != ((_source select 0) select 1)}
            || {(_pass getOrDefault ["generation",-1]) != ((_source select 0) select 2)}
            || {(_pass getOrDefault ["group",grpNull]) != (_state select 3)}
            || {(_pass getOrDefault ["driver",objNull]) != (_source select 1)}
            || {(_pass getOrDefault ["operator",objNull]) != (_source select 2)}
            || {(_pass getOrDefault ["route",[]]) isNotEqualTo (_leg select 10)}
            || {!(_until isEqualType 0)} || {!finite _until}
            || {_until != (_leg select 11)} || {count _tasks != 2}
            || {_tasks findIf {!(_x isEqualType "")} >= 0}
            || {_pass getOrDefault ["interrupted",false]}
            || {abs ((getForcedSpeed _vehicle)-(_state select 0)) > 0.1}
            || {["CBE_DrivingRecovery_Work","CBE_DrivingCorridor_Work","CBE_DrivingBypass_Work"]
                findIf {count (_vehicle getVariable [_x,createHashMap]) > 0} >= 0}
            || {count (_vehicle getVariable ["CBE_DrivingPass_Handover",createHashMap]) > 0}) exitWith {};
        // Last owner-local receipts only: no expectedDestination read after locality loss.
        _vehicle setVariable ["CBE_DrivingPass_Handover",createHashMapFromArray [
            ["leg",+_leg],["state",+_state],["baseline",+_restore],["issuer",+(_source select 0)],
            ["created",_lossEdge select 1],["deadline",_until],["started",_pass get "started"],
            ["driverCommand",+(_pass get "driverCommand")],["command",+(_pass get "command")],
            ["tasks",+_tasks],["handback",+(_pass getOrDefault ["handback",[]])]
        ],true];
        call _retireSource;_offered=true;
    };
    if (["CBE_DrivingRecovery_Work","CBE_DrivingCorridor_Work","CBE_DrivingBypass_Work"]
        findIf {count (_vehicle getVariable [_x,createHashMap]) > 0} >= 0) exitWith {};
    // A confirmed newer native value needs no old cap handback. Retire only this
    // source machine's stale private claim; never republish or delete a public successor.
    if (abs ((getForcedSpeed _vehicle)-(_state select 0)) > 0.1) exitWith {call _retireSource};
    private _created=false;
    private _fact=_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]];
    if (_fact isEqualTo []) then {
        _created=true;
        _fact=[+_state,+_restore,_state select 3,(_source select 0) select 1,
            (_lossEdge select 1)+30,_source select 1,_source select 2,+(_source select 0),+(_source select 0)];
    } else {
        if (!(_fact isEqualType []) || {count _fact != 9}
            || {(_fact select 0) isNotEqualTo _state} || {(_fact select 1) isNotEqualTo _restore}
            || {(_fact select 7) isNotEqualTo (_source select 0)
                && {(_fact select 8) isNotEqualTo (_source select 0)}}
            || {(_fact select 5) isNotEqualTo (_source select 1)}
            || {(_fact select 6) isNotEqualTo (_source select 2)}) exitWith {_fact=[]};
    };
    if (_fact isEqualTo []) exitWith {};
    // Do not replay an already published fact: its current custodian may have changed.
    if (_created) then {_vehicle setVariable ["CBE_DrivingCapRelease_Work",_fact,true]};
    call _retireSource;
    _offered=true;
};
_offered
