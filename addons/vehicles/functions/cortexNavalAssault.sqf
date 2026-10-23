/*
 * Author: WaldoTheWarfighter
 * Delivers AI infantry from a boat with one finite, shallow-water approach and dry-ground egress.
 *
 * The crew uses only enemies its group already knows about. One bounded candidate pass compares
 * dry, gently sloped shore points around that contact with adjacent shallow-water landing and
 * approach points. The ordinary Arma driver follows one temporary MOVE waypoint; CBE never uses
 * setDriveOnPath, teleport, repair, unflip or a global group/unit scan. Crew and operating gunners
 * remain aboard. A separate passenger group owns and unloads only its members, then receives one
 * finite dry-ground egress. For a legacy combined crew/passenger group, cargo receives short
 * individual egress moves so the boat group is never assigned a land waypoint.
 *
 * Player, Zeus, specialist and neutral external-control ownership is respected through the common takeover
 * boundary and movement lease. Zeus input releases the operation through
 * normal eligibility cleanup. Casualties simply reduce the surviving landing element; no readiness
 * barrier waits for a missing soldier.
 * Locality/authority: runs only inside the existing machine-local Cortex group job. Boat speed is
 * changed only where the boat is local. The tokenized plan is public so independently owned
 * passenger groups and a replacement owner can continue or release it.
 * Repeat/JIP: one token and deadline bound every approach. Refused operation/waypoint admission
 * publishes no moving role; draft generations/leases retire before returning. Passenger and crew
 * continuation stop at the outer action boundary when operation creation refuses.
 * Expired local/durable/boat-plan episodes retire before replanning; expiry is never landing
 * success. Completion requires the disembark phase and no living cargo. New infantry delivery
 * requires living cargo in at most64 observed crew rows; empty gunboats retain native combat. Completion, expiry, a closed feature
 * gate, external ownership and Zeus cleanup all restore exact speed and remove only CBE orders.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: Cortex state <HASHMAP>
 * 2: known enemies <ARRAY> from CortexKnowledge
 *
 * Return Value:
 * Boolean - true while this naval operation owns or intentionally holds group movement
 *
 * Current caller: CortexGroupTick.
 *
 * Example:
 * private _owned=[_group,_state,_enemies] call CBE_fnc_CortexNavalAssault;
 * Result: an eligible boat approaches a usable shore and its passenger squad lands without a new poller.
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_enemies",[],[[]]]
];
if (isNull _group || {!local _group}) exitWith {false};
private _enabled=[_group,"CBE_AIPass_NavalAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled;
if (!_enabled) exitWith {
    if ((_state getOrDefault ["navalOperation",[]]) isNotEqualTo []
        || {(_group getVariable ["CBE_Cortex_NavalOperation",[]]) isNotEqualTo []}) then {
        [_group,_state] call CBE_fnc_CortexNavalRelease
    };
    false
};

private _operation=_state getOrDefault ["navalOperation",[]];
// Local state belongs to the old owner. Reconstruct the semantic episode from the public token;
// never replay its previous waypoint or extend its original deadline.
if (_operation isEqualTo []) then {
    private _durable=_group getVariable ["CBE_Cortex_NavalOperation",[]];
    if (count _durable == 5) then {
        _operation=+_durable;
        _state set ["navalOperation",_operation];
    };
};
// Expired local and reconstructed episodes retire before any new planning or crew command.
// An inner exit during reconstruction would leave the outer action free to restart the route.
if (count _operation == 5 && {serverTime >= (_operation select 4)}) exitWith {
    [_group,_state,"EXPIRED"] call CBE_fnc_CortexNavalRelease;
    false
};
// A passenger landing, boat approach or disembark must yield as a whole when a curator,
// player or specialist controller takes either group. Release removes only CBE-owned state.
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {
    if (_operation isNotEqualTo []) then {[_group,_state,"EXTERNAL"] call CBE_fnc_CortexNavalRelease};
    false
};
// Continue a passenger landing after the last soldier has physically left the boat.
if (count _operation >= 4 && {(_operation param [2,""]) == "PASSENGER"}) exitWith {
    _operation params ["_token","_boat","_role","_egress","_expires"];
    private _survivors=(units _group) select {alive _x && {[_x] call CBE_fnc_CortexCombatEffective}};
    private _aboard=_survivors select {vehicle _x == _boat};
    if (serverTime >= _expires || {_survivors isEqualTo []}) exitWith {
        [_group,_state] call CBE_fnc_CortexNavalRelease;
        false
    };
    if (_aboard isNotEqualTo []) exitWith {true};
    // Passenger egress is a separate operation from the boat crew's approach.  A passenger
    // locality handover must therefore never replace the crew's movement generation.
    private _landingGeneration=_state getOrDefault ["navalOperationGeneration",-1];
    if (_landingGeneration < 0) then {
        private _landingOperation=[_group,"NAVAL_LANDING",_egress,_survivors,[_egress],"EGRESS"] call CBE_fnc_OperationStart;
        if (count _landingOperation > 0) then {
            _landingGeneration=_landingOperation get "generation";
            _state set ["navalOperationGeneration",_landingGeneration];
        };
    };
    if (_landingGeneration < 0) exitWith {
        [_group,_state,"OPERATION_REFUSED"] call CBE_fnc_CortexNavalRelease;
        false
    };
    private _movement=_state getOrDefault ["movementLease",[]];
    private _egressReady=(_movement param [0,""]) == "NAVAL_LANDING";
    if (!_egressReady) then {
        if ([_group,"NAVAL_LANDING",true,_expires] call CBE_fnc_CortexOwnershipLease) then {
            private _egressWaypoint=[_group,_egress,25,"MOVE",_landingGeneration] call CBE_fnc_CortexGroupMove;
            if (!isNull (_egressWaypoint param [0,grpNull,[grpNull]]) && {(_egressWaypoint param [1,-1,[0]]) >= 0}) then {
                _state set ["movementLease",["NAVAL_LANDING",time+((_expires-serverTime) max 1)]];
                _group setVariable ["CBE_Cortex_NavalStatus",["EGRESS",_egress,_expires],true];
                _egressReady=true;
            } else {
                [_group,"NAVAL_LANDING",false] call CBE_fnc_CortexOwnershipLease;
            };
        };
    };
    if (!_egressReady) exitWith {
        [_group,_state,"MOVEMENT_REJECTED"] call CBE_fnc_CortexNavalRelease;
        false
    };
    if ((leader _group distance2D _egress) <= 30) exitWith {
        [_group,_state,"COMPLETE"] call CBE_fnc_CortexNavalRelease;
        false
    };
    true
};

private _ships=[];
{
    private _vehicle=vehicle _x;
    if (_vehicle != _x && {_vehicle isKindOf "Ship"} && {!(_vehicle in _ships)}) then {_ships pushBack _vehicle};
} forEach units _group;
if (_ships isEqualTo []) exitWith {false};
private _boat=_ships select 0;
private _commandsBoat=effectiveCommander _boat in units _group;

if (!_commandsBoat) exitWith {
    private _plan=_boat getVariable ["CBE_Cortex_NavalPlan",[]];
    if (count _plan != 9 || {serverTime >= (_plan select 7)}) exitWith {false};
    _plan params ["_token","_crewGroup","_plannedBoat","_approach","_landing","_shore","_egress","_expires","_phase"];
    if (_plannedBoat != _boat || {isNull _crewGroup} || {side _crewGroup != side _group}) exitWith {false};
    if (_phase == "APPROACH") exitWith {
        _group setVariable ["CBE_Cortex_NavalStatus",["EMBARKED",_landing,_expires],true];
        true
    };
    private _cargo=(fullCrew [_boat,"",false]) select {
        private _unit=_x select 0;
        private _seat=_x select 1;
        alive _unit && {group _unit == _group} && {_seat == "cargo" || {_seat == "turret" && {_x select 4}}}
    };
    {
        private _unit=_x select 0;
        [_unit] orderGetIn false;
        unassignVehicle _unit;
        doGetOut _unit;
    } forEach _cargo;
    private _passengerOperation=[_token,_boat,"PASSENGER",_egress,_expires];
    _state set ["navalOperation",_passengerOperation];
    _group setVariable ["CBE_Cortex_NavalOperation",_passengerOperation,true];
    _group setVariable ["CBE_Cortex_NavalStatus",["DISEMBARK",_shore,_expires],true];
    true
};

// Boat crew: adopt or create the single public plan.
private _plan=_boat getVariable ["CBE_Cortex_NavalPlan",[]];
if (count _plan == 9 && {(_plan select 1) == _group} && {(_plan select 2) == _boat}
    && {serverTime >= (_plan select 7)}) exitWith {
    _state set ["navalOperation",[_plan select 0,_boat,"CREW",_plan select 6,_plan select 7]];
    [_group,_state,"EXPIRED"] call CBE_fnc_CortexNavalRelease;
    false
};
if (count _plan == 9 && {(_plan select 8) == "LANDED"} && {serverTime < (_plan select 7)}) exitWith {false};
if (count _plan == 9 && {(_plan select 1) == _group} && {serverTime < (_plan select 7)}) exitWith {
    _plan params ["_token","_crewGroup","_plannedBoat","_approach","_landing","_shore","_egress","_expires","_phase"];
    private _crewOperation=[_token,_boat,"CREW",_egress,_expires];
    _state set ["navalOperation",_crewOperation];
    _group setVariable ["CBE_Cortex_NavalOperation",_crewOperation,true];
    private _crewGeneration=_state getOrDefault ["navalOperationGeneration",-1];
    if (_crewGeneration < 0) then {
        private _crewOperationRecord=[_group,"NAVAL_ASSAULT",_egress,[],[_approach,_landing,_egress],"APPROACH"] call CBE_fnc_OperationStart;
        if (count _crewOperationRecord > 0) then {
            _crewGeneration=_crewOperationRecord get "generation";
            _state set ["navalOperationGeneration",_crewGeneration];
        };
    };
    if (_crewGeneration < 0) exitWith {
        [_group,_state,"OPERATION_REFUSED"] call CBE_fnc_CortexNavalRelease;
        false
    };
    if (_phase == "APPROACH" && {(_boat distance2D _landing) <= 45}) then {
        if (local _boat) then {
            if ((_boat getVariable ["CBE_Cortex_NavalForcedSpeed",[]]) isEqualTo []) then {
                _boat setVariable ["CBE_Cortex_NavalForcedSpeed",[getForcedSpeed _boat,0]];
            };
            _boat forceSpeed 0;
        };
        _plan set [8,"DISEMBARK"];
        _boat setVariable ["CBE_Cortex_NavalPlan",_plan,true];
        _group setVariable ["CBE_Cortex_NavalStatus",["DISEMBARK",_shore,_expires],true];
    };
    private _remaining=(fullCrew [_boat,"",false]) findIf {
        private _unit=_x select 0;
        private _seat=_x select 1;
        alive _unit && {_unit != effectiveCommander _boat}
            && {_seat == "cargo" || {_seat == "turret" && {_x select 4}}}
    };
    if ((_plan select 8) == "DISEMBARK") then {
        // Combined crew/cargo groups cannot receive a land waypoint without beaching their boat.
        {
            private _unit=_x select 0;
            if (group _unit == _group) then {
                [_unit] orderGetIn false;
                unassignVehicle _unit;
                doGetOut _unit;
                _unit doMove (_egress getPos [4+(_forEachIndex mod 4)*3,90+_forEachIndex*35]);
            };
        } forEach ((fullCrew [_boat,"",false]) select {
            private _seat=_x select 1;
            _seat == "cargo" || {_seat == "turret" && {_x select 4}}
        });
    };
    if ((_plan select 8) == "DISEMBARK" && {_remaining < 0}) then {
        if (local _boat) then {
            private _saved=_boat getVariable ["CBE_Cortex_NavalForcedSpeed",[]];
            private _ownedStop=_saved param [1,-2];
            if (_saved isNotEqualTo [] && {_ownedStop >= 0}
                && {abs ((getForcedSpeed _boat)-_ownedStop) <= 0.1}
                && {!([_group] call CBE_fnc_CortexExternalTakeover)}) then {
                _boat forceSpeed (_saved param [0,-1]);
            };
            _boat setVariable ["CBE_Cortex_NavalForcedSpeed",nil];
        };
        [_group,_state,"COMPLETE"] call CBE_fnc_CortexNavalRelease;
        _plan set [8,"LANDED"];
        _plan set [7,serverTime+45];
        _boat setVariable ["CBE_Cortex_NavalPlan",_plan,true];
        _state deleteAt "navalOperation";
        _group setVariable ["CBE_Cortex_NavalOperation",nil,true];
        _group setVariable ["CBE_Cortex_NavalStatus",["COMPLETE",_shore,serverTime+45],true];
        false
    } else {
        true
    }
};

if (_enemies isEqualTo [] || {!surfaceIsWater (getPosATL _boat)}) exitWith {false};
// Infantry delivery requires living landing cargo; gunboat combat is a separate behaviour.
private _landingCrew=fullCrew [_boat,"",false];
if (count _landingCrew > 64 || {_landingCrew findIf {
    private _passenger=_x select 0;
    alive _passenger && {(_x select 1) == "cargo" || {(_x select 1) == "turret" && {_x select 4}}}
} < 0}) exitWith {false};
private _contact=_enemies select 0;
private _target=_contact select 0;
private _targetPos=_contact select 1;
private _distance=_boat distance2D _targetPos;
if (isNull _target || {surfaceIsWater _targetPos} || {_distance < 120} || {_distance > 1800}) exitWith {false};
private _towardBoat=_targetPos getDir _boat;
private _candidates=[];
{
    private _bearing=_towardBoat+_x;
    {
        private _shore=_targetPos getPos [_x,_bearing];
        private _landing=_shore getPos [35,_shore getDir _boat];
        private _approach=_landing getPos [100,_landing getDir _boat];
        private _normal=surfaceNormal _shore;
        if (!surfaceIsWater _shore && {surfaceIsWater _landing} && {surfaceIsWater _approach}
            && {(_normal select 2) >= 0.7}) then {
            private _egress=_shore getPos [45,_boat getDir _targetPos];
            if (!surfaceIsWater _egress && {((surfaceNormal _egress) select 2) >= 0.65}) then {
                _candidates pushBack [(_boat distance2D _approach)+(_shore distance2D _targetPos)*0.35,_approach,_landing,_shore,_egress];
            };
        };
    } forEach [100,150,210,280];
} forEach [0,-25,25,-50,50,180];
if (_candidates isEqualTo []) exitWith {false};
_candidates sort true;
(_candidates select 0) params ["_score","_approach","_landing","_shore","_egress"];
private _expires=serverTime+240;
if !([_group,"NAVAL_ASSAULT",true,_expires] call CBE_fnc_CortexOwnershipLease) exitWith {false};
private _crewOperationRecord=[_group,"NAVAL_ASSAULT",_egress,[],[_approach,_landing,_egress],"APPROACH"] call CBE_fnc_OperationStart;
if (count _crewOperationRecord == 0) exitWith {
    [_group,"NAVAL_ASSAULT",false] call CBE_fnc_CortexOwnershipLease;
    false
};
private _token=format ["NAVAL:%1:%2:%3",netId _boat,clientOwner,round (serverTime*10)];
private _crewGeneration=_crewOperationRecord get "generation";
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {
    [_group,_crewGeneration,"EXTERNAL"] call CBE_fnc_OperationCancel;
    [_group,"NAVAL_ASSAULT",false] call CBE_fnc_CortexOwnershipLease;
    false
};
private _crewWaypoint=[_group,_landing,20,"MOVE",_crewGeneration] call CBE_fnc_CortexGroupMove;
if (isNull (_crewWaypoint param [0,grpNull,[grpNull]]) || {(_crewWaypoint param [1,-1,[0]]) < 0}) exitWith {
    [_group,_crewGeneration,"INCOMPLETE","MOVEMENT_REJECTED"] call CBE_fnc_OperationRelease;
    [_group,"NAVAL_ASSAULT",false] call CBE_fnc_CortexOwnershipLease;
    false
};
_state set ["movementLease",["NAVAL_ASSAULT",time+240]];
_state set ["navalOperationGeneration",_crewGeneration];
private _crewOperation=[_token,_boat,"CREW",_egress,_expires];
_state set ["navalOperation",_crewOperation];
_group setVariable ["CBE_Cortex_NavalOperation",_crewOperation,true];
_boat setVariable ["CBE_Cortex_NavalPlan",[_token,_group,_boat,_approach,_landing,_shore,_egress,_expires,"APPROACH"],true];
_group setVariable ["CBE_Cortex_NavalStatus",["APPROACH",_landing,_expires],true];
true
