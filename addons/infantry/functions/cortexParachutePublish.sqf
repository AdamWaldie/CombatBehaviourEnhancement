/*
 * Author: WaldoTheWarfighter
 * Purpose: Retain one finite parachute receipt wake for joining peers through CBA JIP.
 * Locality/authority: Server only, called by the CBA server event. Proposal publication
 * grants no actor command or damage authority; owner readers require exact live receipts.
 * Repeat/JIP: Token coalesces duplicates. Server publication and removal share one authority;
 * one callback removes the JIP entry at the original protection deadline plus one second,
 * even if the actor is deleted or the issuing client disconnects. No world scan or loop.
 * Arguments: 0 actor <OBJECT, objNull>; 1 proposal <ARRAY, []>, [protection,deploy].
 * Return: BOOL, true for a valid new or already-published proposal, not physical success.
 * Current caller: XEH_preInit CBE_ParachutePublish CBA server event.
 * Example: [soldier1,[_protection,_deployment]] call CBE_fnc_CortexParachutePublish;
 */
params [["_actor",objNull,[objNull]],["_proposal",[],[[]]]];
if (!isServer || {isNull _actor} || {count _proposal != 2}) exitWith {false};
_proposal params ["_protection","_deploy"];
if (!(_protection isEqualType []) || {count _protection != 6}
    || {!(_deploy isEqualType [])} || {!(count _deploy in [0,8])}) exitWith {false};
_protection params ["_schema","_originalActor","_issuer","_token","_baseline","_until"];
if (_schema isNotEqualTo 1 || {_originalActor isNotEqualTo _actor}
    || {!(_issuer isEqualType 0)} || {!finite _issuer} || {_issuer < 2} || {_issuer != floor _issuer}
    || {!(_token isEqualType "")} || {_token == ""} || {count _token > 128}
    || {!(_baseline isEqualType true)} || {!(_until isEqualType 0)} || {!finite _until}
    || {_until < 0} || {_until > serverTime+4} || {serverTime >= _until+1}) exitWith {false};
if (_deploy isNotEqualTo [] && {(_deploy select 0) isNotEqualTo 1
    || {(_deploy select 1) isNotEqualTo _actor} || {(_deploy select 2) isNotEqualTo _token}
    || {(_deploy select 7) isNotEqualTo _until}}) exitWith {false};
private _registry=missionNamespace getVariable ["CBE_ParachuteJIP",createHashMap];
if (_token in _registry) exitWith {(_registry get _token) isEqualTo _proposal};
_registry set [_token,+_proposal];
missionNamespace setVariable ["CBE_ParachuteJIP",_registry];
private _jipID=format ["CBE_Parachute:%1",_token];
["CBE_ParachuteObservation",[_actor,+_proposal],_jipID] call CBA_fnc_globalEventJIP;
[{
    params ["_token","_proposal","_jipID"];
    private _registry=missionNamespace getVariable ["CBE_ParachuteJIP",createHashMap];
    if ((_registry getOrDefault [_token,[]]) isEqualTo _proposal) then {
        [_jipID] call CBA_fnc_removeGlobalEventJIP;
        _registry deleteAt _token;
    };
},[_token,+_proposal,_jipID],(_until+1)-serverTime] call CBA_fnc_waitAndExecute;
true
