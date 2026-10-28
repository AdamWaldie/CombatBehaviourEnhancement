/*
 * Author: WaldoTheWarfighter
 * Purpose: Bind remote passenger consent to an actual crew-observed cargo cohort for one finite support bound.
 * Locality/authority: Vehicle/crew owner only. RECEIVE accepts server relay only; OFFER/READ are local calls.
 * Repeat/JIP: Four groups/sixteen original actors each, sixty-four seats, original sixty-second offer.
 * Sequence and terminal CLOSE prevent delayed packets reviving consent. Pulse freshness is measured from
 * its owner's observation time, at most six seconds, never from delayed delivery. No timer or native writer.
 * Arguments: mode STRING OFFER/READ/RECEIVE; vehicle OBJECT; crew GROUP; data ARRAY [] (packet or expected source).
 * Return: READ [proof,source] or[]; other modes BOOL. Current callers: CortexVehicles, Cargo, RemoteServer.
 * Example: ["OFFER",_apc,_crew] call CBE_fnc_CortexMechanisedRemoteCrew;
 */
params [["_mode","READ",[""]],["_vehicle",objNull,[objNull]],["_crew",grpNull,[grpNull]],["_data",[],[[]]]];
_mode=toUpperANSI _mode;
if (_mode == "READ" && {(_vehicle getVariable ["CBE_Cortex_MechRemoteManifest",[]]) isEqualTo []}) exitWith {[]};
if (isNull _vehicle || {!local _vehicle} || {isNull _crew} || {!local _crew}
    || {!alive _vehicle} || {!(_crew getVariable ["CBE_AIPass_Adopted",false])}
    || {group driver _vehicle != _crew} || {group effectiveCommander _vehicle != _crew}
    || {[_crew] call CBE_fnc_CortexExternalTakeover}
    || {_mode == "RECEIVE" && {remoteExecutedOwner != 2}}
    || {_mode != "RECEIVE" && {isRemoteExecuted}}) exitWith {[]};
private _context=[clientOwner,_crew getVariable ["CBE_AIPass_Epoch",-1],_crew,driver _vehicle,
    effectiveCommander _vehicle,[_crew] call CBE_fnc_NativeOrderReceipt];
private _manifest=_vehicle getVariable ["CBE_Cortex_MechRemoteManifest",[]];
private _valid=count _manifest == 4 && {(_manifest select 1) isEqualTo _context}
    && {serverTime < (_manifest select 2)} && {(_manifest select 2) <= serverTime+60};
if (_mode == "OFFER") exitWith {
    if (_valid) exitWith {true};
    private _seats=fullCrew [_vehicle,"",false];
    if (count _seats > 64) exitWith {false};
    private _groups=[];
    {
        private _person=_x select 0;private _group=group _person;private _role=_x select 1;
        if (alive _person && {!isPlayer _person} && {_group != _crew} && {!local _group}
            && {side _group == side _crew} && {_role == "cargo" || {_role == "turret" && {_x select 4}}}) then {
            private _index=_groups findIf {(_x select 0) == _group};
            if (_index < 0) then {_index=_groups pushBack [_group,groupOwner _group,[]]};
            private _people=(_groups select _index) select 2;_people pushBackUnique _person;
        };
    } forEach _seats;
    if (_groups isEqualTo [] || {count _groups > 4} || {_groups findIf {count (_x select 2) > 16} >= 0}) exitWith {false};
    private _serial=(_vehicle getVariable ["CBE_Cortex_MechRemoteSerial",0])+1;
    private _token=[clientOwner,_context select 1,_serial,"REMOTE"];
    _vehicle setVariable ["CBE_Cortex_MechRemoteSerial",_serial];
    _vehicle setVariable ["CBE_Cortex_MechRemoteManifest",[_token,_context,serverTime+60,_groups]];
    _vehicle setVariable ["CBE_Cortex_MechRemoteReplies",[]];
    _vehicle setVariable ["CBE_Cortex_MechRemoteOffer",[_token,_crew,clientOwner,serverTime+60],true];
    true
};
if (!_valid) exitWith {[]};
private _replies=+(_vehicle getVariable ["CBE_Cortex_MechRemoteReplies",[]]);
if (_mode == "RECEIVE") exitWith {
    if (count _data != 10) exitWith {false};
    _data params ["_token","_passengers","_sender","_epoch","_native","_until","_actors","_serial","_phase","_at"];
    if (_token isNotEqualTo (_manifest select 0) || {groupOwner _passengers != _sender}
        || {_until > (_manifest select 2)} || {_until <= serverTime} || {serverTime-_at > 6}
        || {_at > serverTime+1} || {_phase != "CLOSE" && {_native isNotEqualTo ([_passengers] call CBE_fnc_NativeOrderReceipt)}}) exitWith {false};
    private _original=(_manifest select 3) select {(_x select 0) == _passengers && {(_x select 1) == _sender}};
    if (_original isEqualTo [] || {_actors isEqualTo []} || {count _actors > 16}
        || {_phase != "CLOSE" && {_actors findIf {!(_x in ((_original select 0) select 2))} >= 0}}) exitWith {false};
    private _index=_replies findIf {(_x select 0) == _passengers};
    private _row=if (_index < 0) then {[]} else {_replies select _index};
    if (_row isNotEqualTo [] && {(_row select 8) || {_serial <= (_row select 6)}
        || {_epoch != (_row select 2)} || {_native isNotEqualTo (_row select 3)}}) exitWith {false};
    // A pulse cannot invent original EXIT acknowledgement; CLOSE may precede delayed EXIT.
    if (_phase == "PULSE" && {_row isEqualTo [] || {_actors isNotEqualTo (_row select 4)}}) exitWith {false};
    if (_index < 0 && {count _replies >= 4}) exitWith {false};
    private _new=[_passengers,_sender,_epoch,_native,+_actors,_until,_serial,(_at+6) min _until,_phase == "CLOSE"];
    if (_index < 0) then {_replies pushBack _new} else {_replies set [_index,_new]};
    _vehicle setVariable ["CBE_Cortex_MechRemoteReplies",_replies];
    true
};
if (_mode != "READ") exitWith {[]};
private _used=_vehicle getVariable ["CBE_Cortex_MechCargoUsed",[]];private _result=[];
{
    _x params ["_passengers","_sender","_epoch","_native","_actors","_until","_serial","_freshUntil","_closed"];
    private _source=[_passengers,_epoch,+(_manifest select 0),+_actors,_sender];
    private _index=currentWaypoint _passengers;
    if (!_closed && {serverTime < _freshUntil} && {serverTime < _until}
        && {groupOwner _passengers == _sender} && {!local _passengers}
        && {_native isEqualTo ([_passengers] call CBE_fnc_NativeOrderReceipt)}
        && {!([_passengers] call CBE_fnc_CortexExternalTakeover)}
        && {combatMode _passengers != "BLUE"} && {combatMode _passengers != "GREEN"}
        && {behaviour leader _passengers != "STEALTH"}
        && {(_passengers getVariable ["CBE_AIPass_Garrison",[]]) isEqualTo []}
        && {(_passengers getVariable ["CBE_AIPass_Defend",[]]) isEqualTo []}
        && {!(_passengers getVariable ["CBE_AIPass_ClearBuilding",false])}
        && {isNull objectParent leader _passengers}
        && {!(_index < count waypoints _passengers && {waypointType [_passengers,_index] in ["HOLD","SENTRY"]}
            && {waypointDescription [_passengers,_index] != "CBE AI PASS"})}
        && {_data isEqualTo _source || {_data isEqualTo [] && {!([_manifest select 0,_passengers] in _used)}}}) then {
        private _mobile=_actors select {alive _x && {group _x == _passengers} && {owner _x == _sender}
            && {isNull objectParent _x} && {!isPlayer _x} && {simulationEnabled _x} && {!isObjectHidden _x}
            && {[_x] call CBE_fnc_CortexCombatEffective} && {!fleeing _x}
            && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"} && {currentCommand _x != "STOP"}};
        if (count _mobile >= 2) then {_result=[[_until,0,_actors apply {[_x,_vehicle]},+_native],_source]};
    };
    if (_result isNotEqualTo []) exitWith {};
} forEach _replies;
_result
