/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes current occupied pass-corridor hulls and measured approaching traffic.
 * Locality/authority: Read-only passing-vehicle owner; no priority, agreement or movement writes.
 * Repeat/JIP: Fresh observation only. Both crew/order contexts and two-second proposal age
 * are checked before and after work. Never replay a prior traffic observation as clearance.
 * Arguments: 0 proposal <HASHMAP>, empty, from DrivingPassPlan.
 * Return: HASHMAP status REFUSED or TRAFFIC_OBSERVATION, blocked BOOL, reason, actor,
 * candidateCount, observedAt and context. No observed conflict is not permission to pass.
 * Bound: one native area query <=900 m, at most 64 candidates and 127 guide segments each;
 * dense results refuse without inspecting a selected prefix. No raycasts or recurring handler.
 * Area discovery includes dead vehicle entities; parked/empty/destroyed hulls remain obstacles.
 * The intended predecessor is excluded only from this corridor observer; independent following
 * and collision caps must still constrain it. Mounted people are represented by their vehicle.
 * Approaching risk uses actual velocity and a finite constant-course estimate, not an assumption
 * that another driver yields. Curved/future traffic still requires runtime collision/abort checks.
 * Current callers: trusted script preflight only; automatic pass executor remains unimplemented.
 * Example: private _traffic=[_proposal] call WAIT_fnc_DrivingPassTraffic;
 */
params [["_proposal",createHashMap,[createHashMap]]];
private _fail={params ["_reason",["_count",0]];createHashMapFromArray [["status","REFUSED"],
    ["blocked",true],["reason",_reason],["candidateCount",_count]]};
if ((_proposal getOrDefault ["status",""]) != "PROPOSAL") exitWith {["INVALID_PROPOSAL"] call _fail};
private _vehicles=_proposal getOrDefault ["vehicles",[]];
private _context=_proposal getOrDefault ["context",[]];
private _observed=_proposal getOrDefault ["observedAt",-1];
private _current={_observed isEqualType 0 && {finite _observed} && {serverTime >= _observed}
    && {serverTime-_observed <= 2} && {_context isNotEqualTo []}
    && {([_vehicles] call WAIT_fnc_DrivingPassContext) isEqualTo _context}};
if !(call _current) exitWith {["STALE_CONTEXT"] call _fail};
private _vehicle=_vehicles select 0;private _front=_vehicles select 1;
if (!local _vehicle) exitWith {["OWNER_UNAVAILABLE"] call _fail};
private _guide=_proposal getOrDefault ["guideASL",[]];
private _duration=_proposal getOrDefault ["estimatedSeconds",-1];
private _travel=_proposal getOrDefault ["requiredTravel",-1];
if (!(_guide isEqualType []) || {count _guide < 2} || {count _guide > 128}
    || {_guide findIf {!(_x isEqualType []) || {count _x != 3}
        || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}
    || {!(_duration isEqualType 0)} || {!finite _duration} || {_duration <= 0} || {_duration > 24}
    || {!(_travel isEqualType 0)} || {!finite _travel} || {_travel <= 0} || {_travel > 350}) exitWith {["INVALID_CORRIDOR"] call _fail};
private _range=((_travel+17*_duration+60) max 150) min 900;
private _area=[getPosATL _vehicle,_range,_range,0,false,_range];
private _candidates=_area nearEntities [["LandVehicle","CAManBase"],false,false,false];
if (count _candidates > 64) exitWith {["TRAFFIC_BUDGET",count _candidates] call _fail};
private _box=boundingBoxReal _vehicle;
private _width=((abs ((_box select 0) select 0)) max (abs ((_box select 1) select 0)))+0.5;
private _height=((_box select 1) select 2)-((_box select 0) select 2);
private _origin=getPosASL _vehicle;private _forward=vectorDir _vehicle;
_forward set [2,0];_forward=vectorNormalized _forward;
private _ownSpeed=_travel/(_duration max 0.1);
private _reason="NO_OBSERVED_CONFLICT";private _limiting=objNull;
{
    private _other=_x;
    if (_other != _vehicle && {_other != _front} && {!isNull _other}
        && {!(_other isKindOf "CAManBase") || {isNull objectParent _other}}) then {
        private _position=getPosASL _other;
        private _otherBox=boundingBoxReal _other;
        private _otherWidth=(abs ((_otherBox select 0) select 0)) max (abs ((_otherBox select 1) select 0));
        private _otherLength=(abs ((_otherBox select 0) select 1)) max (abs ((_otherBox select 1) select 1));
        private _radius=sqrt (_otherWidth^2+_otherLength^2);
        private _vertical=(_height+((_otherBox select 1) select 2)-((_otherBox select 0) select 2))*0.5+1;
        private _occupied=false;
        for "_segment" from 1 to (count _guide-1) do {
            private _a=_guide select (_segment-1);private _b=_guide select _segment;
            private _delta=_b vectorDiff _a;private _flat=+_delta;_flat set [2,0];
            private _relative=_position vectorDiff _a;_relative set [2,0];
            private _fraction=((_relative vectorDotProduct _flat)/((_flat vectorDotProduct _flat) max 0.01) max 0) min 1;
            private _closest=_a vectorAdd (_delta vectorMultiply _fraction);
            if (_position distance2D _closest <= _width+_radius+1
                && {abs ((_position select 2)-(_closest select 2)) <= _vertical}) exitWith {_occupied=true};
        };
        private _offset=_position vectorDiff _origin;
        private _closing=-((velocity _other) vectorDotProduct _forward);
        private _approaching=(_offset vectorDotProduct _forward) > 0 && {_closing > 0.5}
            && {_position distance2D _origin <= (_ownSpeed+_closing)*_duration+20}
            && {abs (_offset select 2) <= _vertical};
        if (_occupied || {_approaching}) exitWith {
            _limiting=_other;_reason=["APPROACHING_TRAFFIC","OCCUPIED_CORRIDOR"] select _occupied;
        };
    };
} forEach _candidates;
if (!(call _current) || {!local _vehicle}) exitWith {["CONTEXT_CHANGED",count _candidates] call _fail};
createHashMapFromArray [["status","TRAFFIC_OBSERVATION"],["blocked",!isNull _limiting],
    ["reason",_reason],["actor",_limiting],["candidateCount",count _candidates],
    ["observedAt",serverTime],["context",_context]]