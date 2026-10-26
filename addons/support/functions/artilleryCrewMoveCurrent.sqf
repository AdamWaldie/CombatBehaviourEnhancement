/*
 * Author: WaldoTheWarfighter
 * Purpose: Read current selected-gun physical HOLD evidence for positioned fire admission.
 * Locality/authority: Current vehicle/group owner; trusted server may inspect published owner
 * proof plus its own position/range, replicated crew readiness and platform ownership markers.
 * Only the owner reads native destinations/tasks/FSM proof; replicated readiness is not instantaneous.
 * Repeat/JIP: No commands, mutation, deadline renewal or rebasing. HOLD is not a fired round.
 * Arguments: battery OBJECT,objNull; token STRING,""; original session ARRAY,[];
 * serial NUMBER,-1; supported spot ARRAY,[]; server recheck BOOL,false (server only).
 * Return: BOOL exact live hold evidence, never projectile or resumed-travel evidence.
 * Current callers: CortexArtilleryPosition/PositionReport/MissionStep/Shot.
 * Example: [_gun,_token,_session,_serial,_spot] call CBE_fnc_ArtilleryCrewMoveCurrent;
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_session",[],[[]]],
    ["_serial",-1,[0]],["_spot",[],[[]]],["_serverCheck",false,[true]]];
if (isNull _battery || {count _session != 10} || {count _spot != 3}
    || {_spot findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!local _battery && {!(_serverCheck && {isServer})}}) exitWith {false};
private _group=_session select 3;
private _work=_battery getVariable ["CBE_ArtilleryCrew_Work",createHashMap];
private _reference=_work getOrDefault ["reference",[]];
private _seats=[driver _battery,effectiveCommander _battery];
if (isNull (_seats select 1)) then {_seats set [1,_seats select 0]};
if (isNull _group || {(_work getOrDefault ["token",""]) != _token}
    || {(_work getOrDefault ["serial",-2]) != _serial}
    || {(_work getOrDefault ["session",[]]) isNotEqualTo _session}
    || {(_work getOrDefault ["spot",[]]) isNotEqualTo _spot}
    || {(_work getOrDefault ["phase",""]) != "HOLD"}
    || {_work getOrDefault ["release",true]}
    || {(_work getOrDefault ["crew",[]]) isNotEqualTo _seats}
    || {(_work getOrDefault ["owner",-1]) != owner _battery}
    || {(_work getOrDefault ["epoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",-2])}
    || {count _reference != 5}
    || {(_group getVariable ["CBE_ArtilleryCrew_Reference",[]]) isNotEqualTo _reference}
    || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_session select 4)}
    || {serverTime >= (_session select 9)} || {!alive _battery}
    || {!isNil {_battery getVariable "CBE_ExternalDrivingOwner"}}
    || {_battery getVariable ["CBE_Convoy_Active",false]}
    || {!simulationEnabled _battery} || {isObjectHidden _battery}
    || {_battery distance2D _spot > 25}
    || {abs (((getPosATL _battery) select 2)-(_spot select 2)) > 3}
    || {vectorMagnitude velocity _battery >= 0.278}
    || {vectorMagnitude angularVelocity _battery >= 0.01}) exitWith {false};
// Shared readiness precedes the remote server's HOLD acceptance. A published pose
// cannot keep an incapacitated/captive/player-operated crew usable until owner refresh.
// Platform takeover/convoy markers above likewise veto stale remote HOLD receipts.
// This reads currently replicated state only; native tasks/commands stay owner-local.
if (_seats findIf {
    isNull _x || {group _x != _group} || {objectParent _x != _battery}
        || {isPlayer _x} || {!isNull remoteControlled _x}
        || {!([_x] call CBE_fnc_CortexCombatEffective)}
} >= 0) exitWith {false};
if (_serverCheck && {isServer} && {!local _battery}) exitWith {true};
private _executor=_battery getVariable ["CBE_ArtilleryCrew_FSM",[]];
local _group && {(_work get "owner") == clientOwner}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)}
    && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {count _executor == 5} && {(_executor select 0) == _serial}
    && {(_executor select 2) == clientOwner} && {(_executor select 3) == (_work get "epoch")}
    && {(_executor select 1) isEqualType 0} && {finite (_executor select 1)}
    && {(_executor select 1) >= 0} && {!completedFSM (_executor select 1)}
    && {_seats findIf {
        private _point=(expectedDestination _x) param [0,[],[[]]];
        !local _x || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
            || {currentCommand _x == "STOP"} || {count _point != 3}
            || {_point findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {_point vectorDistance _spot > 0.25}
    } < 0}
