/*
 * Author: WaldoTheWarfighter
 * Purpose: Own temporary on-foot actor stance/speed settings independently of native movement tasks.
 * Locality/authority: Actual actor and group owner. APPLY/CHECK/ADOPT require the current common
 * operation generation/epoch and original finite deadline; RELEASE uses an exact issuer receipt.
 * Repeat/JIP: Original baselines never renew. ADOPT changes metadata only for the same issuer and
 * deadline. Changed native settings refuse application; release preserves edits. Partial native
 * restoration retains the remaining pairs and at most one release attempt/second, without renewing
 * the caller deadline or creating a worker. This does not prove initial network receipt readiness.
 * Arguments: 0 mode STRING APPLY (CHECK/ADOPT/RELEASE); 1 actor OBJECT objNull;
 * 2 context ARRAY [] = [group,issuer token,operation generation,owner epoch,server deadline];
 * 3 requested HASHMAP empty, supported keys STANCE (AUTO/UP/MIDDLE/DOWN), SPEED (-1 or >=0).
 * 4 authority scope STRING OPERATION; GARRISON requires its live explicit issuer/order/assignment
 * and uses deadline0 for post holding, independently of the finite approach deadline.
 * Return: STRING APPLIED/OWNED/ADOPTED/RELEASED/ABSENT/CHANGED/PENDING/REFUSED.
 * Native stance rule names are normalised before enum validation and exact receipt comparisons.
 * A settings acknowledgement never grants movement, target or physical-progress authority.
 * Acquisition/check/adoption yield to native flight and queued care; exact release stays task-independent.
 * Current callers: CortexClearSettingsApply, CortexClearSettingsRelease and CortexGarrisonSettings.
 * Example: ["APPLY",soldier1,[_group,"task-token",4,2,serverTime+30],createHashMapFromArray [["SPEED",4]]] call CBE_fnc_ActorSettings;
 */
params [["_mode","APPLY",[""]],["_actor",objNull,[objNull]],
    ["_context",[],[[]]],["_requested",createHashMap,[createHashMap]],["_scope","OPERATION",[""]]];
private _result="REFUSED";
isNil {
_result=call {
    if (!(_mode in ["APPLY","CHECK","ADOPT","RELEASE"]) || {isNull _actor} || {!local _actor}
        || {count _context != 5} || {count _requested > 2}) exitWith {"REFUSED"};
    private _contextValid={
        params ["_row"];
        _row isEqualType [] && {count _row == 5} && {(_row select 0) isEqualType grpNull}
            && {(_row select 1) isEqualType ""} && {count (_row select 1) > 0 && {count (_row select 1) <= 256}}
            && {[2,3,4] findIf {!((_row select _x) isEqualType 0) || {!finite (_row select _x)} || {(_row select _x) < 0}} < 0}
    };
    if !([_context] call _contextValid) exitWith {"REFUSED"};
    _context params ["_group","_issuer","_generation","_epoch","_deadline"];
    if (isNull _group || {!local _group} || {group _actor != _group}
        || {_epoch != (_group getVariable ["CBE_AIPass_Epoch",-1])}
        || {!(_actor isKindOf "CAManBase")} || {isPlayer _actor} || {!isNull objectParent _actor}
        || {!isNull remoteControlled _actor} || {!isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {!simulationEnabled _actor} || {isObjectHidden _actor}
        || {!([_actor] call CBE_fnc_CortexCombatEffective)}
        || {[_actor] call CBE_fnc_CortexActorMoveReserved} || {count units _group > 64}
        || {[_group,_mode == "RELEASE",_actor] call CBE_fnc_CortexExternalTakeover}) exitWith {"REFUSED"};
    private _valueValid={
        params ["_key","_value"];
        if (_key == "STANCE") exitWith {_value isEqualType "" && {_value in ["AUTO","UP","MIDDLE","DOWN"]}};
        _key == "SPEED" && {_value isEqualType 0} && {finite _value} && {_value == -1 || {_value >= 0}}
    };
    if (keys _requested findIf {!([_x,_requested get _x] call _valueValid)} >= 0) exitWith {"REFUSED"};
    private _read={params ["_key"];if (_key == "STANCE") then {toUpperANSI (unitPos _actor)} else {getForcedSpeed _actor}};
    private _same={params ["_key","_a","_b"];if (_key == "STANCE") then {_a isEqualTo _b} else {abs (_a-_b) <= 0.00001}};
    private _write={params ["_key","_value"];if (_key == "STANCE") then {_actor setUnitPos _value} else {_actor forceSpeed _value}};
    private _lease=_actor getVariable ["CBE_ActorSettings",[]];
    if !(_lease isEqualType [] && {count _lease in [0,3]}) exitWith {"REFUSED"};
    private _owned=createHashMap;
    private _oldContext=[];
    private _releaseAt=0;
    if (_lease isNotEqualTo []) then {
        _oldContext=_lease select 0;
        _owned=_lease select 1;
        _releaseAt=_lease select 2;
    };
    if (!(_releaseAt isEqualType 0) || {!finite _releaseAt} || {_releaseAt < 0}) exitWith {"REFUSED"};
    if (_lease isNotEqualTo [] && {
        !([_oldContext] call _contextValid) || {!(_owned isEqualType createHashMap)}
        || {count _owned < 1} || {count _owned > 2}
        || {keys _owned findIf {
            private _pair=_owned get _x;
            !(_x in ["STANCE","SPEED"]) || {!(_pair isEqualType [])} || {count _pair != 2}
                || {!([_x,_pair select 0] call _valueValid)} || {!([_x,_pair select 1] call _valueValid)}
        } >= 0}
    }) exitWith {"REFUSED"};
    if (_lease isNotEqualTo [] && {(_oldContext select 0) != _group || {(_oldContext select 1) != _issuer}
        || {(_oldContext select 4) != _deadline}}) exitWith {"REFUSED"};
    if (keys _owned findIf {!([_x,[_x] call _read] call _valueValid)} >= 0) exitWith {"REFUSED"};
    if (_mode == "RELEASE") exitWith {
        if (_lease isEqualTo []) exitWith {"ABSENT"};
        if ((_oldContext select 2) != _generation) exitWith {"REFUSED"};
        if (serverTime < _releaseAt) exitWith {"PENDING"};
        // A new actual owner may clean an inherited unchanged setting without replaying work.
        // The caller supplies the current epoch; the old receipt epoch grants no new application.
        private _remaining=createHashMap;
        {
            private _key=_x;
            private _pair=+(_owned get _key);
            private _native=[_key] call _read;
            if ([_key,_native,_pair select 1] call _same) then {
                if (_native isNotEqualTo (_pair select 0)) then {[_key,_pair select 0] call _write};
                if !([_key,[_key] call _read,_pair select 0] call _same) then {_remaining set [_key,_pair]};
            };
        } forEach keys _owned;
        if (count _remaining == 0) then {
            _actor setVariable ["CBE_ActorSettings",nil,true];"RELEASED"
        } else {
            private _next=[+_oldContext,_remaining,serverTime+1];
            if (_next isNotEqualTo _lease) then {_actor setVariable ["CBE_ActorSettings",_next,true]};
            "PENDING"
        }
    };
    // Native flight and pending treatment own new settings as well as movement.
    // Exact RELEASE above remains independent: removing our unchanged cap/stance
    // must not require cancelling or waiting for the native task.
    if (_releaseAt > 0 || {fleeing _actor}
        || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}) exitWith {"REFUSED"};
    private _taskOwned=false;
    if (_scope == "GARRISON") then {
        // Persistent explicit post holding is order-scoped, not an expired approach route.
        _taskOwned=_deadline == 0
            && {_issuer == (_group getVariable ["CBE_Cortex_GarrisonSettingIssuer",""])}
            && {_generation == (_group getVariable ["CBE_AIPass_GarrisonGeneration",-1])}
            && {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
            && {(_actor getVariable ["CBE_AIPass_GarrisonPos",[]]) isNotEqualTo []};
    } else {
        if (_scope == "OPERATION") then {
            private _operation=_group getVariable ["CBE_Operation",createHashMap];
            _taskOwned=(_operation getOrDefault ["generation",-1]) == _generation
                && {(_operation getOrDefault ["ownerEpoch",-1]) == _epoch}
                && {(_group getVariable ["CBE_OperationGeneration",-1]) == _generation}
                && {(_operation getOrDefault ["phase",""]) != "CANCELLED"}
                && {serverTime < _deadline};
        };
    };
    if (!_taskOwned) exitWith {"REFUSED"};
    if (currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]) exitWith {"REFUSED"};
    if (_lease isNotEqualTo [] && {keys _owned findIf {
        !([_x,[_x] call _read,(_owned get _x) select 1] call _same)
    } >= 0}) exitWith {"CHANGED"};
    if (_mode == "ADOPT") exitWith {
        if (_lease isEqualTo []) exitWith {"ABSENT"};
        private _next=[+_context,createHashMapFromArray (keys _owned apply {[_x,+(_owned get _x)]}),0];
        if (_next isNotEqualTo _lease) then {_actor setVariable ["CBE_ActorSettings",_next,true]};
        "ADOPTED"
    };
    if (_lease isNotEqualTo [] && {_oldContext isNotEqualTo _context}) exitWith {"REFUSED"};
    if (_mode == "CHECK") exitWith {
        if (_lease isEqualTo []) exitWith {"ABSENT"};
        if (keys _requested findIf {!(_x in _owned)} >= 0) then {"REFUSED"} else {"OWNED"}
    };
    if (count _requested < 1) exitWith {"REFUSED"};
    if (keys _requested findIf {!([_x,[_x] call _read] call _valueValid)} >= 0) exitWith {"REFUSED"};
    // The usual room tick keeps the same controls. Ownership/native checks above already
    // confirmed them: avoid copying receipt maps, writing controls or publishing metadata.
    if (_lease isNotEqualTo [] && {keys _requested findIf {
        !(_x in _owned) || {!([_x,(_owned get _x) select 1,_requested get _x] call _same)}
    } < 0}) exitWith {"APPLIED"};
    private _nextOwned=createHashMapFromArray (keys _owned apply {[_x,+(_owned get _x)]});
    {
        private _native=[_x] call _read;
        private _pair=+(_nextOwned getOrDefault [_x,[_native,_native]]);
        _pair set [1,_requested get _x];_nextOwned set [_x,_pair];
    } forEach keys _requested;
    if (count _nextOwned < count _requested) exitWith {"REFUSED"};
    {
        private _desired=_requested get _x;
        if (([_x] call _read) isNotEqualTo _desired) then {[_x,_desired] call _write};
    } forEach keys _requested;
    private _next=[+_context,_nextOwned,0];
    if (_next isNotEqualTo _lease) then {_actor setVariable ["CBE_ActorSettings",_next,true]};
    if (keys _nextOwned findIf {!([_x,[_x] call _read,(_nextOwned get _x) select 1] call _same)} >= 0) exitWith {"PENDING"};
    "APPLIED"
};
};
_result
