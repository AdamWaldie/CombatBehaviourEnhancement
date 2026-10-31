/*
 * Author: WaldoTheWarfighter
 * Purpose: Acknowledge or withdraw original cargo support from its actual passenger owner.
 * Locality/authority: Local adopted passenger group only; no native commands. Server authenticates
 * every packet before forwarding it to the actual crew owner. Private exit state is checked here.
 * Repeat/JIP: Up to four original vehicle episodes, sixteen actors each. Existing group ticks send
 * at most one pulse per two seconds/episode; original exit horizon never renews. A fresh crew
 * offer may rebind that original actual exit, but crew manifest still proves carriage. No JIP replay or job.
 * Arguments: group GROUP grpNull; mode STRING TICK/EXIT/CLOSE/BOARD; vehicle OBJECT objNull;
 * actor OBJECT objNull (EXIT, still physically mounted before CBE's first exit request).
 * Return: BOOL whether any packet was sent. Current callers: CortexOnboardContact, GroupTick, ReleaseGroup and native Boarded cleanup.
 * Example: [_group,"EXIT",_apc,_soldier] call CBE_fnc_CortexMechanisedRemote;
 */
// Engine event name is supplied by the native caller scope; see Bohemia addEventHandler.
#pragma hemtt ignore_variables ["_thisEvent"]
params [["_group",grpNull,[grpNull]],["_mode","TICK",[""]],
    ["_vehicle",objNull,[objNull]],["_actor",objNull,[objNull]]];
_mode=toUpperANSI _mode;
if ((isRemoteExecuted && {_mode != "BOARD" || {isNil "_thisEvent" || {_thisEvent != "GetIn"}}})
    || {isNull _group} || {!local _group}) exitWith {false};
if !(_mode in ["TICK","EXIT","CLOSE","BOARD"]) exitWith {false};
private _records=+(_group getVariable ["CBE_Cortex_MechRemoteExits",[]]);
if (_records isEqualTo [] && {_mode != "EXIT"}) exitWith {false};
_records=_records select {serverTime < (_x select 9)};
private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
private _native=[_group] call CBE_fnc_NativeOrderReceipt;
private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
private _owned=_state getOrDefault ["dismounted",[]];
if (_mode == "EXIT" && {!isNull _vehicle} && {!local _vehicle}
    && {!isNull _actor} && {local _actor} && {!isPlayer _actor} && {objectParent _actor == _vehicle}) then {
    private _offer=_vehicle getVariable ["CBE_Cortex_MechRemoteOffer",[]];
    if (_offer isEqualType [] && {count _offer == 4} && {(_offer select 0) isEqualType []}
        && {count (_offer select 0) == 4} && {((_offer select 0) select 3) isEqualTo "REMOTE"}
        && {((_offer select 0) select [0,3]) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {((_offer select 0) select 0) isEqualTo (_offer select 2)}
        && {(_offer select 1) isEqualType grpNull} && {(_offer select 2) isEqualType 0}
        && {(_offer select 3) isEqualType 0} && {serverTime < (_offer select 3)}
        && {(_offer select 3) <= serverTime+60}
        && {group effectiveCommander _vehicle == (_offer select 1)}
        && {groupOwner (_offer select 1) == (_offer select 2)}
        && {owner _vehicle == (_offer select 2)}
        && {_owned findIf {_x isEqualType [] && {count _x == 2} && {(_x select 0) == _actor}
            && {(_x select 1) == _vehicle}} >= 0}) then {
        private _at=_records findIf {(_x select 0) == _vehicle};
        if (_at < 0 && {count _records < 4}) then {
            _at=_records pushBack [_vehicle,_offer select 1,+(_offer select 0),_epoch,+_native,
                (_offer select 3) min (serverTime+60),[],0,0,serverTime+60];
        };
        if (_at >= 0) then {
            private _r=+(_records select _at);
            if ((_r select 2) isEqualTo (_offer select 0) && {(_r select 3) == _epoch}
                && {(_r select 4) isEqualTo _native} && {count (_r select 6) < 16}) then {
                private _actors=+(_r select 6);_actors pushBackUnique _actor;
                _r set [6,_actors];_r set [8,0];_records set [_at,_r];
            };
        };
    };
};
private _sent=false;private _keep=[];
{
    _x params ["_platform","_crewGroup","_token","_originalEpoch","_order","_until","_actors","_serial","_due","_originUntil"];
    private _rebound=false;
    private _fresh=_platform getVariable ["CBE_Cortex_MechRemoteOffer",[]];
    if (_mode in ["TICK","EXIT"] && {_fresh isEqualType []} && {count _fresh == 4} && {(_fresh select 0) isEqualType []}
        && {count (_fresh select 0) == 4} && {((_fresh select 0) select 3) isEqualTo "REMOTE"}
        && {((_fresh select 0) select [0,3]) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {((_fresh select 0) select 0) isEqualTo (_fresh select 2)}
        && {(_fresh select 1) isEqualTo _crewGroup} && {(_fresh select 2) isEqualType 0}
        && {(_fresh select 2) == groupOwner _crewGroup} && {owner _platform == (_fresh select 2)}
        && {(_fresh select 3) isEqualType 0} && {finite (_fresh select 3)}
        && {(_fresh select 3) > serverTime} && {(_fresh select 3) <= serverTime+60}
        && {(_fresh select 0) isNotEqualTo _token}) then {
        _token=+(_fresh select 0);_until=_originUntil min (_fresh select 3);
        _serial=0;_due=0;_rebound=true;
    };
    private _current=_mode != "CLOSE" && {!(_mode == "BOARD" && {_platform == _vehicle})}
        && {serverTime < _originUntil} && {!isNull _platform}
        && {_epoch == _originalEpoch} && {_order isEqualTo _native}
        && {_group getVariable ["CBE_AIPass_Adopted",false]}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}
        && {combatMode _group != "BLUE"} && {combatMode _group != "GREEN"}
        && {behaviour leader _group != "STEALTH"}
        && {(_group getVariable ["CBE_AIPass_Garrison",[]]) isEqualTo []}
        && {(_group getVariable ["CBE_AIPass_Defend",[]]) isEqualTo []}
        && {!(_group getVariable ["CBE_AIPass_ClearBuilding",false])}
        && {private _index=currentWaypoint _group;
            !(_index < count waypoints _group && {waypointType [_group,_index] in ["HOLD","SENTRY"]}
                && {waypointDescription [_group,_index] != "CBE AI PASS"})}
        && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {[_group,"CBE_AIPass_VehicleDismount_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {group effectiveCommander _platform == _crewGroup}
        && {groupOwner _crewGroup == (_token select 0)} && {owner _platform == (_token select 0)}
        && {count _owned <= 64} && {count _actors > 0} && {_actors findIf {alive _x} >= 0}
        && {_actors findIf {alive _x && {private _person=_x;
            !local _person || {group _person != _group}
            || {_owned findIf {_x isEqualType [] && {count _x == 2} && {(_x select 0) == _person}
                && {(_x select 1) == _platform}} < 0}}} < 0};
    if ((!_current || {serverTime >= _due}) && {!_current || {serverTime < _until}}) then {
        _serial=_serial+1;
        private _phase=if (!_current) then {"CLOSE"} else {
            if (_rebound || {_mode == "EXIT" && {_platform == _vehicle}}) then {"EXIT"} else {"PULSE"}
        };
        [_platform,_crewGroup,+_token,_group,_originalEpoch,+_order,_until,+_actors,_serial,_phase,serverTime,clientOwner]
            remoteExecCall ["CBE_fnc_CortexMechanisedRemoteServer",2];
        _sent=true;
    };
    if (_current) then {_keep pushBack [_platform,_crewGroup,_token,_originalEpoch,_order,_until,_actors,_serial,
        if (serverTime >= _due) then {serverTime+2} else {_due},_originUntil]};
} forEach _records;
_group setVariable ["CBE_Cortex_MechRemoteExits",_keep];
_sent
