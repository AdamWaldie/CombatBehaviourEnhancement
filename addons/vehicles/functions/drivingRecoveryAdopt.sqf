/*
 * Author: WaldoTheWarfighter
 * Recovery is explicitly mode-bound: destination and SIMPLE_BACK have distinct native
 * ownership proof. Unknown modes grant no cleanup, adoption or command authority.
 * Purpose: Offers an existing pending driving-release receipt to its new vehicle owner.
 * Locality / Authority: Native LandVehicle init/Local and actual driving-seat events on each machine, never remote calls.
 * Only cleanup registration is permitted; the existing exact release guards authorize commands.
 * Repeat/JIP: Every locality edge invalidates older lookup callbacks. At most five one-second
 * late-receipt or pending-flag lookups for occupied vehicles; later delivery remains unsupported.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 gained locality <BOOL, false>;
 * 2 lookup attempt <NUMBER, 0>; 3 local epoch <NUMBER, -1>.
 * Return Value: BOOL - true only when a pending reverse receipt was offered, not physical success.
 * Current callers: XEH_postInit LandVehicle init/Local, DrivingRecoveryCrewAdopt and bounded delayed lookup.
 * Crew locality/entry/seat changes start a fresh observation window, never a fresh movement or recovery lifetime.
 * Example: [truck1,local truck1] call CBE_fnc_DrivingRecoveryAdopt;
 */
params [["_vehicle",objNull,[objNull]],["_gained",false,[true]],
    ["_attempt",0,[0]],["_epoch",-1,[0]]];
if (remoteExecutedOwner > 0 || {isNull _vehicle} || {!(_vehicle isKindOf "LandVehicle")}
    || {_vehicle isKindOf "StaticWeapon"}
    || {!finite _attempt} || {_attempt < 0} || {_attempt > 5} || {_attempt != floor _attempt}) exitWith {false};
private _accepted=false;
isNil {
    if (_attempt == 0) then {
        _epoch=1+(_vehicle getVariable ["CBE_DrivingRecovery_LocalEpoch",0]);
        _vehicle setVariable ["CBE_DrivingRecovery_LocalEpoch",_epoch];
    };
    if (_epoch == (_vehicle getVariable ["CBE_DrivingRecovery_LocalEpoch",0])
        && {_gained} && {local _vehicle} && {alive _vehicle}) then {
        private _work=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
        if (_work getOrDefault ["releasePending",false]
            && {(_work getOrDefault ["kind",""]) == "REVERSE"}
            && {(_work getOrDefault ["commandMode","DESTINATION"]) in ["DESTINATION","SIMPLE_BACK"]}) then {
            [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
            _accepted=true;
        } else {
            // A reverse receipt and its later pending flag can arrive separately. Observe
            // within the original window only; nonpending work never authorizes release.
            private _lookup=count _work == 0 || {(_work getOrDefault ["kind",""]) == "REVERSE"
                && {(_work getOrDefault ["commandMode","DESTINATION"]) in ["DESTINATION","SIMPLE_BACK"]}};
            if (_lookup && {_attempt < 5} && {count crew _vehicle > 0}) then {
                [{_this call CBE_fnc_DrivingRecoveryAdopt},
                    [_vehicle,true,_attempt+1,_epoch],1] call CBA_fnc_waitAndExecute;
            };
        };
    };
};
_accepted
