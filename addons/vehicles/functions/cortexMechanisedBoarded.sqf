/*
 * Author: WaldoTheWarfighter
 * Purpose: Retire old dismount/carriage intent after a real native boarding event.
 * Locality/authority: Native GetIn handler only. The actor owner changes private exit metadata;
 * the vehicle owner retires its original cargo source. No seat, movement, group or skill command.
 * Repeat/JIP: Reuses the existing GetIn handler, not seat-change/init/Local or a timer. Ordinary
 * untracked boarding is a fast no-op. At most64seat/owned rows and4groups/16acknowledged actors.
 * Actual native entry is not proof of a walked boarding path; mission moveIn commands also emit GetIn.
 * Arguments: vehicle OBJECT objNull; boarded actor OBJECT objNull.
 * Return: BOOL metadata changed. Current caller: LandVehicle GetIn in XEH_postInit.
 * Example: vehicle addEventHandler ["GetIn",{[_this select 0,_this select 2] call CBE_fnc_CortexMechanisedBoarded}];
 */
// Engine event name is supplied by the native caller scope; see Bohemia addEventHandler.
#pragma hemtt ignore_variables ["_thisEvent"]
params [["_vehicle",objNull,[objNull]],["_actor",objNull,[objNull]]];
if (isNil "_thisEventHandler" || {isNil "_thisEvent"} || {_thisEvent != "GetIn"}
    || {isNull _vehicle} || {isNull _actor} || {!alive _actor}
    || {!local _vehicle && {!local _actor}}) exitWith {false};
private _group=group _actor;
private _state=if (local _actor && {local _group}) then {
    _group getVariable ["CBE_AIPass_State",createHashMap]
} else {createHashMap};
private _owned=_state getOrDefault ["dismounted",[]];
private _withdraw=count _owned <= 64 && {_owned findIf {
    _x isEqualType [] && {count _x == 2} && {(_x select 0) == _actor}
} >= 0};
private _remoteExits=if (local _actor && {local _group}) then {
    _group getVariable ["CBE_Cortex_MechRemoteExits",[]]
} else {[]};
private _remoteWithdraw=count _remoteExits <= 4 && {_remoteExits findIf {
    (_x select 0) == _vehicle && {_actor in (_x select 6)}
} >= 0};
private _cohort=if (local _vehicle) then {_vehicle getVariable ["CBE_Cortex_MechCargo",[]]} else {[]};
private _manifest=if (local _vehicle) then {_vehicle getVariable ["CBE_Cortex_MechRemoteManifest",[]]} else {[]};
private _support=if (local _vehicle) then {
    (_vehicle getVariable ["CBE_VehicleTacticalMove_Work",createHashMap]) getOrDefault ["kind",""] == "MECH_SUPPORT"
} else {false};
if (!_withdraw && {!_remoteWithdraw} && {!_support} && {_cohort isEqualTo []} && {_manifest isEqualTo []}) exitWith {false};
// Require actual occupied seating as well as the native edge; never infer boarding from intent.
private _seats=fullCrew [_vehicle,"",false];
if (count _seats > 64 || {objectParent _actor != _vehicle}
    || {_seats findIf {(_x select 0) == _actor} < 0}) exitWith {false};
private _changed=false;
if (local _actor && {local _group}) then {
    [_group,"BOARD",_vehicle,_actor] call CBE_fnc_CortexMechanisedRemote;
    if (_withdraw) then {
        _state set ["dismounted",_owned select {(_x select 0) != _actor}];
        private _proof=_group getVariable ["CBE_Cortex_DismountContinuation",[]];
        if (count _proof == 4) then {
            _proof=+_proof;
            private _rows=(_proof select 2) select {(_x select 0) != _actor};
            if (_rows isEqualTo []) then {_group setVariable ["CBE_Cortex_DismountContinuation",nil,true]} else {
                _proof set [2,_rows];_group setVariable ["CBE_Cortex_DismountContinuation",_proof,true];
            };
        };
        _changed=true;
    };
};
if (local _vehicle) then {
    // Fence captured own-group contexts as well as separate-squad tokens. A brief
    // boarding/exit between worker samples must not lend new exit rows to an old leg.
    _vehicle setVariable ["CBE_Cortex_MechBoardSerial",(_vehicle getVariable ["CBE_Cortex_MechBoardSerial",0])+1];
    _changed=true;
    // A fresh actual load retires the previous vehicle carriage episode. Old worker contexts
    // retain their old source and must retire; no delayed reply can acquire the new manifest.
    if (count _cohort == 4 && {(_cohort select 3) isNotEqualTo []}) then {
        _vehicle setVariable ["CBE_Cortex_MechCargo",nil];_changed=true;
    };
    private _replies=_vehicle getVariable ["CBE_Cortex_MechRemoteReplies",[]];
    if (count _manifest == 4 && {_replies isNotEqualTo []}) then {
        _vehicle setVariable ["CBE_Cortex_MechRemoteManifest",nil];
        _vehicle setVariable ["CBE_Cortex_MechRemoteReplies",nil];
        _vehicle setVariable ["CBE_Cortex_MechRemoteOffer",nil,true];_changed=true;
    };
    // OFFER may extend only an unacknowledged roster from actual occupied seats. Its
    // deadline stays fixed; a closed/acknowledged episode was retired above first.
    if (_changed || {_manifest isNotEqualTo []}) then {
        private _offer=["OFFER",_vehicle,group effectiveCommander _vehicle,[_actor]] call CBE_fnc_CortexMechanisedRemoteCrew;
        if (_offer isEqualTo true) then {_changed=true};
    };
};
_changed
