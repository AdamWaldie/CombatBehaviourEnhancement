/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe late replicated receipts for one already accepted parachute exit.
 * Locality/authority: A CBA wake caches metadata on connected peers. Only a deferred actual
 * actor-owner callback invokes existing exact-receipt readers; the wake grants no mutation.
 * Repeat/JIP: One cached proposal and coalesced observer per actor. Native init/Local can
 * resume it until the original protection deadline plus one second of cleanup observation.
 * Duplicate wakes never extend that window. New JIP peers rely on native receipt adoption;
 * this non-JIP event does not guarantee recovery of a receipt late to a newly joined peer.
 * Arguments: 0 actor <OBJECT, objNull>; 1 proposal <ARRAY, [] reads cache>, [protection,deploy].
 * Return: BOOL, true when a valid finite proposal is retained, not deployment success.
 * Current callers: XEH_preInit wake event, XEH_postInit actor init/Local, own CBA callback.
 * Example: [soldier1] call CBE_fnc_CortexParachuteObserve;
 */
params [["_actor",objNull,[objNull]],["_proposal",[],[[]]]];
if (isNull _actor) exitWith {false};
if (_proposal isEqualTo []) then {_proposal=_actor getVariable ["CBE_ParachuteObservation",[]]};
if (count _proposal != 2) exitWith {false};
_proposal params ["_protection","_deploy"];
if (!(_protection isEqualType []) || {count _protection != 6}
    || {!(_deploy isEqualType [])} || {!(count _deploy in [0,8])}) exitWith {false};
_protection params ["_schema","_originalActor","_issuer","_token","_baseline","_until"];
if (_schema isNotEqualTo 1 || {_originalActor isNotEqualTo _actor}
    || {!(_issuer isEqualType 0)} || {!finite _issuer} || {_issuer < 2} || {_issuer != floor _issuer}
    || {!(_token isEqualType "")} || {_token == ""} || {!(_baseline isEqualType true)}
    || {!(_until isEqualType 0)} || {!finite _until} || {_until < 0}
    || {_until > serverTime+4}) exitWith {false};
if (_deploy isNotEqualTo [] && {(_deploy select 0) isNotEqualTo 1
    || {(_deploy select 1) isNotEqualTo _actor} || {(_deploy select 2) isNotEqualTo _token}
    || {(_deploy select 7) isNotEqualTo _until}}) exitWith {false};
private _stopAt=_until+1;
private _current=_actor getVariable ["CBE_ParachuteObservation",[]];
if (serverTime >= _stopAt) exitWith {
    if (_current isEqualTo _proposal) then {_actor setVariable ["CBE_ParachuteObservation",nil]};
    false
};
if (_current isNotEqualTo _proposal) then {
    // A delayed prior wake cannot replace a later episode already known on this peer.
    if (count _current == 2 && {((_current select 0) select 5) >= _until}) exitWith {};
    _actor setVariable ["CBE_ParachuteObservation",+_proposal];
    [{
        params ["_actor","_proposal"];
        if (!isNull _actor && {(_actor getVariable ["CBE_ParachuteObservation",[]]) isEqualTo _proposal}) then {
            _actor setVariable ["CBE_ParachuteObservation",nil];
        };
    },[_actor,+_proposal],_stopAt-serverTime] call CBA_fnc_waitAndExecute;
};
if ((_actor getVariable ["CBE_ParachuteObservation",[]]) isNotEqualTo _proposal) exitWith {false};
if (!local _actor) exitWith {
    _actor setVariable ["CBE_ParachuteObservationQueued",nil];
    true
};
private _queued=_actor getVariable ["CBE_ParachuteObservationQueued",[]];
if (count _queued == 2 && {(_queued select 0) isEqualTo _proposal}) exitWith {true};
private _serial=(_actor getVariable ["CBE_ParachuteObservationSerial",0])+1;
_actor setVariable ["CBE_ParachuteObservationSerial",_serial];
private _queueToken=[+_proposal,_serial];
_actor setVariable ["CBE_ParachuteObservationQueued",_queueToken];
[{
    params ["_actor","_proposal","_stopAt","_queueToken"];
    if (isNull _actor || {(_actor getVariable ["CBE_ParachuteObservationQueued",[]]) isNotEqualTo _queueToken}) exitWith {};
    _actor setVariable ["CBE_ParachuteObservationQueued",nil];
    if (!local _actor || {serverTime >= _stopAt}
        || {(_actor getVariable ["CBE_ParachuteObservation",[]]) isNotEqualTo _proposal}) exitWith {};
    _proposal params ["_protection","_deploy"];
    private _protectionReady=(_actor getVariable ["CBE_ParachuteProtection",[]]) isEqualTo _protection;
    private _deployReady=_deploy isEqualTo [] || {(_actor getVariable ["CBE_ParachuteDeploy",[]]) isEqualTo _deploy};
    if (_protectionReady) then {[_actor,_protection] call CBE_fnc_CortexParachuteProtectionRelease};
    if (_deploy isNotEqualTo [] && {_deployReady}) then {[_actor,_deploy] call CBE_fnc_CortexParachuteDeploy};
    // Existing readers own due/deadline callbacks once both receipts have been observed.
    if (!_protectionReady || {!_deployReady}) then {[_actor] call CBE_fnc_CortexParachuteObserve};
},[_actor,+_proposal,_stopAt,_queueToken],0.1] call CBA_fnc_waitAndExecute;
true
