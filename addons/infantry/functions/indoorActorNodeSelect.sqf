/*
 * Author: WaldoTheWarfighter
 * Geometry identity includes object scale: rescaling invalidates cached selection and active work.
 * Purpose: Plan one actor's indoor observation destination near a supplied native contact belief.
 * Locality/authority: Read-only world observation on the actor/group owner; only the optional
 * caller-owned search HashMap is updated. No movement or access is granted.
 * Repeat/JIP: At most 512 native positions ranked and three roof queries per call. A supplied
 * operation-local search retains up to twelve tested nodes across callbacks, bound to the
 * exact actor/building transform/belief. It does not mark accessibility, visits or clearance.
 * Reservation, failed-node and body separation use absolute ASL coordinates. Native
 * outputs remain ATL; terrain-cell differences cannot alias distinct floors.
 * Current positions of at most16 living, simulated, visible, dismounted squadmates exclude
 * same-floor body overlap. No enemy/other-group scan or persistent occupancy cache is used.
 * Up to four actor-local failed-node observations temporarily exclude matching destinations only
 * while the original owner epoch, building transform and sixty-second expiry remain valid.
 * A caller must retain the building transform, recheck authority and observe physical arrival.
 * Arguments: 0 actor <OBJECT>, objNull; 1 building <OBJECT>, objNull;
 * 2 believed ATL position <ARRAY>, []; 3 reserved ATL destinations <ARRAY>, [];
 * 4 original observation clue <ARRAY,[]> enables same-episode physical-visit preference.
 * 5 optional caller-owned search <HASHMAP,empty>; pending BOOL and probed ASL nodes are outputs.
 * 6 optional finite SEARCH memory <ARRAY,[]> shares confirmed same-episode visits within the
 * same sixteen-destination budget. Valid memory permits lower-floor-first multi-storey selection;
 * live contact/body-clue selection retains its belief-floor band. Neither grants access or clearance.
 * Visit preferences share the sixteen-destination exclusion budget after live reservations;
 * they never affect known-contact work or add roof rays.
 * 7 defensive BOOL false restricts candidates to an eight-metre same-floor improvement
 * toward believed threat geometry, retaining all roof/occupancy/failure checks.
 * Defensive selection additionally requires a blocked current lane and a usable prospective
 * FIRE/GEOM lane at the actor's current eye height. It adds at most four surface queries
 * per call (one current lane, three candidates), only in defensive mode. This is position
 * planning toward a native belief, never permission to fire or proof of accessibility.
 * 8 defensiveOrigin ASL ARRAY [] is mandatory for defensive selection and binds the
 * original radius/floor across retries; it is never replaced by the actor's new position.
 * Return: ARRAY - one native ATL position, or [] for invalid, occupied or unroofed candidates.
 * Hidden buildings refuse before node/roof observation; authored mission visibility remains authoritative.
 * Navigation metadata and roof ownership do not establish accessibility or a safe room.
 * Current callers: CBE_fnc_IndoorActorOperation SELECT phase, including natural dispatch; DangerRefugeSelect fallback for flight and ordinary danger cover.
 * Example: private _node=[soldier1,house1,[100,100,2],[]] call CBE_fnc_IndoorActorNodeSelect;
 */
params [["_actor",objNull,[objNull]],["_building",objNull,[objNull]],
    ["_belief",[],[[]]],["_reserved",[],[[]]],["_clue",[],[[]]],
    ["_search",createHashMap,[createHashMap]],["_searchMemory",[],[[]]],["_defensive",false,[true]],["_defensiveOrigin",[],[[]]]];
_search set ["pending",false];
private _positionValid={
    _this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
if (isNull _actor || {!local _actor} || {!local group _actor}
    || {isNull _building} || {!alive _building} || {isObjectHidden _building} || {!(_belief call _positionValid)}
    || {count _reserved > 16} || {_defensive && {!(_defensiveOrigin call _positionValid)}}) exitWith {[]};
// Reject unknown reservations rather than sending a second actor to an unverified destination.
if (_reserved findIf {!(_x call _positionValid)} >= 0) exitWith {[]};
private _reservedASL=_reserved apply {AGLToASL _x};
private _failedNodes=[];
private _epoch=(group _actor) getVariable ["CBE_AIPass_Epoch",0];
private _transform=[getPosWorld _building,vectorDir _building,vectorUp _building,getObjectScale _building];
private _binding=[_actor,_building,_transform,+_belief,+_searchMemory,_defensive,+_defensiveOrigin];
private _previousBinding=_search getOrDefault ["binding",[]];
if (_previousBinding isNotEqualTo [] && {_previousBinding isNotEqualTo _binding}) exitWith {[]};
private _probed=_search getOrDefault ["probed",[]];
if (!(_probed isEqualType []) || {count _probed >= 12}
    || {_probed findIf {!(_x call _positionValid)} >= 0}) exitWith {[]};
_probed=+_probed;
_search set ["binding",_binding];
private _history=(group _actor) getVariable ["CBE_Danger_BuildingVisits",[]];
if (count _clue == 5 && {(_clue select 4) isEqualTo _epoch}
    && {(_clue select 2) isEqualType 0} && {finite (_clue select 2)} && {serverTime < (_clue select 2)}
    && {((group _actor) getVariable ["CBE_Danger_BuildingClue",[]]) isEqualTo _clue}
    && {_history isEqualType []} && {count _history == 2} && {(_history select 0) isEqualTo _clue}
    && {(_history select 1) isEqualType []}) then {
    {
        if (count _reservedASL >= 16) exitWith {};
        if (_x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualTo _building}
            && {(_x select 1) isEqualTo _transform} && {(_x select 2) call _positionValid}) then {
            _reservedASL pushBack (_x select 2);
        };
    } forEach ((_history select 1) select [0,16]);
};
// Search-memory visits share the same budget as live reservations and body-clue history.
private _searchAllFloors=false;
if (count _searchMemory == 4) then {
    private _memoryState=(group _actor) getVariable ["CBE_AIPass_State",createHashMap];
    private _memoryHistory=_memoryState getOrDefault ["searchBuildingVisits",[]];
    if ((_memoryState getOrDefault ["phase",""]) == "SEARCH"
        && {(_memoryState getOrDefault ["searchMemory",[]]) isEqualTo _searchMemory}
        && {(_searchMemory select 0) call _positionValid}
        && {(_searchMemory select 0) isEqualTo _belief}
        && {[1,2,3] findIf {!((_searchMemory select _x) isEqualType 0) || {!finite (_searchMemory select _x)}} < 0}
        && {(_searchMemory select 3) isEqualTo _epoch}
        && {serverTime >= (_searchMemory select 1)} && {serverTime < (_searchMemory select 2)}
        && {(_searchMemory select 2) > (_searchMemory select 1)}
        && {(_searchMemory select 2) <= (_searchMemory select 1)+120}
        && {(_searchMemory select 2) <= (_memoryState getOrDefault ["searchDeadline",-1])}) then {
        _searchAllFloors=true;
    };
    if (_searchAllFloors && {_memoryHistory isEqualType []} && {count _memoryHistory == 2}
        && {(_memoryHistory select 0) isEqualTo _searchMemory} && {(_memoryHistory select 1) isEqualType []}) then {
        {
            if (count _reservedASL >= 16) exitWith {};
            if (_x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualTo _building}
                && {(_x select 1) isEqualTo _transform} && {(_x select 2) call _positionValid}) then {
                _reservedASL pushBackUnique (_x select 2);
            };
        } forEach ((_memoryHistory select 1) select [0,16]);
    };
};
{
    if (_x isEqualType [] && {count _x == 5} && {(_x select 0) isEqualTo _building}
        && {(_x select 1) isEqualTo _transform} && {(_x select 2) call _positionValid}
        && {(_x select 3) isEqualType 0} && {finite (_x select 3)} && {serverTime < (_x select 3)}
        && {(_x select 4) isEqualTo _epoch}) then {_failedNodes pushBack (AGLToASL (_x select 2))};
} forEach ((_actor getVariable ["CBE_IndoorActor_NodeFailures",[]]) select [0,4]);
// A nearer room node can still face the same wall. Keep a defender at an already
// usable firing position; only screen alternatives when its present lane is blocked.
// Native belief is the endpoint, never a hidden target's exact pose. A surface within
// three metres of that belief can support near-face suppression, as in SuppressionAim.
private _laneTargetASL=(AGLToASL _belief) vectorAdd [0,0,1];
private _defensiveEyeHeight=0;
private _defensiveLaneUsable={
    params ["_from"];
    if (terrainIntersectASL [_from,_laneTargetASL]) exitWith {false};
    private _laneHits=lineIntersectsSurfaces [_from,_laneTargetASL,_actor,objNull,true,1,"FIRE","GEOM"];
    _laneHits isEqualTo [] || {private _laneHit=_laneHits select 0;
        !isNull (_laneHit select 2) && {(_laneHit select 0) vectorDistance _laneTargetASL <= 3}}
};
if (_defensive) then {
    _defensiveEyeHeight=(((eyePos _actor) select 2)-((getPosASL _actor) select 2)) max 0.6 min 1.8;
};
if (_defensive && {[eyePos _actor] call _defensiveLaneUsable}) exitWith {[]};
private _positions=_building buildingPos -1;
if (count _positions > 512) exitWith {[]};
private _bounds=boundingBoxReal _building;
private _low=_bounds select 0;
private _high=_bounds select 1;
private _beliefHeight=if (_defensive) then {_defensiveOrigin select 2} else {(AGLToASL _belief) select 2};
private _origin=if (_defensive) then {ASLToAGL _defensiveOrigin} else {getPosATL _actor};
// Reservation metadata does not include a teammate who is simply standing at a node.
// Sample only the existing bounded squad roster; never inspect unseen hostile positions.
private _bodies=[];
{
    if (_x != _actor && {alive _x} && {isNull objectParent _x}
        && {simulationEnabled _x} && {!isObjectHidden _x}) then {
        _bodies pushBack getPosASL _x;
    };
} forEach ((units group _actor) select [0,16]);
private _ranked=[];
{
    private _node=_x;
    if (_node call _positionValid) then {
        private _model=_building worldToModel _node;
        private _inside=(_model select 0) > (_low select 0) && {(_model select 0) < (_high select 0)}
            && {(_model select 1) > (_low select 1)} && {(_model select 1) < (_high select 1)}
            && {(_model select 2) >= (_low select 2)-0.5} && {(_model select 2) <= (_high select 2)};
        private _nodeASL=AGLToASL _node;
        private _height=_nodeASL select 2;
        if (_inside && {!_defensive || {_node distance2D _origin <= 8
            && {_node distance2D _origin >= 1.5}
            && {_node distance2D _belief < (_origin distance2D _belief)-0.8}}}
            && {_searchAllFloors || {abs (_height-_beliefHeight) <= 1.5}}
            && {_probed findIf {_x vectorDistance _nodeASL < 0.1} < 0}
            && {_reservedASL findIf {_x vectorDistance _nodeASL < 1.5} < 0}
            && {_bodies findIf {_x distance2D _nodeASL < 1.5 && {abs ((_x select 2)-_height) <= 1}} < 0}
            && {_failedNodes findIf {_x vectorDistance _nodeASL < 1.5} < 0}) then {
            // Position-only memory can continue upstairs after lower nodes were visited.
            // Live contact selection still ranks by believed horizontal proximity on its floor.
            // Whole-metre height is a preference, never a floor/accessibility classification.
            private _heightRank=if (_searchAllFloors) then {floor _height} else {0};
            _ranked pushBack [_heightRank,_node distance2D _belief,_node distance2D _origin,_forEachIndex];
        };
    };
} forEach _positions;
_ranked sort true;
private _selected=[];
private _roofTop=[_building] call CBE_fnc_BuildingRoofTop;
{
    if (_selected isNotEqualTo [] || {count _probed >= 12}) exitWith {};
    private _node=_positions select (_x select 3);
    private _asl=AGLToASL _node;
    _probed pushBack +_asl;
    private _hits=if (_roofTop > (_asl select 2)+0.4) then {
        lineIntersectsSurfaces [_asl vectorAdd [0,0,0.4],
            [_asl select 0,_asl select 1,_roofTop],_actor,objNull,true,1,"GEOM","NONE"]
    } else {[]};
    if (_hits isNotEqualTo []) then {
        private _hit=_hits select 0;
        if (((_hit select 2) == _building || {(_hit select 3) == _building})
            && {!_defensive || {[_asl vectorAdd [0,0,_defensiveEyeHeight]] call _defensiveLaneUsable}}) exitWith {
            _selected=+_node;
        };
    };
} forEach (_ranked select [0,3]);
_search set ["probed",_probed];
_search set ["pending",_selected isEqualTo [] && {count _ranked > 3} && {count _probed < 12}];
_selected
