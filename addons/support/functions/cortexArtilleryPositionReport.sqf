/*
 * Author: WaldoTheWarfighter
 * Purpose: Authenticate one pre-fire positioning result for the exact server fire mission.
 * Locality/authority: Server only; actual addressed AI owner plus independently observed arrival/range.
 * Repeat/JIP: Matching token/session/phase only; repeated or stale replies cannot fire or move.
 * Arguments: battery OBJECT; token STRING; status STRING; replyOwner NUMBER; spot ARRAY; generation NUMBER.
 * Return: Nothing. READY is firing admission only, never proof that a projectile fired.
 * Current caller: CortexArtilleryPosition on the actual owner.
 * Example: [_gun,_token,"READY",clientOwner,_spot,_generation] remoteExecCall ["CBE_fnc_CortexArtilleryPositionReport",2];
 */
params ["_battery","_token","_status","_replyOwner","_spot","_generation"];
if (!isServer || {isNull _battery}) exitWith {};
private _mission=(missionNamespace getVariable ["CBE_AIPass_FireMissions",createHashMap]) getOrDefault [netId _battery,createHashMap];
if (count _mission == 0 || {(_mission get "token") != _token} || {(_mission get "phase") != "POSITIONING"}
    || {([_replyOwner,_mission getOrDefault ["positionOwner",-1]] call CBE_fnc_HeadlessResolveSender) < 0}
    || {_replyOwner != owner _battery}) exitWith {};
private _session=_mission get "positionSession";
if (serverTime >= (_session select 2)) exitWith {};
private _readyValid=true;
if (_status == "READY") then {
    private _group=_session select 3;
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _intent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
    private _issued=_battery getVariable ["CBE_ArtilleryPosition_Issued",[]];
    private _seats=[driver _battery,effectiveCommander _battery];
    if (isNull (_seats select 1)) then {_seats set [1,_seats select 0]};
    _readyValid=count _issued == 8 && {(_issued select 0) == _token}
        && {(_issued select 1) isEqualTo _session} && {(_issued select 2) == _group}
        && {(_issued select 3) isEqualTo _generation} && {(_issued select 5) isEqualTo _spot}
        && {(_issued select 4) == (_group getVariable ["CBE_AIPass_Epoch",-1])}
        && {(_issued select 6) == _replyOwner}
        && {(_issued select 7) isEqualTo _seats}
        && {group driver _battery == _group}
        && {(_operation getOrDefault ["generation",-2]) == _generation}
        && {(_operation getOrDefault ["intent",""]) == "ARTILLERY_POSITION"}
        && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_operation getOrDefault ["artilleryPositionOrder",[]])}
        && {(_intent getOrDefault ["operationGeneration",-2]) == _generation}
        && {(_intent getOrDefault ["waypoint",[]]) isEqualTo [_group,currentWaypoint _group]}
        && {waypointType [_group,currentWaypoint _group] == "HOLD"}
        && {(_intent getOrDefault ["requestedPosition",[]]) isEqualTo _spot}
        && {vectorMagnitude velocity _battery < 0.278}
        && {vectorMagnitude angularVelocity _battery < 0.01}
        && {_spot isEqualType []} && {count _spot == 3}
        && {_spot findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {_generation isEqualType 0} && {finite _generation} && {_generation >= 0}
        && {_battery distance2D _spot <= 25}
        && {abs (((getPosATL _battery) select 2)-(_spot select 2)) <= 3}
        && {((_mission get "fix") select 0) inRangeOfArtillery [[_battery],_mission get "magazine"]};
};
if (!_readyValid) exitWith {};
_mission set ["positionResult",_status];
