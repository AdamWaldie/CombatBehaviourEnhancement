/*
 * Author: WaldoTheWarfighter
 * Purpose: Promote one recent, engine-confirmed hostile belief inside a usable building into
 * a natural WAIT clearance operation without replacing explicit orders or manufacturing knowledge.
 * Locality / Authority: Runs only on the local group owner during the bounded CONTACT decision.
 * It uses the stored native believed position, never the hostile's current world position,
 * and checks at most three recent contacts. Natural admission requests four actually eligible
 * actors from the executor; nominal headcount cannot satisfy that threshold.
 * The common building operation remains the sole
 * movement owner. Believed inclusion/roof geometry is not proof an enemy remains in that house.
 * Repeat/JIP: A per-group cooldown bounds failed topology and executor admission checks. An accepted clear publishes its
 * normal durable order and is reconstructed by the new owner after locality migration.
 * Arguments: 0: group <GROUP>; 1: group state <HASHMAP>; 2: Cortex knowledge records <ARRAY>.
 * Return Value: Boolean - true only when a physical building-clear operation was started.
 * Current callers: WAIT_fnc_CortexGroupTick before open-ground tactical movement selection.
 * Example: private _started=[_group,_state,_enemies] call WAIT_fnc_CortexBuildingContact;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_enemies",[],[[]]]
];
if (isNull _group || {!local _group} || {_enemies isEqualTo []}) exitWith {false};
if (!([_group,"WAIT_AIPass_BuildingCombat_Enable",true] call WAIT_fnc_CortexFeatureEnabled)
    || {!([_group,"WAIT_AIPass_Assault_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {_group getVariable ["WAIT_AIPass_ClearBuilding",false]}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld}
    || {[_state,"buildingCombat"] call WAIT_fnc_CortexCooldown}) exitWith {false};

private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation > 0) exitWith {false};
private _range=missionNamespace getVariable ["WAIT_AIPass_BuildingCombat_Range",100];
private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _anchor) then {_anchor=leader _group};
if (isNull _anchor) exitWith {false};
private _capable=(units _group) select {
    [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {isNull objectParent _x} && {simulationEnabled _x} && {!isObjectHidden _x}
};
// A natural entry needs a viable clearing pair plus exterior/reserve strength. Explicit CLEAR
// orders retain their existing executor minimum for mission-authored special cases.
if (count _capable < 4) exitWith {false};

private _records=_enemies select {
    private _enemy=_x param [0,objNull,[objNull]];
    private _belief=_x param [1,[],[[]]];
    private _age=_x param [2,1e6,[0]];
    count _belief == 3 && {_belief findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {finite _age} && {_age >= 0}
        && {!isNull _enemy} && {alive _enemy} && {isNull objectParent _enemy}
        && {(_x param [2,1e6,[0]]) <= 5}
        && {(_x param [3,1e6,[0]]) <= _range}
};
if (_records isEqualTo []) exitWith {false};
if (count _records > 3) then {_records resize 3};
private _enemy=objNull;
private _building=objNull;
private _contactBelief=[];
// Nearest-building alone also returns houses beside an outdoor actor. Check at most three fresh
// beliefs and require model-bound inclusion plus overhead geometry from that same building.
// Never query an enemy's live transform after the knowledge snapshot was made.
// The strict bound prevents a crowded contact from multiplying geometry work per group tick.
{
    if (!isNull _building) exitWith {};
    private _candidateEnemy=_x select 0;
    private _candidatePosition=+(_x select 1);
    private _candidateBuilding=nearestBuilding _candidatePosition;
    if (!isNull _candidateBuilding && {(_candidateBuilding buildingPos -1) isNotEqualTo []}) then {
        private _bounds=boundingBoxReal _candidateBuilding;
        private _minimum=_bounds param [0,[0,0,0]];
        private _maximum=_bounds param [1,[0,0,0]];
        private _modelPosition=_candidateBuilding worldToModelVisual _candidatePosition;
        private _insideBounds=(_modelPosition select 0) >= ((_minimum select 0)-1)
            && {(_modelPosition select 0) <= ((_maximum select 0)+1)}
            && {(_modelPosition select 1) >= ((_minimum select 1)-1)}
            && {(_modelPosition select 1) <= ((_maximum select 1)+1)}
            && {(_modelPosition select 2) >= ((_minimum select 2)-1)}
            && {(_modelPosition select 2) <= ((_maximum select 2)+1)};
        if (_insideBounds) then {
            private _origin=AGLToASL _candidatePosition;
            private _roofHits=lineIntersectsSurfaces [
                _origin vectorAdd [0,0,0.4],_origin vectorAdd [0,0,20],_candidateEnemy,objNull,true,4,"GEOM","NONE"
            ];
            if (_roofHits findIf {(_x select 2) == _candidateBuilding || {(_x select 3) == _candidateBuilding}} >= 0) then {
                _enemy=_candidateEnemy;
                _building=_candidateBuilding;
                _contactBelief=[+_candidatePosition,serverTime-(_x select 2)];
            };
        };
    };
} forEach _records;
if (isNull _building) exitWith {
    [_state,"buildingCombat",8] call WAIT_fnc_CortexCooldown;
    false
};

private _accepted=[_group,_building,createHashMapFromArray [["preserveBrain",true],["minimumActors",4],["contact",_enemy],["contactBelief",_contactBelief]]] call WAIT_fnc_CortexClearBuilding;
if (_accepted) then {
    _state set ["buildingContact",[_building,_enemy,serverTime]];
    [_state,"buildingCombat",60] call WAIT_fnc_CortexCooldown;
} else {
    // Eligibility may change after the cheap strength check. Avoid repeating the same
    // building geometry/admission work every decision callback while actors stay protected.
    [_state,"buildingCombat",8] call WAIT_fnc_CortexCooldown;
};
_accepted
