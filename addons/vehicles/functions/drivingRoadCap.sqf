/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes nearby road bends, junctions and grade for a shared safety speed ceiling.
 * Locality/authority: read-only on the current vehicle owner; the consuming driving/convoy
 * executor rechecks its movement lease before any speed command. No route choice is written.
 * Repeat/JIP: fresh observation only, no handlers or retained state; callers own cadence/cache.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 requested cap km/h <NUMBER>, 70 (0..120).
 * Return: ARRAY [cap km/h NUMBER, maximum turn degrees NUMBER, maximum grade NUMBER, junction BOOL].
 * Cost: at most eight road nodes and sixteen connections per node; native discovery cost is
 * engine-dependent. Heading-based branch selection is a heuristic, not the native planned route.
 * Current callers: DrivingAssistStart and ConvoyTick.
 * Example: private _road = [truck1,70] call WAIT_fnc_DrivingRoadCap;
 */
params [["_vehicle",objNull,[objNull]],["_requested",70,[0]]];
if (!finite _requested) then {_requested=0};
_requested=(_requested max 0) min 120;
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}) exitWith {[_requested,0,0,false]};
private _road=roadAt _vehicle;
if (isNull _road) then {_road=(_vehicle nearRoads 8) param [0,objNull]};
private _maximumTurn=0;private _maximumGrade=0;private _junction=false;private _overBudget=false;
if (!isNull _road) then {
    private _previousRoad=objNull;
    private _roadPosition=getPosASL _road;
    private _roadHeading=getDir _vehicle;
    private _travel=0;private _visited=[];
    for "_sample" from 1 to 8 do {
        if (_road in _visited) exitWith {};
        _visited pushBack _road;
        private _allConnected=roadsConnectedTo _road;
        if (count _allConnected > 16) exitWith {_overBudget=true};
        if (count _allConnected >= 3) then {_junction=true};
        private _connected=_allConnected-[_previousRoad];
        private _nextRoad=objNull;private _bestTurn=181;
        {
            if (!isNull _x && {!(_x in _visited)}) then {
                private _candidateHeading=_roadPosition getDir _x;
                private _candidateTurn=abs (((_candidateHeading-_roadHeading+540) mod 360)-180);
                if (_candidateTurn < _bestTurn) then {_bestTurn=_candidateTurn;_nextRoad=_x};
            };
        } forEach _connected;
        if (isNull _nextRoad || {_bestTurn > 110}) exitWith {};
        private _nextPosition=getPosASL _nextRoad;
        private _segment=_roadPosition distance2D _nextPosition;
        if (_segment < 1) exitWith {};
        _maximumTurn=_maximumTurn max _bestTurn;
        _maximumGrade=_maximumGrade max (abs ((_nextPosition select 2)-(_roadPosition select 2))/_segment);
        _travel=_travel+_segment;
        _roadHeading=_roadPosition getDir _nextPosition;
        _previousRoad=_road;_road=_nextRoad;_roadPosition=_nextPosition;
        if (_travel >= 70) exitWith {};
    };
};
private _cap=_requested;
if (_maximumTurn > 70) then {_cap=_cap min 18} else {
    if (_maximumTurn > 45) then {_cap=_cap min 25} else {if (_maximumTurn > 25) then {_cap=_cap min 35}};
};
if (_junction) then {_cap=_cap min 30};
if (_maximumGrade > 0.2) then {_cap=_cap min 18} else {if (_maximumGrade > 0.12) then {_cap=_cap min 25}};
if (_overBudget) then {_cap=_cap min 15};
[_cap,_maximumTurn,_maximumGrade,_junction]
