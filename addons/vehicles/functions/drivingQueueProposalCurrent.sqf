/*
 * Author: WaldoTheWarfighter
 * Purpose: Checks queue roster/role topology and optionally each actual local owner row.
 * Locality/authority: Read-only anywhere; localRows requires real local crew/group/brain and native-route eligibility. Snapshot topology is not owner consent.
 * Repeat/JIP: No state/commands/handlers; re-read before every deferred protocol action.
 * Total finite linear velocity must remain below1km/h, including lateral/vertical motion.
 * This instantaneous test grants neither an execution hold nor physical READY.
 * Arguments: 0 vehicles ARRAY [];1 roles ARRAY [];2 dependencies ARRAY [];3 context ARRAY [];4 localRows BOOL false.
 * Return: BOOL current proposal observation, never execution authority.
 * Current callers: DrivingQueueAgreementRequest/Server/Owner.
 * Example: [_vehicles,_roles,_dependencies,_context,true] call CBE_fnc_DrivingQueueProposalCurrent;
 */
params [["_vehicles",[],[[]]],["_roles",[],[[]]],["_dependencies",[],[[]]],
    ["_context",[],[[]]],["_localRows",false,[true]]];
private _n=count _vehicles;
if (_n < 2 || {_n > 4} || {count _roles != _n} || {count _dependencies != _n}
    || {count _context != _n}) exitWith {false};
private _expectedRoles=["HOLD_CROSSING","YIELD_ROOT"];private _expectedDependencies=[-1];
for "_i" from 1 to (_n-1) do {
    if (_i > 1) then {_expectedRoles pushBack "REAR_ROOM"};
    _expectedDependencies pushBack ([-1,_i+1] select (_i < _n-1));
};
if (_roles isNotEqualTo _expectedRoles || {_dependencies isNotEqualTo _expectedDependencies}) exitWith {false};
private _live=[_vehicles] call CBE_fnc_DrivingQueueContext;
if (count _live != _n) exitWith {false};
private _valid=true;private _localCount=0;private _groups=[];
for "_i" from 0 to (_n-1) do {
    private _a=_live select _i;private _e=_context select _i;
    if (!(_e isEqualType []) || {count _e != 5} || {(_a select [0,2]) isNotEqualTo (_e select [0,2])}) exitWith {_valid=false};
    {
        private _ar=_a select _x;private _er=_e select _x;
        if (!(_er isEqualType []) || {count _er != 11} || {count _ar != 11}
            || {(_ar select [0,8]) isNotEqualTo (_er select [0,8])}
            || {(_ar select 10) isNotEqualTo (_er select 10)}) exitWith {_valid=false};
        if (!alive (_ar select 0) || {_ar select 6} || {!isNull (_ar select 7)}) exitWith {_valid=false};
        if (_localRows && {local (_vehicles select _i)} && {_ar isNotEqualTo _er}) exitWith {_valid=false};
    } forEach [2,3];
    if (!_valid) exitWith {};
    private _ep=_e select 4;private _ap=_a select 4;
    if (!(_ep isEqualType []) || {count _ep != 3}
        || {_ep findIf {!(_x isEqualType []) || {count _x != 3}
            || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}) exitWith {_valid=false};
    if (abs ((vectorMagnitude (_ep select 1))-1) > 0.01
        || {abs ((vectorMagnitude (_ep select 2))-1) > 0.01}
        || {abs ((_ep select 1) vectorDotProduct (_ep select 2)) > 0.02}) exitWith {_valid=false};
    if (((_ap select 0) vectorDistance (_ep select 0)) > 1.5
        || {((_ap select 1) vectorDotProduct (_ep select 1)) < cos 5}
        || {((_ap select 2) vectorDotProduct (_ep select 2)) < cos 5}) exitWith {_valid=false};
    private _vehicle=_vehicles select _i;private _driver=driver _vehicle;private _group=group _driver;
    // speed measures only model-forward motion; lateral sliding/falling must revoke admission too.
    private _queueLinearSpeed=vectorMagnitude velocity _vehicle;
    if (_group in _groups || {!finite _queueLinearSpeed} || {_queueLinearSpeed >= (1/3.6)} || {!canMove _vehicle}
        || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {_vehicle getVariable ["CBE_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}) exitWith {_valid=false};
    _groups pushBack _group;
    if (_localRows && {local _vehicle}) then {
        _localCount=_localCount+1;
        // Shared read-only ordinary-route admission only: no passing token/ACK is reused.
        private _brain=_group getVariable ["CBE_Driving_Brain",createHashMap];
        private _pass=_vehicle getVariable ["CBE_DrivingPass_Consent",[]];
        private _passBusy=false;
        if (_pass isNotEqualTo []) then {
            private _typed=_pass isEqualType [] && {count _pass == 5}
                && {(_pass select 4) in ["PENDING","AGREED"]}
                && {(_pass select 2) isEqualType 0} && {finite (_pass select 2)}
                && {(_pass select 3) isEqualType 0} && {finite (_pass select 3)};
            _passBusy=!_typed || {serverTime < ([_pass select 2,_pass select 3] select ((_pass select 4) == "AGREED"))};
        };
        if (!([_vehicle,"QUEUE"] call CBE_fnc_DrivingPassCanConsent)
            || {(_brain getOrDefault ["generation",-2]) != ((_a select 2) select 5)}
            || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
            || {_passBusy}
            || {!([_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
            || {[_group] call CBE_fnc_CortexZeusHeld}) then {_valid=false};
    };
};
if (!_valid || {_localRows && {_localCount == 0}}) exitWith {false};
private _first=_vehicles select 0;private _yield=_vehicles select 1;
private _axis=vectorDir _yield;_axis set [2,0];_axis=vectorNormalized _axis;
private _right=[_axis select 1,-(_axis select 0),0];
private _front=(getPosASL _first) vectorDiff (getPosASL _yield);
if (_first distance2D _yield > 30 || {(_front vectorDotProduct _axis) <= 0}
    || {abs (_front vectorDotProduct _right) > 6} || {abs (_front select 2) > 2}
    || {(vectorDir _first) vectorDotProduct _axis > -(cos 25)}) exitWith {false};
for "_i" from 2 to (_n-1) do {
    private _delta=(getPosASL (_vehicles select _i)) vectorDiff (getPosASL (_vehicles select (_i-1)));
    private _rear=-(_delta vectorDotProduct _axis);
    if (_rear <= 0 || {_rear > 25} || {abs (_delta vectorDotProduct _right) > 6}
        || {abs (_delta select 2) > 2} || {(vectorDir (_vehicles select _i)) vectorDotProduct _axis < cos 25}) exitWith {_valid=false};
};
_valid
