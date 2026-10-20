/*
 * Author: WaldoTheWarfighter
 * Purpose: Preserve and finitely retry ordinary hold recall while actor locality catches up.
 * Locality/authority: Actual group owner; native follow also requires actual actor ownership.
 * Repeat/JIP: Public journal keeps its original 30-second deadline through owner transfer.
 * At most 64 rows, one coalesced one-second callback chain per owner/epoch, at most 30 retries.
 * Route/generation replacement cancels recall; expiry retains unresolved rows without replay.
 * Arguments: 0 group <GROUP>, grpNull; 1 offered original hold rows <ARRAY>, [];
 * 2 existing journal key <ARRAY>, []; 3 callback attempt <NUMBER>, 0;
 * 4 issuing callback owner epoch <NUMBER>, -1 (internal callbacks only).
 * Return: BOOL - all journalled follow commands issued; never proof of physical reunion.
 * Current callers: CortexRestoreCalm, CortexLocality and this finite callback.
 * Example: [_group,_pendingOriginalRows] call CBE_fnc_CortexHolderRecallPending;
 */
params [["_group",grpNull,[grpNull]],["_offered",[],[[]]],["_key",[],[[]]],["_attempt",0,[0]],["_callbackEpoch",-1,[0]]];
if (isNull _group || {!local _group} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
if (!finite _attempt || {_attempt < 0} || {_attempt != floor _attempt} || {_attempt > 30}) exitWith {false};
private _generation=_group getVariable ["CBE_OperationGeneration",0];
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
if (_attempt > 0 && {_callbackEpoch != _epoch}) exitWith {false};
private _record=_group getVariable ["CBE_Cortex_HolderRecallPending",[]];
if !(_record isEqualType []) exitWith {false};
if (_record isNotEqualTo [] && {count _record != 5
    || {!((_record select 0) isEqualType "")} || {!((_record select 1) isEqualType 0)}
    || {!finite (_record select 1)} || {!((_record select 2) isEqualType 0)}
    || {!((_record select 3) isEqualType [])} || {count (_record select 3) > 64}
    || {(_record select 3) findIf {
        !(_x isEqualType []) || {count _x != 8} || {!((_x select 0) isEqualType objNull)}
        || {(_x select 1) isNotEqualTo _group}
    } >= 0}}) exitWith {false};
// Admission never rebases an old receipt onto the route left by cleanup.
if (_offered isNotEqualTo [] && {_key isEqualTo []}) then {
    private _order=[_group] call CBE_fnc_NativeOrderReceipt;
    private _rows=(_offered select [0,64]) select {
        _x isEqualType [] && {count _x == 8} && {(_x select 0) isEqualType objNull}
        && {!isNull (_x select 0)} && {group (_x select 0) == _group}
        && {(_x select 1) isEqualTo _group} && {(_x select 7) isEqualTo _order}
        && {((_x select 0) getVariable ["CBE_Cortex_HolderToken",[]]) isEqualTo (_x select [1,5])}
    };
    if (_rows isNotEqualTo []) then {
        private _existing=count _record == 5 && {(_record select 4) == "PENDING"}
            && {(_record select 2) == _generation};
        if (_existing) then {
            private _pending=+(_record select 3);
            {if (count _pending < 64) then {_pending pushBackUnique _x}} forEach _rows;
            _record set [3,_pending];
        } else {
            private _serial=1+(_group getVariable ["CBE_Cortex_HolderRecallSerial",0]);
            _group setVariable ["CBE_Cortex_HolderRecallSerial",_serial,true];
            _record=[format ["%1:%2:%3",clientOwner,_epoch,_serial],serverTime+30,_generation,_rows,"PENDING"];
        };
        _group setVariable ["CBE_Cortex_HolderRecallPending",_record,true];
    };
};
if (count _record != 5 || {(_record select 4) != "PENDING"}) exitWith {false};
if (!((_record select 0) isEqualType "") || {!((_record select 2) isEqualType 0)}
    || {!((_record select 3) isEqualType [])} || {count (_record select 3) > 64}
    || {(_record select 3) findIf {
        !(_x isEqualType []) || {count _x != 8} || {!((_x select 0) isEqualType objNull)}
        || {(_x select 1) isNotEqualTo _group}
    } >= 0}) exitWith {false};
private _identity=_record select [0,3];
if (_key isNotEqualTo [] && {_key isNotEqualTo _identity}) exitWith {false};
private _until=_record select 1;
if (!(_until isEqualType 0) || {!finite _until} || {!((_record select 3) isEqualType [])}
    || {count (_record select 3) > 64}) exitWith {false};
private _work=[_identity,clientOwner,_epoch];
private _status="PENDING";
if (serverTime >= _until || {_attempt >= 30}) then {_status="UNRESOLVED_DEADLINE"};
if ((_record select 2) != _generation || {[_group] call CBE_fnc_CortexExternalTakeover}
    || {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isNotEqualTo []}) then {_status="SUPERSEDED"};
if (_status != "PENDING") exitWith {
    _record set [4,_status];
    _group setVariable ["CBE_Cortex_HolderRecallPending",_record,true];
    _group setVariable ["CBE_Cortex_HolderRecallWork",nil];
    false
};
if (_attempt == 0 && {(_group getVariable ["CBE_Cortex_HolderRecallWork",[]]) isEqualTo _work}) exitWith {false};
if (_attempt > 0 && {(_group getVariable ["CBE_Cortex_HolderRecallWork",[]]) isNotEqualTo _work}) exitWith {false};
_group setVariable ["CBE_Cortex_HolderRecallWork",_work];
private _pending=+(_record select 3);
isNil {
    if (!local _group || {(_group getVariable ["CBE_AIPass_Epoch",0]) != _epoch}
        || {(_group getVariable ["CBE_OperationGeneration",0]) != _generation}
        || {(_group getVariable ["CBE_Cortex_HolderRecallPending",[]]) isNotEqualTo _record}
        || {serverTime >= _until}) exitWith {};
    private _leader=[_group] call CBE_fnc_CortexGroupAnchor;
    if (isNull _leader || {!local _leader} || {!([_leader] call CBE_fnc_CortexCombatEffective)}
        || {!isNull objectParent _leader}) exitWith {};
    private _state=createHashMapFromArray [["holderRecallReceipts",_pending]];
    private _issued=[];
    {
        private _actor=_x select 0;
        if ([_group,_state,_actor] call CBE_fnc_CortexHolderRecallOwned) then {
            _actor doFollow _leader;
            _actor setVariable ["CBE_Cortex_HolderToken",nil,true];
            _issued pushBack _x;
        };
    } forEach _pending;
    _pending=_pending-_issued;
    _record set [3,_pending];
    if (_pending isEqualTo []) then {_record set [4,"FOLLOW_ISSUED"]};
    _group setVariable ["CBE_Cortex_HolderRecallPending",_record,true];
};
if (_pending isEqualTo []) exitWith {_group setVariable ["CBE_Cortex_HolderRecallWork",nil]; true};
if (!local _group || {(_group getVariable ["CBE_AIPass_Epoch",0]) != _epoch}) exitWith {false};
[{_this call CBE_fnc_CortexHolderRecallPending},[_group,[],_identity,_attempt+1,_epoch],1] call CBA_fnc_waitAndExecute;
false
