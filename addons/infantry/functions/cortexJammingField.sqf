/*
 * Author: WaldoTheWarfighter
 * Purpose: Register, update or remove one explicit AI radio-interference emitter.
 * Locality/authority: Server owns the at-most32-field snapshot. Raw client calls refuse;
 * named curator tasks authenticate the actual sender and exact editable emitter.
 * No native aircraft, actor, radio-addon or movement commands are issued.
 * Repeat/JIP: Same registration is idempotent. Latest snapshot is public for joining
 * owners. Queries read current emitter position/life; deletion/death immediately stops
 * its effect without a cleanup worker. Later registration prunes dead entries.
 * Arguments: 0 emitter OBJECT, required; 1 enabled BOOL, required;
 * 2 radius NUMBER, required when enabling, finite1..100000 metres;
 * 3 affected sides ARRAY of SIDE, required when enabling,1..4 unique sides from
 * west/east/resistance/civilian. Explicit sides avoid treating every radar as a jammer.
 * Disable uses only [emitter,false]. No global setting, target knowledge or voice denial.
 * Return Value: BOOL, snapshot accepted; false for invalid input or full registry.
 * Named task input: pairs mode EMIT/STOP, emitter OBJECT, radius NUMBER, sides ARRAY,
 * serial positive integer, expires serverTime <=12s ahead. Assigned curators only for clients;
 * server revalidates editable target, types, bounds, sequence and identical retry payload.
 * At most64 owner receipts; stale requests from that owner cannot undo its newer STOP.
 * All registry/receipt changes share one unscheduled transaction; no delayed writer.
 * Return for a client named task is submission only; server sends acceptance/refusal feedback.
 * Current callers: Server mission scripts and JammingTaskDialog; CortexJammingFactor reads fields.
 * Example: [jammerVehicle,true,200,[west]] call CBE_fnc_CortexJammingField;
 */
if (!(_this isEqualType []) || {_this isEqualTo []}) exitWith {false};
private _named=(_this select 0) isEqualType [];
if (!isServer) exitWith {
    if (!_named || {!hasInterface}) exitWith {false};
    _this remoteExecCall ["CBE_fnc_CortexJammingField",2];
    true
};
private _request=_this;
private _apply={
    if (!(count _this in [2,4])) exitWith {false};
    params ["_emitter","_enabled",["_radius",200],["_sides",[]]];
    if (!(_emitter isEqualType objNull) || {isNull _emitter}
        || {!(_enabled isEqualType true)}) exitWith {false};
    if (_enabled && {count _this != 4 || {!alive _emitter}
        || {!(_radius isEqualType 0)} || {!finite _radius} || {_radius < 1} || {_radius > 100000}
        || {!(_sides isEqualType [])} || {count _sides < 1} || {count _sides > 4}
        || {_sides findIf {!(_x isEqualType west) || {!(_x in [west,east,resistance,civilian])}} >= 0}
    }) exitWith {false};
    private _original=missionNamespace getVariable ["CBE_EW_Fields",[]];
    if (!(_original isEqualType []) || {count _original > 32}) exitWith {false};
    private _fields=_original select {
        _x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualType objNull}
            && {!isNull (_x select 0)} && {alive (_x select 0)}
    };
    private _index=_fields findIf {(_x select 0) == _emitter};
    if (_enabled) then {
        private _affected=[west,east,resistance,civilian] select {_x in _sides};
        private _field=[_emitter,_radius,_affected];
        if (_index >= 0) then {_fields set [_index,_field]} else {
            if (count _fields < 32) then {_fields pushBack _field} else {_index=-2};
        };
    } else {
        if (_index >= 0) then {_fields deleteAt _index};
    };
    if (_index == -2) exitWith {false};
    if (_fields isNotEqualTo _original) then {
        missionNamespace setVariable ["CBE_EW_Fields",_fields,true];
    };
    true
};
private _accepted=false;
isNil {
    _accepted=_request call {
        private _sender=remoteExecutedOwner;
        if (isRemoteExecuted && {_sender <= 0}) exitWith {false};
        // Trusted server scripts keep their original positional API. No raw client bypass.
        if (!_named) exitWith {
            if (_sender > 0 && {_sender != 2}) exitWith {false};
            _this call _apply
        };
        private _replyOwner=[2,_sender] select (_sender > 0);
        private _curator=objNull;
        private _players=allPlayers;
        private _index=_players findIf {owner _x == _replyOwner && {!isNull getAssignedCuratorLogic _x}};
        if (_index >= 0) then {_curator=getAssignedCuratorLogic (_players select _index)};
        if (_sender > 2 && {isNull _curator}) exitWith {false};
        private _reply={
            params ["_ok","_message"];
            ["AI RADIO DENIAL",_message,["ERROR","INFO"] select _ok]
                remoteExecCall ["CBE_fnc_AITweaksNotifyLocal",_replyOwner];
            _ok
        };
        if (count _this != 6 || {_this findIf {
            !(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}
        } >= 0}) exitWith {[false,"Invalid radio-denial task payload."] call _reply};
        private _keys=_this apply {_x select 0};
        if (count (_keys arrayIntersect _keys) != 6 || {_keys findIf {
            !(_x in ["mode","emitter","radius","sides","serial","expires"])
        } >= 0}) exitWith {[false,"Invalid or duplicate task parameter."] call _reply};
        private _task=createHashMapFromArray _this;
        private _mode=_task get "mode";
        private _emitter=_task get "emitter";
        private _radius=_task get "radius";
        private _sides=_task get "sides";
        private _serial=_task get "serial";
        private _expires=_task get "expires";
        if (!(_mode isEqualType "") || {!(_mode in ["EMIT","STOP"])}
            || {!(_emitter isEqualType objNull)} || {isNull _emitter}
            || {!(_radius isEqualType 0)} || {!finite _radius} || {_radius < 1} || {_radius > 100000}
            || {!(_sides isEqualType [])} || {count _sides > 4}
            || {_sides findIf {!(_x isEqualType west) || {!(_x in [west,east,resistance,civilian])}} >= 0}
            || {_mode == "EMIT" && {count _sides == 0 || {!alive _emitter}}}
            || {!(_serial isEqualType 0)} || {!finite _serial} || {_serial < 1} || {_serial != floor _serial}
            || {!(_expires isEqualType 0)} || {!finite _expires}
            || {_expires <= serverTime} || {_expires > serverTime+12}) exitWith {
            [false,"Invalid or expired task. Select a live emitter, range and affected sides."] call _reply
        };
        if (!isNull _curator && {!(_emitter in curatorEditableObjects _curator)}) exitWith {
            [false,"The selected emitter is not editable by your curator."] call _reply
        };
        private _receipts=missionNamespace getVariable ["CBE_EW_TaskReceipts",createHashMap];
        private _key=str _replyOwner;
        private _previous=_receipts getOrDefault [_key,[]];
        private _payload=[_mode,_emitter,_radius,+_sides];
        if (_previous isNotEqualTo [] && {_serial <= (_previous select 0)}) exitWith {
            if (_serial == (_previous select 0) && {_payload isEqualTo (_previous select 1)}) then {
                (_previous select 2) call _reply
            } else {[false,"A newer or different radio-denial task already exists."] call _reply}
        };
        if (_previous isEqualTo [] && {count _receipts >= 64}) exitWith {
            [false,"Radio-denial request capacity reached."] call _reply
        };
        // Resolve locally only after authentication; no caller-provided authority flag.
        private _args=if (_mode == "STOP") then {[_emitter,false]} else {[_emitter,true,_radius,_sides]};
        private _ok=_args call _apply;
        private _answer=[_ok,if (_ok) then {
            ["AI radio-denial field registered. Voice and player radios are unchanged.",
                "AI radio-denial field removed."] select (_mode == "STOP")
        } else {"Emitter refused or field capacity reached. No new field registered."}];
        _receipts set [_key,[_serial,_payload,_answer]];
        missionNamespace setVariable ["CBE_EW_TaskReceipts",_receipts];
        if (_replyOwner == 2) then {missionNamespace setVariable ["CBE_EW_LocalSerial",
            (missionNamespace getVariable ["CBE_EW_LocalSerial",0]) max _serial]};
        _answer call _reply
    };
    false
};
_accepted
