/*
 * Author: WaldoTheWarfighter
 * Purpose: Retire the exact convoy native MOVE receipt before an owned driving phase issues STOP.
 * Locality/authority: Actual group, vehicle, driver and effective-commander owner only.
 * Metadata retirement grants no movement permission; callers retain their task/phase guards.
 * Repeat/JIP: One exact six-field or pending seven-field receipt is removed; no command, worker, deadline or replay.
 * Arguments: 0 group <GROUP>, grpNull; 1 vehicle <OBJECT>, objNull.
 * Return: BOOL - matching native MOVE metadata retired, not acknowledgement of STOP or release.
 * Current callers: ConvoyTick/CrewLocal/ReleaseLocal and driving corridor, bypass, pass and recovery stops.
 * Example: [_group,_vehicle] call CBE_fnc_ConvoyRetireMoveReceipt;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _group} || {!local _group}
    || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _retired=false;
isNil {
    private _receipt=_vehicle getVariable ["CBE_Convoy_MovementReceipt",[]];
    private _state=_group getVariable ["CBE_Convoy_LocalState",createHashMap];
    private _currentRevision=if (_state isEqualType createHashMap) then {_state getOrDefault ["revision",-1]} else {-1};
    // Reacquisition deliberately resets local state revision before its owned STOP. The
    // current admitted brain still carries the exact authoritative configuration revision.
    if (_currentRevision < 0) then {
        private _brain=_group getVariable ["CBE_Convoy_Brain",createHashMap];
        if (_brain isEqualType createHashMap && {!(_brain getOrDefault ["cancelled",false])}
            && {!(_brain getOrDefault ["finished",false])}) then {
            _currentRevision=(_brain getOrDefault ["configuration",[]]) param [0,-1,[0]];
        };
    };
    private _driver=driver _vehicle;
    private _operator=effectiveCommander _vehicle;
    if (isNull _operator) then {_operator=_driver};
    if (_receipt isEqualType [] && {count _receipt in [6,7]} && {(_receipt select 5) == "NATIVE"}
        && {(_receipt select 0) isEqualTo _group} && {_state isEqualType createHashMap}
        && {(_receipt select 1) == _currentRevision}
        && {(_receipt select 2) isEqualTo _driver} && {(_receipt select 3) isEqualTo _operator}
        && {!isNull _driver} && {!isNull _operator} && {local _driver} && {local _operator}
        && {group _driver == _group} && {group _operator == _group}
        && {(expectedDestination _operator) isEqualTo (_receipt select 4) || {
            private _request=_receipt param [6,[],[[]]];
            private _position=(expectedDestination _operator) param [0,[],[[]]];
            count _request == 3 && {(_request select 0) isEqualType []} && {count (_request select 0) == 3}
                && {(_request select 0) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {count _position == 3} && {currentCommand _operator in ["","MOVE"]}
                && {_position vectorDistance (_request select 0) <= 0.25}
        }}) then {
        _vehicle setVariable ["CBE_Convoy_MovementReceipt",nil,true];
        _retired=true;
    };
};
_retired
