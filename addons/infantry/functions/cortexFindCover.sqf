/*
 * Author: WaldoTheWarfighter
 * Finds a covered position near a point, on the far side of a solid object from a threat.
 *
 * Up to four posts per object share a sixteen-post budget across ten ranked objects.
 * Every original threat-away post keeps its ranked priority. Only after those fail, try
 * the closest protected-face post, then original lateral posts nominally2.25m either side.
 * The nearest face uses0.8m rear clearance and0.45m lateral end inset, in world metres;
 * it is a proposal, never proof of a firing position, walkable route or physical arrival.
 * Successful original searches do no extra post work or transforms.
 * Each alternate independently retains reservations, occupancy and screening; native access
 * and actual movement remain the caller's responsibility. No stance or movement is written.
 * The candidate sits outside the
 * object's rotated horizontal bounds on the side away from the threat, and it is accepted only if a
 * line-of-fire ray from the threat's eye height to the candidate's chest height is blocked. Candidates inside the object's bounds or under its roof are rejected. Trees, rocks, walls, fences, hides and buildings count;
 * bushes do not in default COVER mode (they conceal but do not stop rounds).
 * Explicit CONCEALMENT mode accepts visual screening only and never claims ballistic protection. The engine's `findCover` is not implemented in
 * Arma 3, so this is scripted.
 * Locality and authority: read-only; callable anywhere.
 *
 * Arguments:
 * 0: position <ARRAY> - ATL point to search around
 * 1: threat <ARRAY> - ATL position of the threat
 * 2: radius <NUMBER> - search radius in metres (optional, default: 12)
 * 3: reserved <ARRAY> - ATL positions already taken by squad-mates (optional, default: [])
 *
 * 4: group <GROUP> - optional grpNull, supplies per-group feature exclusions.
 * 5: screening mode <STRING, COVER>; CONCEALMENT tests visual screening instead of ballistic cover.
 * 6: intended actor <OBJECT, objNull>; only this actor is excluded from occupancy and geometry
 * rays. Other soldiers still block the post; the actor cannot count as its own cover.
 * Repeat/JIP: read-only; candidates are recalculated only when a caller requests a search.
 * Return Value:
 * Array - [screenedPosATL, found <BOOL>] for the selected mode; original position when none qualifies
 *
 * Example:
 * ([_boundPoint, _enemyPos, 12, _taken] call CBE_fnc_CortexFindCover) params ["_spot", "_found"];
 * Result: a nearby spot with solid cover between it and the enemy, if one exists.
 *
 * Current callers: CBE_fnc_CortexFlankStep, CBE_fnc_CortexGrenadeCheck, CBE_fnc_CortexAntiArmour CBE_fnc_DangerCoverStep, CBE_fnc_CortexCivilianReact and CBE_fnc_BuildingOperationStep.
 */

params [["_position", [], [[]]], ["_threat", [], [[]]], ["_radius", 12, [0]], ["_reserved", [], [[]]], ["_group",grpNull,[grpNull]],["_mode","COVER",[""]],["_actor",objNull,[objNull]]];
if (count _position < 2 || {count _threat < 2}) exitWith {[_position, false]};
_radius = (_radius max 1) min 25;
private _validate = [_group,"CBE_AIPass_CoverValidation_Enable",true] call CBE_fnc_CortexFeatureEnabled;
_mode=toUpperANSI _mode;
if !(_mode in ["COVER","CONCEALMENT"]) then {_mode="COVER"};
private _terrainTypes=if (_mode == "CONCEALMENT") then {["BUSH","TREE","SMALL TREE","HIDE"]} else {
    ["TREE","SMALL TREE","ROCK","ROCKS","WALL","FENCE","HIDE","BUILDING","HOUSE"]
};
private _objects = nearestTerrainObjects [_position, _terrainTypes, _radius, true, true];
if (count _objects > 10) then {_objects resize 10};
private _placed=if (_mode == "COVER") then {
    (nearestObjects [_position, ["House", "Wall", "Strategic"], _radius, true]) select [0,10]
} else {[]};
{_objects pushBackUnique _x} forEach _placed;
// Rank both sources together before the geometry budget. Appending placed cover after terrain
// and truncating immediately could discard a nearby wall behind ten more distant trees.
private _ranked=[];
{_ranked pushBack [_x distance2D _position,_forEachIndex,_x]} forEach _objects;
_ranked sort true;
_objects=(_ranked select [0,10]) apply {_x select 2};
private _threatASL = (AGLToASL _threat) vectorAdd [0, 0, 1.6];
private _result = [];
private _postChecks=0;
{
    private _pass=_x;
    {
        if (_postChecks >= 16) exitWith {};
        private _object = _x;
        private _scale=getObjectScale _object;
        if (!finite _scale || {_scale <= 0}) then {continue};
        private _bounds = boundingBoxReal _object;
        private _minimum=_bounds select 0;
        private _maximum=_bounds select 1;
        private _modelCentre=(_minimum vectorAdd _maximum) vectorMultiply 0.5;
        private _half=(_maximum vectorDiff _minimum) vectorMultiply 0.5;
        private _modelThreat=_object worldToModel _threat;
        private _away=_modelCentre vectorDiff _modelThreat;
        private _horizontal=[_away select 0,_away select 1,0];
        if (vectorMagnitude _horizontal < 0.01) then {_horizontal=[0,1,0]};
        private _direction=vectorNormalized _horizontal;
        // Intersect the threat-away ray with the rotated horizontal box. A capped circular
        // radius could leave a point inside a long wall or the footprint of a large house.
        private _edge=1e6;
        for "_axis" from 0 to 1 do {
            private _component=abs (_direction select _axis);
            if (_component > 0.001) then {_edge=_edge min ((_half select _axis)/_component)};
        };
        private _primary=_modelCentre vectorAdd (_direction vectorMultiply (_edge+0.8));
        private _side=[-(_direction select 1),_direction select 0,0];
        private _nearest=[];
        if (_pass == 1) then {
            // The central shadow can be far outside the local search at a long wall.
            // Project the requested point onto the nearest protected face instead of
            // extending the search or sampling the whole wall. Screening still decides.
            private _faceAxis=if (abs (_direction select 0) >= abs (_direction select 1)) then {0} else {1};
            private _lateralAxis=1-_faceAxis;
            private _faceSign=if ((_direction select _faceAxis) >= 0) then {1} else {-1};
            private _searchPoint=+_position;
            if (count _searchPoint == 2) then {_searchPoint pushBack 0};
            private _modelPosition=_object worldToModel _searchPoint;
            private _lateralLimit=((_half select _lateralAxis)-0.45/_scale) max 0;
            private _lateral=((_modelPosition select _lateralAxis)-(_modelCentre select _lateralAxis))
                max (-_lateralLimit) min _lateralLimit;
            _nearest=+_modelCentre;
            _nearest set [_faceAxis,(_modelCentre select _faceAxis)+_faceSign*((_half select _faceAxis)+0.8/_scale)];
            _nearest set [_lateralAxis,(_modelCentre select _lateralAxis)+_lateral];
        };
        private _offsets=if (_pass == 0) then {[0]} else {[0,2.25,-2.25]};
        {
            if (_postChecks >= 16 || {_result isNotEqualTo []}) exitWith {};
            _postChecks=_postChecks+1;
            private _offset=_x;
            private _modelCandidate=if (_pass == 1 && {_offset == 0}) then {_nearest} else {
                _primary vectorAdd (_side vectorMultiply (_offset/_scale))
            };
            // Lateral alternatives must remain outside the same rotated footprint.
            // An oblique offset can otherwise put one of them back inside the object.
            private _outside=(_modelCandidate select 0) < (_minimum select 0)
                || {(_modelCandidate select 0) > (_maximum select 0)}
                || {(_modelCandidate select 1) < (_minimum select 1)}
                || {(_modelCandidate select 1) > (_maximum select 1)};
            if (!_outside) then {continue};
            private _candidate=_object modelToWorld _modelCandidate;
            _candidate set [2, 0];
            private _candidateASL = AGLToASL _candidate;
            private _free = _candidate distance2D _position <= _radius
                && {!surfaceIsWater _candidate}
                && {_reserved findIf {_x distance2D _candidate < 2} < 0}
                && {(lineIntersectsSurfaces [_candidateASL vectorAdd [0, 0, 0.5], _candidateASL vectorAdd [0, 0, 20], _actor, objNull, true, 1]) findIf {(_x select 2) == _object || {(_x select 3) == _object}} < 0};
            if (_free && {_validate}) then {
                _free = (surfaceNormal _candidate select 2) >= 0.65
                    && {(_candidate nearEntities ["CAManBase",1.2]) findIf {_x != _actor} < 0}
                    && {(lineIntersectsSurfaces [_candidateASL vectorAdd [0,0,0.15],_candidateASL vectorAdd [0,0,1.8],_actor,objNull,true,1,"GEOM","NONE"]) isEqualTo []};
                if (_free) then {
                    {if ((lineIntersectsSurfaces [_candidateASL vectorAdd [0,0,0.8],(_candidateASL vectorAdd [0,0,0.8]) vectorAdd _x,_actor,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []) exitWith {_free = false}} forEach [[0.45,0,0],[-0.45,0,0],[0,0.45,0],[0,-0.45,0]];
                };
            };
            if (_free) then {
                private _endASL = _candidateASL vectorAdd [0, 0, 1];
                private _blocked=[_threatASL,_endASL,_actor,_mode] call CBE_fnc_CortexCoverScreened;
                if (_blocked) then {_result = [_candidate, true]};
            };
        } forEach _offsets;
        if (_result isNotEqualTo []) exitWith {};
    } forEach _objects;
    if (_result isNotEqualTo [] || {_postChecks >= 16}) exitWith {};
} forEach [0,1];
if (_result isEqualTo []) then {[_position, false]} else {_result}
