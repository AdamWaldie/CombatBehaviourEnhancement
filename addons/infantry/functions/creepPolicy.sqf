/*
 * Author: WaldoTheWarfighter
 * Purpose: Own Creep's temporary group fire discipline and limited pace under one operation.
 * Native behaviour, formation, skills and individual forced-speed/stance policies are unchanged.
 * Locality/authority: Current group owner, exact marked PATROL operation/generation/epoch.
 * All property writes are synchronous in one unscheduled boundary; no timer retains a writer.
 * HANDOVER stages retirement before the receiver increments its epoch; it never resumes Creep.
 * RETIRE uses that receiver/next-epoch proof after adoption, including split actor locality.
 * Repeat/JIP: First baselines and expiry never renew. One release request per changed property;
 * readback, not timeout, proves release. At most30s cleanup inside original expiry+30; afterwards
 * unresolved proof is observation-only and blocks reacquisition. No worker or task replay.
 * Arguments: 0 mode STRING APPLY/CHECK/RELEASE/HANDOVER/RETIRE default CHECK;
 * 1 group GROUP,grpNull; 2 exact operation HASHMAP,empty; 3 original server deadline NUMBER,-1.
 * Return: STRING ACQUIRED/OWNED/RELEASED/PENDING/CHANGED/REFUSED/NONE.
 * Current callers: OperationRestore, CortexLocality and CortexDiscover; Creep executor pending.
 * Example: ["APPLY",_group,_operation,serverTime+180] call CBE_fnc_CreepPolicy;
 */
params [["_mode","CHECK",[""]],["_group",grpNull,[grpNull]],
    ["_operation",createHashMap,[createHashMap]],["_until",-1,[0]]];
if (isNull _group || {!local _group} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}
    || {!(_mode in ["APPLY","CHECK","RELEASE","HANDOVER","RETIRE"])}) exitWith {"REFUSED"};
private _result="REFUSED";
isNil {
_result=call {
    private _receipt=_group getVariable ["CBE_CreepPolicy",createHashMap];
    if (!(_receipt isEqualType createHashMap)) exitWith {"REFUSED"};
    if (_mode != "APPLY" && {count _receipt == 0}) exitWith {"NONE"};
    private _current=_group getVariable ["CBE_Operation",createHashMap];
    private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
    private _members=units _group;
    private _groupSafe={
        count _members > 0 && {count _members <= 64}
            && {!([_group] call CBE_fnc_CortexExternalTakeover)}
            && {_members findIf {alive _x && {!local _x || {isPlayer _x}
                || {!isNull objectParent _x} || {!simulationEnabled _x} || {isObjectHidden _x}
                || {!([_x] call CBE_fnc_CortexCombatEffective)}
                || {!isNull remoteControlled _x}
                || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                || {([_x] call CBE_fnc_CortexExternalOwner) != ""}
                || {[_x] call CBE_fnc_CompatibilityExternalControl}
                || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}}} < 0}
    };
    private _read={params ["_key"];if (_key == "COMBAT") then {combatMode _group} else {speedMode _group}};
    private _write={params ["_key","_value"];if (!local _group) exitWith {};if (_key == "COMBAT") then {_group setCombatMode _value} else {_group setSpeedMode _value}};
    private _operationGeneration=_operation getOrDefault ["generation",-1];
    private _sameOperation=_current isEqualTo _operation && {count _operation > 0}
        && {_operationGeneration isEqualType 0} && {finite _operationGeneration}
        && {_operationGeneration >= 0} && {_operationGeneration == floor _operationGeneration}
        && {_epoch isEqualType 0} && {finite _epoch} && {_epoch >= 0} && {_epoch == floor _epoch}
        && {_operationGeneration == (_group getVariable ["CBE_OperationGeneration",-2])};
    if (_mode == "APPLY" && {count _receipt == 0}) exitWith {
        if (!_sameOperation || {(_operation getOrDefault ["intent",""]) != "PATROL"}
            || {!(_operation getOrDefault ["creep",false])}
            || {(_operation getOrDefault ["ownerEpoch",-2]) != _epoch}
            || {(_operation getOrDefault ["phase",""]) in ["CANCELLED","COMPLETE"]}
            || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
            || {!finite _until} || {_until <= serverTime} || {_until > serverTime+300}
            || {!(call _groupSafe)}) exitWith {"REFUSED"};
        private _combat=combatMode _group;private _speed=speedMode _group;
        if (!(_combat in ["BLUE","GREEN","WHITE","YELLOW","RED"])
            || {!(_speed in ["LIMITED","NORMAL","FULL"])}
            || {_members findIf {alive _x && {unitCombatMode _x != _combat}} >= 0}) exitWith {"REFUSED"};
        // BLUE remains stricter than Creep's self-defence-only GREEN. No authored individual
        // override is widened, and limited group pace never overwrites forceSpeed.
        private _appliedCombat=if (_combat == "BLUE") then {"BLUE"} else {"GREEN"};
        private _rows=[["COMBAT",_combat,_appliedCombat,"NEW",false],["SPEED",_speed,"LIMITED","NEW",false]];
        _receipt=createHashMapFromArray [["owner",clientOwner],["epoch",_epoch],
            ["generation",_operation get "generation"],["started",serverTime],["until",_until],
            ["phase","APPLYING"],["rows",_rows]];
        _group setVariable ["CBE_CreepPolicy",_receipt,true];
        {
            _x params ["_key","_base","_applied"];
            if (_base == _applied) then {_x set [3,"NOOP"]} else {
                _x set [3,"REQUESTED"];
                [_key,_applied] call _write;
                if (([_key] call _read) == _applied && {_key != "COMBAT"
                    || {_members findIf {alive _x && {unitCombatMode _x != _applied}} < 0}}) then {_x set [3,"ACKED"]};
            };
        } forEach _rows;
        private _confirmed=_rows findIf {!((_x select 3) in ["ACKED","NOOP"])} < 0;
        if (_confirmed) then {_receipt set ["phase","LIVE"]};
        _group setVariable ["CBE_CreepPolicy",_receipt,true];
        ["PENDING","ACQUIRED"] select _confirmed
    };
    if (count _receipt == 0) exitWith {"NONE"};
    private _owner=_receipt getOrDefault ["owner",-1];
    private _oldEpoch=_receipt getOrDefault ["epoch",-1];
    private _generation=_receipt getOrDefault ["generation",-1];
    private _started=_receipt getOrDefault ["started",-1];
    private _deadline=_receipt getOrDefault ["until",-1];
    private _rows=_receipt getOrDefault ["rows",[]];
    if ([_owner,_oldEpoch,_generation,_started,_deadline] findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} >= 0
        || {_owner < 2} || {_owner != floor _owner} || {_oldEpoch != floor _oldEpoch}
        || {_generation != floor _generation} || {_deadline <= _started} || {_deadline > _started+300}
        || {!(_rows isEqualType [])} || {count _rows > 2}
        || {_rows findIf {!(_x isEqualType []) || {count _x != 5}
            || {!((_x select 0) in ["COMBAT","SPEED"])}
            || {!((_x select 1) isEqualType "")} || {!((_x select 2) isEqualType "")}
            || {if ((_x select 0) == "COMBAT") then {
                !((_x select 1) in ["BLUE","GREEN","WHITE","YELLOW","RED"])
                    || {!((_x select 2) in ["BLUE","GREEN"])}
            } else {!((_x select 1) in ["LIMITED","NORMAL","FULL"]) || {(_x select 2) != "LIMITED"}}}
            || {!((_x select 3) in ["NEW","NOOP","REQUESTED","ACKED"])}
            || {!((_x select 4) isEqualType true)}} >= 0}
        || {count ((_rows apply {_x select 0}) arrayIntersect (_rows apply {_x select 0})) != count _rows}) exitWith {"REFUSED"};
    private _phase=_receipt getOrDefault ["phase",""];
    private _identityMatches=_sameOperation && {(_operation getOrDefault ["generation",-2]) == _generation}
        && {(_operation getOrDefault ["ownerEpoch",-2]) == _oldEpoch};
    if (_mode in ["APPLY","CHECK"]) exitWith {
        if (!_identityMatches || {_owner != clientOwner} || {_oldEpoch != _epoch}
            || {_phase != "LIVE"} || {serverTime >= _deadline}
            || {(_current getOrDefault ["phase",""]) in ["CANCELLED","COMPLETE"]}
            || {!(call _groupSafe)}) exitWith {"REFUSED"};
        if (_rows findIf {private _row=_x;
            ([_row select 0] call _read) != (_row select 2)
                || {(_row select 0) == "COMBAT" && {_members findIf {alive _x && {unitCombatMode _x != (_row select 2)}} >= 0}}
        } >= 0) exitWith {"CHANGED"};
        "OWNED"
    };
    if (_mode == "RELEASE" && {!_identityMatches || {_owner != clientOwner} || {_oldEpoch != _epoch}}) exitWith {"REFUSED"};
    if (_mode == "HANDOVER") exitWith {
        if (!(_phase in ["APPLYING","LIVE","RETIRING","UNRESOLVED"])) exitWith {"REFUSED"};
        private _handoverOwned=_identityMatches && {_oldEpoch == _epoch};
        private _successorPresent=count _current > 0 && {(_current getOrDefault ["generation",-2]) != _generation};
        if (_phase in ["APPLYING","LIVE"]) then {
            _receipt set ["phase",["UNRESOLVED","RETIRING"] select _handoverOwned];
            _receipt set ["retireUntil",(serverTime+30) min (_deadline+30)];
        };
        if (_successorPresent) then {_receipt set ["phase","UNRESOLVED"]};
        // A second ownership edge may carry an existing retirement, never renew it.
        _receipt set ["retireOwner",clientOwner];_receipt set ["retireEpoch",_epoch+1];
        _group setVariable ["CBE_CreepPolicy",_receipt,true];
        "PENDING"
    };
    if (_mode == "RELEASE") then {
        if (_phase in ["APPLYING","LIVE"]) then {
            _receipt set ["phase","RETIRING"];
            _receipt set ["retireOwner",clientOwner];
            _receipt set ["retireEpoch",_epoch];
            _receipt set ["retireUntil",(serverTime+30) min (_deadline+30)];
            _group setVariable ["CBE_CreepPolicy",_receipt,true];
            _phase="RETIRING";
        };
    };
    if (!(_phase in ["RETIRING","UNRESOLVED"])
        || {(_receipt getOrDefault ["retireOwner",-1]) != clientOwner}
        || {(_receipt getOrDefault ["retireEpoch",-1]) != _epoch}) exitWith {"REFUSED"};
    private _retireUntil=_receipt getOrDefault ["retireUntil",-1];
    if (!(_retireUntil isEqualType 0) || {!finite _retireUntil} || {_retireUntil > _deadline+30}) exitWith {"REFUSED"};
    // A successor can never inherit an old policy write. Observe only until its native
    // values supersede the old claims. Source policy writers have no delayed callbacks.
    private _successor=count _current > 0 && {(_current getOrDefault ["generation",-2]) != _generation};
    private _mayRestore=_phase == "RETIRING" && {serverTime < _retireUntil}
        && {!_successor} && {call _groupSafe};
    if (count _members > 64 || {_members findIf {alive _x && {!local _x}} >= 0}) exitWith {"PENDING"};
    private _remaining=[];
    {
        private _row=_x;
        _row params ["_key","_base","_applied","_ack","_attempted"];
        private _value=[_key] call _read;
        private _observed=_value == _applied && {_key != "COMBAT"
            || {_members findIf {alive _x && {unitCombatMode _x != _applied}} < 0}};
        private _baseObserved=_value == _base && {_key != "COMBAT"
            || {_members findIf {alive _x && {unitCombatMode _x != _base}} < 0}};
        // A requested but unacknowledged apply cannot be called released merely because
        // its baseline is still visible. Keep that uncertainty without another apply.
        private _done=_ack == "NOOP" || {_ack == "NEW"}
            || {_ack == "ACKED" && {_baseObserved || {_value != _applied && {_value != _base}}}}
            || {_ack == "REQUESTED" && {_value != _base && {_value != _applied}}};
        if (!_done && {_observed}) then {
            _row set [3,"ACKED"];
            private _individualROECurrent=_key != "COMBAT"
                || {_members findIf {alive _x && {unitCombatMode _x != _applied}} < 0};
            if (_mayRestore && {!_attempted} && {_individualROECurrent}) then {
                _row set [4,true];
                [_key,_base] call _write;
                _done=([_key] call _read) == _base && {_key != "COMBAT"
                    || {_members findIf {alive _x && {unitCombatMode _x != _base}} < 0}};
            };
        };
        if (!_done) then {_remaining pushBack _row};
    } forEach _rows;
    _receipt set ["rows",_remaining];
    if (_remaining isEqualTo []) exitWith {
        _group setVariable ["CBE_CreepPolicy",nil,true];
        _group setVariable ["CBE_CreepPolicyResult",[[_owner,_oldEpoch,_generation],"RELEASED_OR_SUPERSEDED",serverTime],true];
        "RELEASED"
    };
    if (serverTime >= _retireUntil) then {_receipt set ["phase","UNRESOLVED"]};
    _group setVariable ["CBE_CreepPolicy",_receipt,true];
    "PENDING"
};
};
_result
