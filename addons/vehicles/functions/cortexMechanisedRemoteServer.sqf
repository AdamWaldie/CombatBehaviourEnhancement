/*
 * Author: WaldoTheWarfighter
 * Purpose: Authenticate passenger-owner consent packets and forward only to the current vehicle owner.
 * Locality/authority: Server only; requires the actual sending server/HC and current passenger group owner.
 * Repeat/JIP: Stateless relay, original token/deadline/sequence retained, no JIP or movement permission.
 * Arguments: vehicle OBJECT; crew GROUP; token ARRAY4; passengers GROUP; epoch NUMBER;
 * native order ARRAY; deadline NUMBER; actors ARRAY <=16; serial NUMBER; phase STRING;
 * observation server time NUMBER; claimed owner NUMBER. Defaults refuse incomplete packets.
 * Return: BOOL forwarded, not accepted. Current caller: CortexMechanisedRemote.
 * Example: _packet remoteExecCall ["CBE_fnc_CortexMechanisedRemoteServer",2];
 */
params [["_vehicle",objNull,[objNull]],["_crew",grpNull,[grpNull]],["_token",[],[[]]],
    ["_passengers",grpNull,[grpNull]],["_epoch",-1,[0]],["_native",[],[[]]],
    ["_until",-1,[0]],["_actors",[],[[]]],["_serial",-1,[0]],["_phase","",[""]],
    ["_at",-1,[0]],["_claimed",-1,[0]]];
if (!isServer || {isNull _vehicle} || {isNull _crew} || {isNull _passengers}
    || {_crew == _passengers} || {count _token != 4}
    || {(_token select 3) isNotEqualTo "REMOTE"}
    || {(_token select [0,3]) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {count _actors == 0} || {count _actors > 16}
    || {_phase != "CLOSE" && {_actors findIf {!(_x isEqualType objNull) || {isNull _x} || {isPlayer _x} || {group _x != _passengers}} >= 0}}
    || {!(_phase in ["EXIT","PULSE","CLOSE"])}
    || {[_epoch,_until,_serial,_at] findIf {!finite _x} >= 0}
    || {_serial < 1} || {_at > serverTime+1} || {serverTime-_at > 6}
    || {_until <= serverTime} || {_until > serverTime+60}
    || {side _crew != side _passengers}) exitWith {false};
private _sender=[_claimed,groupOwner _passengers] call CBE_fnc_HeadlessResolveSender;
if (_sender < 0 || {_sender != 2 && {(entities "HeadlessClient_F") findIf {owner _x == _sender} < 0}}) exitWith {false};
private _crewOwner=groupOwner _crew;
if (_crewOwner <= 0 || {_crewOwner != owner _vehicle} || {_crewOwner != (_token select 0)}
    || {group effectiveCommander _vehicle != _crew}) exitWith {false};
// No server-maintained positive cache. The crew checks its private actual-cargo manifest.
["RECEIVE",_vehicle,_crew,[_token,_passengers,_sender,_epoch,_native,_until,_actors,_serial,_phase,_at]]
    remoteExecCall ["CBE_fnc_CortexMechanisedRemoteCrew",_crewOwner];
true
