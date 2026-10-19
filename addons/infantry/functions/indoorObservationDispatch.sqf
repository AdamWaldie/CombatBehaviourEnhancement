/*
 * Author: WaldoTheWarfighter
 * Purpose: Use an unknown-body clue to inspect nearby building positions without inventing an enemy.
 * Native INIT/PLANNING/REPLAN/BUSY work is not an idle actor available for this clue.
 * Locality/authority: Current group owner only. Existing indoor actor FSM owns all movement.
 * Repeat/JIP: One public clue with original twenty-second expiry and owner epoch; no replay on gain.
 * At most one bounded selection per eight seconds, four nearby buildings and sixteen squad actors.
 * At most two investigators use the existing per-group indoor actor limit. No permanent worker.
 * Arguments: group GROUP grpNull; state HASHMAP empty.
 * Return: NUMBER of admitted actors, 0..2; not physical entry or room clearance.
 * Current caller: CortexGroupTick CALM when no enemies or authored/group movement owns the group.
 * Example: private _count=[_group,_state] call CBE_fnc_IndoorObservationDispatch;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]]];
if (isNull _group || {!local _group}) exitWith {0};
private _clue=_group getVariable ["CBE_Danger_BuildingClue",[]];
if !(_clue isEqualType [] && {count _clue == 5}) exitWith {0};
_clue params ["_position","_observed","_expires","_witness","_epoch"];
private _vector={_this isEqualType [] && {count _this == 3}
    && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
private _valid=_position call _vector && {_observed isEqualType 0} && {finite _observed}
    && {_expires isEqualType 0} && {finite _expires} && {_expires > _observed}
    && {_expires <= _observed+20} && {serverTime >= _observed} && {serverTime < _expires}
    && {_witness isEqualType objNull} && {!isNull _witness} && {group _witness == _group}
    && {local _witness} && {[_witness] call CBE_fnc_CortexCombatEffective}
    && {_epoch isEqualType 0} && {finite _epoch}
    && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])};
if (!_valid) exitWith {
    if ((_group getVariable ["CBE_Danger_BuildingClue",[]]) isEqualTo _clue) then {_group setVariable ["CBE_Danger_BuildingClue",nil,true]};
    0
};
if ([_state,"bodyBuilding"] call CBE_fnc_CortexCooldown
    || {!([_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_Investigate_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_Assault_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {behaviour leader _group in ["STEALTH","CARELESS"]}
    || {combatMode _group in ["BLUE","GREEN"]}
    || {leader _group distance2D _position > 100}) exitWith {0};
private _actors=((units _group) select [0,16]) select {
    local _x && {!isPlayer _x} && {_x != leader _group} && {isNull objectParent _x}
        && {[_x] call CBE_fnc_CortexCombatEffective} && {_x distance2D _position <= 50}
        && {currentCommand _x == ""} && {!(getUnitState _x in ["INIT","PLANNING","REPLAN","BUSY"])}
        && {isNull getAttackTarget _x} && {isNull assignedTarget _x}
        && {serverTime >= (_x getVariable ["CBE_IndoorActor_Cooldown",-1])}
        && {(_x getVariable ["CBE_IndoorActor_Order",[]]) isEqualTo []}
        && {isNull remoteControlled _x}
        && {[_x] call CBE_fnc_IndoorActorGroupAvailable}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
};
if (_actors isEqualTo []) exitWith {0};
[_state,"bodyBuilding",8] call CBE_fnc_CortexCooldown;
// Static navigation positions are candidates, not hostile occupancy or accessibility proof.
// Event altitude need not be guessed: choose a real low-floor candidate in absolute ASL.
private _buildings=nearestObjects [_position,["House"],15,true];
private _admitted=0;
{
    if (_admitted > 0 || {serverTime >= _expires}) exitWith {};
    private _house=_x;
    private _nodes=if (alive _house) then {_house buildingPos -1} else {[]};
    if (count _nodes > 0 && {count _nodes <= 512}) then {
        private _ranked=[];
        {if (_x call _vector) then {_ranked pushBack [((AGLToASL _x) select 2),_x distance2D _position,_forEachIndex]}} forEach _nodes;
        _ranked sort true;
        if (_ranked isNotEqualTo []) then {
            private _belief=+(_nodes select ((_ranked select 0) select 2));
            private _rankedActors=[];
            {_rankedActors pushBack [_x distance2D _belief,_forEachIndex]} forEach _actors;
            _rankedActors sort true;
            {
                if (_admitted >= 2 || {serverTime >= _expires}
                    || {(_group getVariable ["CBE_Danger_BuildingClue",[]]) isNotEqualTo _clue}) exitWith {};
                private _actor=_actors select (_x select 1);
                if (currentCommand _actor == "" && {isNull getAttackTarget _actor} && {isNull assignedTarget _actor}) then {
                    if (["START",_actor,createHashMapFromArray [["building",_house],
                        ["belief",[+_belief,serverTime]],["deadline",_expires],["observationOnly",true]]] call CBE_fnc_IndoorActorOperation) then {_admitted=_admitted+1};
                };
            } forEach (_rankedActors select [0,2]);
        };
    };
} forEach (_buildings select [0,4]);
if (_admitted > 0 && {(_group getVariable ["CBE_Danger_BuildingClue",[]]) isEqualTo _clue}) then {
    _group setVariable ["CBE_Danger_BuildingClue",nil,true];
};
_admitted
