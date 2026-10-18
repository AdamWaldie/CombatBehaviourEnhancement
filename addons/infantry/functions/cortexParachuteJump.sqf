/*
 * Author: WaldoTheWarfighter
 * Makes one AI soldier jump from an aircraft on a parachute of his own, keeping his backpack.
 *
 * The soldier leaves behind the aircraft with its speed, and a parachute vehicle (the pack's
 * static-line class, WALDO_STATIC_STATICCHUTE, default NonSteerable_Parachute_F) is created for him a
 * moment later, so his backpack is never swapped out. He is protected from damage for the few seconds of the exit.
 * Missing classes and non-parachute vehicle classes fall back to the vanilla static chute.
 * Exit admission preserves actor reservations, direct remote control and specialist ownership.
 * Only a visible, simulated aircraft may supply an exit; parachutes and ground/on-foot calls
 * refuse. Recheck actor/airframe authority without suspension at the exit mutation boundary.
 * Repeat/JIP: one public protection receipt prevents overlapping CBE exits. Owner-local exact
 * deadline cleanup survives native Local/init adoption independently of tactics enablement.
 * Failed chute boarding deletes only this newly created empty local chute; no replacement seat is forced.
 * AI leave a parachute on their own when they land. For players, use the Paradrop feature instead.
 * Locality and authority: call where the soldier is local (moveOut and moveInDriver are local-argument).
 *
 * Review contract: Exact receipt cleanup preserves the original damage baseline and rejects stale
 * releases. Mid-exit chute-phase migration and same-value external protection remain unresolved.
 *
 * Arguments:
 * 0: soldier <OBJECT>
 * 1: aircraft <OBJECT>
 *
 * Return Value:
 * Boolean - true when the soldier jumped
 *
 * Example:
 * [_soldier, _helicopter] call CBE_fnc_CortexParachuteJump;
 * Result: the soldier drops behind the helicopter and his parachute opens.
 *
 * Current caller: CBE_fnc_CortexAirborneDropStep.
 */

params [["_unit", objNull, [objNull]], ["_aircraft", objNull, [objNull]]];
if (isNull _unit || {isNull _aircraft} || {_unit == _aircraft}
    || {!(_aircraft isKindOf "Air")} || {_aircraft isKindOf "ParachuteBase"}) exitWith {false};
private _mayExit={
    alive _unit && {local _unit} && {!isPlayer _unit} && {vehicle _unit == _aircraft}
        && {simulationEnabled _unit} && {!isObjectHidden _unit}
        && {simulationEnabled _aircraft} && {!isObjectHidden _aircraft}
        && {[_unit] call CBE_fnc_CortexCombatEffective}
        && {!([_unit] call CBE_fnc_CortexActorMoveReserved)}
        && {isNull remoteControlled _unit}
        && {isNull (_unit getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {([_unit] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
        && {(_unit getVariable ["CBE_ParachuteProtection",[]]) isEqualTo []}
};
if !(call _mayExit) exitWith {false};
private _chuteClass = missionNamespace getVariable ["WALDO_STATIC_STATICCHUTE", "NonSteerable_Parachute_F"];
// Backpack classes also exist in CfgVehicles but cannot carry a jumper.
if !(isClass (configFile >> "CfgVehicles" >> _chuteClass) && {_chuteClass isKindOf "ParachuteBase"}) then {
    _chuteClass = "NonSteerable_Parachute_F";
};
private _velocity = velocity _aircraft;
// Just behind and below the airframe, clear of rotors and tail ramp.
private _exit = _aircraft modelToWorld [0, ((((boundingBoxReal _aircraft) select 0) select 1) min -6) - 2, -3];
private _receipt=[];
private _exited=false;
isNil {
    if (call _mayExit) then {
        private _serial=(missionNamespace getVariable ["CBE_ParachuteProtectionSerial",0])+1;
        missionNamespace setVariable ["CBE_ParachuteProtectionSerial",_serial];
        _receipt=[1,_unit,clientOwner,format ["%1:%2",clientOwner,_serial],isDamageAllowed _unit,serverTime+3.8];
        _unit setVariable ["CBE_ParachuteProtection",+_receipt,true];
        _unit setVariable ["CBE_ParachuteExitToken",_receipt select 3,true];
        _unit allowDamage false;
        unassignVehicle _unit;
        moveOut _unit;
        _unit setPosATL _exit;
        _unit setVelocity _velocity;
        _exited=true;
    };
};
if (!_exited) exitWith {false};
// Queue the immutable protection deadline before the chute callback, independent of tactics.
[_unit,_receipt] call CBE_fnc_CortexParachuteProtectionRelease;
[{
    params ["_unit", "_chuteClass", "_velocity", "_receipt"];
    if (!alive _unit || {!local _unit} || {vehicle _unit != _unit}
        || {(_unit getVariable ["CBE_ParachuteExitToken",""]) isNotEqualTo (_receipt select 3)}) exitWith {};
    // Protection may already have retired under scheduler delay. The exit token still
    // distinguishes this one accepted jump from a later exit without renewing protection.
    private _chute = createVehicle [_chuteClass, getPosATL _unit, [], 0, "CAN_COLLIDE"];
    _chute setDir getDir _unit;
    _unit moveInDriver _chute;
    // A failed seat command must not leave an empty moving chute behind. Never delete
    // an occupied object or a chute whose locality changed after creation.
    if (vehicle _unit == _chute) then {
        _chute setVelocity (_velocity vectorMultiply 0.5);
    } else {
        if (!isNull _chute && {local _chute} && {crew _chute isEqualTo []}) then {deleteVehicle _chute};
    };
}, [_unit, _chuteClass, _velocity, _receipt], 0.8] call CBA_fnc_waitAndExecute;
true
