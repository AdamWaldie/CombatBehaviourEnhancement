/*
 * Author: WaldoTheWarfighter
 * Purpose: Preserve one useful armed vehicle after its primary gunner is lost by assigning an
 * eligible existing commander to the empty gunner role during a confirmed danger generation.
 * Detection or fresh incoming-fire danger may trigger the same finite request. An immobilised
 * platform can retain useful firepower; mobility is not required for an internal seat change.
 * The caller excludes current abandonment cases. Queued ACE care forbids reassignment.
 * Locality / Authority: Runs on the current group owner. It changes only a local AI commander's
 * assigned vehicle role and asks the engine to perform an internal seat change. Zeus, player,
 * specialist, convoy and authored task ownership always win.
 * Repeat/JIP: Finite and generation-owned. The caller records every attempted generation, so a
 * Actor reservations, direct remote control and specialist ownership veto both seat commands.
 * Rejected or accepted recovery cannot churn assignments. A new owner evaluates only later danger.
 * The candidate must still be assigned to the actual occupied commander turret; a newer
 * same-vehicle role or explicit unassignment refuses before either seat command.
 * A living assigned incoming gunner retains the seat; explicit STOP, hidden/suspended crew
 * and disabled movement/pathfinding forbid reassignment. Seat vacancy alone is not authority.
 * Arguments: 0: group <GROUP>, grpNull; 1: vehicle <OBJECT>, objNull; 2: hostile <OBJECT>, objNull;
 * 3: cause <STRING>, ""; 4: danger generation <NUMBER>, -1.
 * Return Value: Boolean - true only when a seat-change request was issued.
 * Current callers: CBE_fnc_CortexVehicles exact-platform danger response.
 * Example: [group driver cursorObject,cursorObject,objNull,"DETECTED",4] call CBE_fnc_CortexVehicleCrewRecover;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_vehicle",objNull,[objNull]],
    ["_hostile",objNull,[objNull]],
    ["_cause","",[""]],
    ["_generation",-1,[0]]
];
private _reject={
    params ["_reason"];
    if (!isNull _group && {local _group}) then {
        private _commander=if (isNull _vehicle) then {objNull} else {commander _vehicle};
        _group setVariable ["CBE_Danger_CrewRecoveryDecision",[serverTime,clientOwner,_generation,_reason,_cause,
            if (isNull _vehicle) then {-1} else {speed _vehicle},
            if (isNull _commander) then {""} else {currentCommand _commander},
            if (isNull _commander || {isNull _hostile}) then {-1} else {_commander knowsAbout _hostile}]];
    };
    false
};
if (isNull _group || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {_generation < 0} || {!(_cause in ["DETECTED","HIT","EXPLOSION","SUPPRESSED","GUNFIRE"])}
    || {!alive _vehicle} || {!someAmmo _vehicle}
    || {abs speed _vehicle >= 20} || {_vehicle getVariable ["CBE_Convoy_Active",false]}
    || {!([_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {[_group] call CBE_fnc_CortexExternalTakeover}
    || {[_group] call CBE_fnc_CortexZeusHeld}) exitWith {["PLATFORM_OR_OWNERSHIP"] call _reject};
if (!isNull gunner _vehicle && {alive gunner _vehicle}) exitWith {["GUNNER_ALIVE"] call _reject};
if (isNull _hostile || {!alive _hostile}
    || {(side _group) getFriend (side _hostile) >= 0.6}) exitWith {["HOSTILE_INVALID"] call _reject};

// A dedicated commander may change seats without sacrificing steering. A driver is deliberately
// never reassigned: preserving mobility and an authored route is more valuable than recovering a
// weapon, and CBE must not manufacture a replacement crew member.
private _candidate=commander _vehicle;
if (isNull _candidate || {!alive _candidate} || {!local _candidate} || {isPlayer _candidate}
    || {group _candidate != _group} || {_candidate == driver _vehicle}
    || {!([_candidate] call CBE_fnc_CortexCombatEffective)}) exitWith {["COMMANDER_INELIGIBLE"] call _reject};
if ([_candidate] call CBE_fnc_CortexActorMoveReserved
    || {!isNull remoteControlled _candidate}
    || {!isNull (_candidate getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    || {([_candidate] call CBE_fnc_CortexExternalOwner) != ""}
    || {[_candidate] call CBE_fnc_CompatibilityExternalControl}) exitWith {["ACTOR_OWNERSHIP"] call _reject};
private _command=toUpperANSI currentCommand _candidate;
if (fleeing _candidate || {(_candidate getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {_command in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {["NATIVE_TASK"] call _reject};
if (_command == "STOP" || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!simulationEnabled _candidate} || {isObjectHidden _candidate}
    || {!(_candidate checkAIFeature "MOVE")} || {!(_candidate checkAIFeature "PATH")}
    || {vehicle _candidate != _vehicle}
    || {!(assignedVehicle _candidate in [objNull,_vehicle])}) exitWith {["CREW_TASK_OR_SIMULATION"] call _reject};
// Occupancy is not current seat intent. An assigned driver/cargo/other turret or an
// explicit unassignment must not be converted into a gunner request merely because
// the commander has not physically moved yet. Resolve the actual commander path;
// do not assume a tank-specific [0,0] turret layout.
private _commanderSeat=(fullCrew [_vehicle,"commander",false]) param [0,[]];
private _assignment=assignedVehicleRole _candidate;
if (assignedVehicle _candidate != _vehicle || {count _commanderSeat < 6}
    || {(_commanderSeat select 0) != _candidate} || {(_commanderSeat select 5) != _candidate}
    || {count _assignment != 2} || {toLowerANSI (_assignment select 0) != "turret"}
    || {(_assignment select 1) isNotEqualTo (_commanderSeat select 3)}) exitWith {
    ["COMMANDER_ASSIGNMENT_CHANGED"] call _reject
};
// Empty seats can still belong to a living crew member ordered back aboard.
// Read only the primary gunner role; auxiliary turret assignments are independent.
private _gunnerSeat=(fullCrew [_vehicle,"gunner",true]) param [0,[]];
if (_gunnerSeat isEqualTo []) exitWith {["NO_GUNNER_SEAT"] call _reject};
private _assignedGunner=_gunnerSeat param [5,objNull];
if (!isNull _assignedGunner && {alive _assignedGunner} && {_assignedGunner != _candidate}) exitWith {
    ["GUNNER_ASSIGNED"] call _reject
};
if (_candidate knowsAbout _hostile <= 0) exitWith {["NO_NATIVE_KNOWLEDGE"] call _reject};

_candidate assignAsGunner _vehicle;
_candidate action ["MoveToGunner",_vehicle];
_vehicle setVariable ["CBE_Danger_CrewRecovery",[_generation,_candidate,_hostile,serverTime],true];
true
