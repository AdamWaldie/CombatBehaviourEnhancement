/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one accepted finite parachute deployment on the actual soldier owner.
 * Locality/authority: Actor-local only; remote calls refuse. Native init/Local observation
 * can adopt a public receipt, never replay dismount, position or exit velocity.
 * Repeat/JIP: Schema1 [1,actor,exitToken,group,chuteClass,velocity,due,deadline]. Exact
 * receipt and exit identity gate one unscheduled consumption before creating the chute.
 * The original protection deadline bounds deployment; landed/taken-over actors cancel.
 * Native locality loss clears only local queued admission. Late public receipt delivery
 * after init/Local observation is not guaranteed to be recovered. No world scan or loop.
 * Arguments: 0 actor <OBJECT, objNull>; 1 exact receipt <ARRAY, [] reads live locally>.
 * Return: BOOL, true only if this call successfully boarded the actor into its new chute.
 * Current callers: CortexParachuteJump, XEH_postInit init/Local, bounded CBA callback.
 * Example: [soldier1] call CBE_fnc_CortexParachuteDeploy;
 */
params [["_unit",objNull,[objNull]],["_receipt",[],[[]]]];
if (isNull _unit || {remoteExecutedOwner > 0}) exitWith {false};
if (!local _unit) exitWith {
    if (_receipt isEqualTo []) then {_unit setVariable ["CBE_ParachuteDeployQueued",nil]};
    false
};
if (_receipt isEqualTo []) then {_receipt=_unit getVariable ["CBE_ParachuteDeploy",[]]};
if (!(_receipt isEqualType []) || {count _receipt != 8}) exitWith {false};
_receipt params ["_schema","_actor","_token","_group","_chuteClass","_velocity","_due","_until"];
if (_schema isNotEqualTo 1 || {_actor isNotEqualTo _unit}
    || {!(_token isEqualType "")} || {_token == ""} || {!(_group isEqualType grpNull)}
    || {!(_chuteClass isEqualType "")} || {!isClass (configFile >> "CfgVehicles" >> _chuteClass)}
    || {!(_chuteClass isKindOf "ParachuteBase")}
    || {!(_velocity isEqualType [])} || {count _velocity != 3}
    || {_velocity findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!(_due isEqualType 0)} || {!finite _due}
    || {!(_until isEqualType 0)} || {!finite _until} || {_due > _until}
    || {(_unit getVariable ["CBE_ParachuteDeploy",[]]) isNotEqualTo _receipt}) exitWith {false};
if (serverTime < _due) exitWith {
    if ((_unit getVariable ["CBE_ParachuteDeployQueued",[]]) isNotEqualTo _receipt) then {
        _unit setVariable ["CBE_ParachuteDeployQueued",+_receipt];
        [{
            params ["_unit","_receipt"];
            if (local _unit && {(_unit getVariable ["CBE_ParachuteDeployQueued",[]]) isEqualTo _receipt}) then {
                _unit setVariable ["CBE_ParachuteDeployQueued",nil];
            };
            [_unit,_receipt] call CBE_fnc_CortexParachuteDeploy;
        },[_unit,+_receipt],_due-serverTime] call CBA_fnc_waitAndExecute;
    };
    false
};
private _boarded=false;
isNil {
    if (!local _unit || {(_unit getVariable ["CBE_ParachuteDeploy",[]]) isNotEqualTo _receipt}) exitWith {};
    // Consume only our exact phase even when it has expired or a new controller won.
    _unit setVariable ["CBE_ParachuteDeploy",nil,true];
    _unit setVariable ["CBE_ParachuteDeployQueued",nil];
    private _reason="CANCELLED";
    if (serverTime >= _until) then {_reason="EXPIRED"};
    if (serverTime < _until && {alive _unit} && {!isPlayer _unit} && {vehicle _unit == _unit}
        && {group _unit == _group} && {!isTouchingGround _unit}
        && {simulationEnabled _unit} && {!isObjectHidden _unit}
        && {[_unit] call CBE_fnc_CortexCombatEffective}
        && {!([_unit] call CBE_fnc_CortexActorMoveReserved)}
        && {isNull remoteControlled _unit}
        && {isNull (_unit getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {([_unit] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
        && {(_unit getVariable ["CBE_ParachuteExitToken",""]) isEqualTo _token}) then {
        private _chute=createVehicle [_chuteClass,getPosATL _unit,[],0,"CAN_COLLIDE"];
        _chute setDir getDir _unit;
        _unit moveInDriver _chute;
        if (vehicle _unit == _chute) then {
            _chute setVelocity (_velocity vectorMultiply 0.5);
            _boarded=true;
            _reason="BOARDED";
        } else {
            _reason="BOARDING_FAILED";
            if (!isNull _chute && {local _chute} && {crew _chute isEqualTo []}) then {deleteVehicle _chute};
        };
    };
    _unit setVariable ["CBE_ParachuteDeployResult",[_reason,_token,serverTime],true];
};
_boarded
