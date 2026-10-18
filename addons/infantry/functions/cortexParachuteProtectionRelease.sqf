/*
 * Author: WaldoTheWarfighter
 * Purpose: Restore one exact parachute-exit damage baseline on the actual actor owner.
 * Locality/authority: Actual actor owner only; remote calls refuse. Native actor init/Local
 * callbacks authorize local observation; issuer is immutable provenance, not remote permission.
 * Repeat/JIP: Public schema1 receipt [schema,actor,issuer,token,baseline,absolute deadline].
 * Exact receipt comparison rejects old callbacks. One local deadline callback is coalesced;
 * native actor init/Local adoption queues release independently of tactics enablement.
 * No deadline renewal, world scan, flight/chute replay or blanket damage command is used.
 * External same-value allowDamage writes cannot be attributed without cooperation.
 * Arguments: 0 actor <OBJECT, objNull>; 1 exact receipt <ARRAY, [] reads live locally>.
 * Return: BOOL, true only when matching protection bookkeeping is retired now.
 * Current callers: CortexParachuteJump, XEH_postInit actor init/Local, bounded CBA callback.
 * Example: [soldier1] call CBE_fnc_CortexParachuteProtectionRelease;
 */
params [["_actor",objNull,[objNull]],["_receipt",[],[[]]]];
if (isNull _actor || {remoteExecutedOwner > 0}) exitWith {false};
if (_receipt isEqualTo [] && {remoteExecutedOwner == 0} && {!local _actor}) exitWith {
    _actor setVariable ["CBE_ParachuteProtectionQueued",nil];
    false
};
if (_receipt isEqualTo []) then {
    if (remoteExecutedOwner > 0 || {!local _actor}) exitWith {};
    _receipt=_actor getVariable ["CBE_ParachuteProtection",[]];
};
if (count _receipt != 6) exitWith {false};
_receipt params ["_schema","_originalActor","_issuer","_token","_baseline","_until"];
if (_schema isNotEqualTo 1 || {_originalActor isNotEqualTo _actor}
    || {!(_issuer isEqualType 0)} || {!finite _issuer} || {_issuer < 2} || {_issuer != floor _issuer}
    || {!(_token isEqualType "")} || {_token == ""} || {!(_baseline isEqualType true)}
    || {!(_until isEqualType 0)} || {!finite _until} || {_until < 0}
    || {(_actor getVariable ["CBE_ParachuteProtection",[]]) isNotEqualTo _receipt}) exitWith {false};
if (!local _actor) exitWith {false};
if (serverTime < _until) exitWith {
    if ((_actor getVariable ["CBE_ParachuteProtectionQueued",[]]) isNotEqualTo _receipt) then {
        _actor setVariable ["CBE_ParachuteProtectionQueued",+_receipt];
        [{
            params ["_actor","_receipt"];
            if (local _actor && {(_actor getVariable ["CBE_ParachuteProtectionQueued",[]]) isEqualTo _receipt}) then {
                _actor setVariable ["CBE_ParachuteProtectionQueued",nil];
            };
            [_actor,_receipt] call CBE_fnc_CortexParachuteProtectionRelease;
        },[_actor,+_receipt],_until-serverTime] call CBA_fnc_waitAndExecute;
    };
    false
};
private _restored=false;
isNil {
    if (local _actor && {(_actor getVariable ["CBE_ParachuteProtection",[]]) isEqualTo _receipt}) then {
        // A newer visible permission value supersedes ours. Same-value external ownership
        // still needs a cooperating contract and cannot be inferred from a boolean.
        private _changed=isDamageAllowed _actor;
        if (!_changed) then {_actor allowDamage _baseline};
        _actor setVariable ["CBE_ParachuteProtection",nil,true];
        if ((_actor getVariable ["CBE_ParachuteProtectionQueued",[]]) isEqualTo _receipt) then {
            _actor setVariable ["CBE_ParachuteProtectionQueued",nil];
        };
        _actor setVariable ["CBE_ParachuteProtectionResult",[
            ["RESTORED","SUPERSEDED"] select _changed,_token,serverTime
        ],true];
        _restored=true;
    };
};
_restored
