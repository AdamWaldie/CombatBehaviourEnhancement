/*
 * Author: WaldoTheWarfighter
 * Tests actual helicopter touchdown, cancelled landing orders and deferred feature handover
 * on clear-ground fixtures. The synthetic successor lease tests CBE protocol only, not mod parity.
 * Handover requires real approach admission, unchanged deadline and physical redirected flight;
 * no feature snapshots/results or physical completion are injected.
 * Locality/authority: scheduled server audit, using the public landing configuration and live waypoints.
 * Repeat/JIP: fresh aircraft per case; settings restored, public labels/trails; only owned fixtures deleted.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; required callbacks.
 * Return: Nothing. Current caller: cortexQAServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQALanding.sqf";
 */
params ["_check","_phase","_wait"];
private _names=["Enable","MinimumActivationDistance","TransitAltitude","GlideSlopeRatio","TreeScanRadius","TreeSafetyBuffer","GoAroundHeight","MaximumClimbRate","MaximumDescentRate","MaximumGoArounds","TouchdownHoldSeconds"];
private _defaults=[true,50,30,4,25,5,150,8,10,1,20];
private _saved=[];
{_saved pushBack (missionNamespace getVariable ["CBE_ImprovedHelicopterLanding_"+_x,_defaults select _forEachIndex])} forEach _names;
private _beforeInvalid=missionNamespace getVariable ["CBE_ImprovedHelicopterLanding_Enable",false];
["LAND-reject-short-payload",!([[true,50]] call CBE_fnc_ImprovedHelicopterLandingConfigureServer)] call _check;
["LAND-reject-wrong-enabled-type",!([[1,50,30,4,25,5,150,8,10,1,20]] call CBE_fnc_ImprovedHelicopterLandingConfigureServer)] call _check;
["LAND-reject-wrong-numeric-type",!([[true,"bad",30,4,25,5,150,8,10,1,20]] call CBE_fnc_ImprovedHelicopterLandingConfigureServer)] call _check;
["LAND-invalid-payload-preserves-setting",(missionNamespace getVariable ["CBE_ImprovedHelicopterLanding_Enable",false]) isEqualTo _beforeInvalid] call _check;
{
    private _cancel=_x;
    [[true,50,30,4,25,5,150,8,10,1,20]] call CBE_fnc_ImprovedHelicopterLandingConfigureServer;
    private _target=[4500,5000,0];
    private _aircraft=createVehicle ["O_Heli_Light_02_unarmed_F",[4500,4500,70],[],0,"FLY"];
    _aircraft setDir 0;
    createVehicleCrew _aircraft;
    private _crew=crew _aircraft;
    private _group=group driver _aircraft;
    _group setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setVariable ["CBE_AIPass_Exclude",true,true];
    _group setCombatMode "BLUE";
    {_x setVariable ["acex_headless_blacklist",true,true]} forEach _crew;
    _aircraft flyInHeight 70;
    _aircraft setVariable ["CBE_CortexQA_Label","LANDING TEST AIRCRAFT",true];
    _aircraft setVariable ["CBE_CortexQA_Target",_target,true];
    missionNamespace setVariable ["CBE_CortexQA_Actors",[_aircraft],true];
    ["Helicopter approach","Watch the actual aircraft approach the ground marker. The cyan trail records its flight. Landing acceptance requires physical ground contact within 10 m and a sustained stop, not a landing flag.",[4500,4750,40]] call _phase;
    private _wp=_group addWaypoint [_target,0];
    _wp setWaypointType "GETOUT";
    _wp setWaypointCompletionRadius 5;
    private _acquired=[{_aircraft getVariable ["CBE_ImprovedHelicopterLanding_Active",false]},60] call _wait;
    [format ["LAND-%1-controller-acquired",["touchdown","cancel"] select _cancel],_acquired] call _check;
    if (_cancel) then {
        private _redirect=[4900,4800,70];
        ["Landing order replaced","The approach order is replaced with an ordinary MOVE. The helicopter must fly toward the new marker without touching down at the cancelled landing point.",[4500,4750,40]] call _phase;
        deleteWaypoint _wp;
        _wp=_group addWaypoint [_redirect,0]; _wp setWaypointType "MOVE";
        _aircraft setVariable ["CBE_CortexQA_Target",_redirect,true];
        private _origin=getPosATL _aircraft;
        private _touched=false;
        private _redirected=[{
            if (isTouchingGround _aircraft) then {_touched=true};
            alive _aircraft && {_aircraft distance2D _origin > 150} && {_aircraft distance2D _redirect < 100} && {getPosATL _aircraft select 2 > 15}
        },100] call _wait;
        ["LAND-cancel-physical-redirection",_acquired && {_redirected} && {!_touched},str getPosATL _aircraft] call _check;
        ["LAND-cancel-controller-released",!(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_Active",false])] call _check;
    } else {
        private _landed=[{alive _aircraft && {isTouchingGround _aircraft} && {_aircraft distance2D _target <= 10} && {abs speed _aircraft < 2}},150] call _wait;
        ["LAND-physical-touchdown",_acquired && {_landed},str [getPosATL _aircraft,speed _aircraft,isTouchingGround _aircraft]] call _check;
        private _held=_landed;
        for "_sample" from 1 to 10 do {sleep 1; if (!alive _aircraft || {!isTouchingGround _aircraft} || {abs speed _aircraft >= 2}) then {_held=false}};
        ["LAND-ground-hold",_held] call _check;
    };
    missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
    {deleteVehicle _x} forEach _crew;
    deleteVehicle _aircraft; deleteGroup _group;
} forEach [false,true];
// Deferred feature handover diagnostic (normal, server-owned). This uses the real approach
// and flight-lease APIs, not injected snapshots, feature results or movement completion.
call {
    [[true,50,30,4,25,5,150,8,10,1,20]] call CBE_fnc_ImprovedHelicopterLandingConfigureServer;
    private _target=[5200,5000,0];
    private _redirect=[5600,4800,80];
    private _aircraft=createVehicle ["O_Heli_Light_02_unarmed_F",[5200,4500,90],[],0,"FLY"];
    _aircraft setDir 0;
    createVehicleCrew _aircraft;
    private _crew=crew _aircraft;
    private _pilot=currentPilot _aircraft;
    private _group=group _pilot;
    _group setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setVariable ["CBE_AIPass_Exclude",true,true];
    _group setCombatMode "BLUE";
    {_x setVariable ["acex_headless_blacklist",true,true]} forEach _crew;
    private _successorToken="LAND_QA:"+netId _aircraft;
    private _dispose={
        [_aircraft,"QA_SUCCESSOR",_successorToken,"QA_CLEANUP"] call CBE_fnc_FlightLeaseRelease;
        missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
        {deleteVehicle _x} forEach _crew;
        deleteVehicle _aircraft;
        deleteGroup _group;
    };
    _aircraft flyInHeight 90;
    _aircraft setVariable ["CBE_CortexQA_Label","LANDING HANDOVER DIAGNOSTIC",true];
    _aircraft setVariable ["CBE_CortexQA_Target",_target,true];
    missionNamespace setVariable ["CBE_CortexQA_Actors",[_aircraft],true];
    ["Landing feature handover","A real approach yields to another flight lease. Cleanup must wait without renewing its deadline, then let a fresh native MOVE fly. This tests the CBE protocol, not a Workshop controller.",[5200,4750,60]] call _phase;
    private _beforeRevision=_aircraft getVariable ["CBE_ImprovedHelicopterLanding_ControlRevision",0];
    private _beforeFlags=[_aircraft checkAIFeature "MOVE",_aircraft checkAIFeature "PATH",_pilot checkAIFeature "FSM"];
    private _unownedRelease=[_aircraft,false] call CBE_fnc_ImprovedHelicopterLandingRestoreLocal;
    ["LAND-handover-unowned-release-noop",!_unownedRelease
        && {(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_ControlRevision",0]) == _beforeRevision}
        && {[_aircraft checkAIFeature "MOVE",_aircraft checkAIFeature "PATH",_pilot checkAIFeature "FSM"] isEqualTo _beforeFlags}] call _check;
    ["LAND-handover-normal-owner",local _aircraft && {local _pilot} && {local _group}] call _check;
    private _wp=_group addWaypoint [_target,0];
    _wp setWaypointType "GETOUT";
    _wp setWaypointCompletionRadius 5;
    private _acquired=[{_aircraft getVariable ["CBE_ImprovedHelicopterLanding_Active",false]
        && {count (_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot",[]]) == 6}
        && {!(_pilot checkAIFeature "FSM")}},60] call _wait;
    ["LAND-handover-real-controller-admitted",_acquired] call _check;
    if (!_acquired) exitWith {call _dispose};
    private _revision=_aircraft getVariable ["CBE_ImprovedHelicopterLanding_ControlRevision",-1];
    private _snapshot=+(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot",[]]);
    private _successor=[_aircraft,"QA_SUCCESSOR",_successorToken,600] call CBE_fnc_FlightLeaseAcquire;
    ["LAND-handover-successor-lease",_successor] call _check;
    if (!_successor) exitWith {call _dispose};
    private _pending=[{!(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_Active",false])
        && {count (_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",[]]) == 2}
        && {((_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseResult",[]]) param [0,""]) == "PENDING"}},10] call _wait;
    ["LAND-handover-deferred-not-completed",_pending
        && {!(_aircraft checkAIFeature "MOVE")} && {!(_aircraft checkAIFeature "PATH")}
        && {(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot",[]]) isEqualTo _snapshot}] call _check;
    if (!_pending) exitWith {call _dispose};
    private _release=+(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",[]]);
    private _until=_release select 1;
    private _stale=[_aircraft,false,"",false,_revision+1] call CBE_fnc_ImprovedHelicopterLandingRestoreLocal;
    ["LAND-handover-stale-release-refused",!_stale
        && {(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",[]]) isEqualTo _release}] call _check;
    [_aircraft,false,"",false,_revision] call CBE_fnc_ImprovedHelicopterLandingRestoreLocal;
    [{false},2] call _wait;
    private _liveLease=_aircraft getVariable ["CBE_FlightLease",createHashMap];
    ["LAND-handover-original-deadline-and-successor",(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",[]]) isEqualTo _release
        && {(_liveLease getOrDefault ["controller",""]) == "QA_SUCCESSOR"}
        && {(_liveLease getOrDefault ["token",""]) == _successorToken}
        && {!(_aircraft checkAIFeature "MOVE")}] call _check;
    // The successor establishes its own native flight policy while it owns the lease.
    // These are real orders, not forced velocity/position or injected feature completion.
    deleteWaypoint _wp;
    _wp=_group addWaypoint [_redirect,0];
    _wp setWaypointType "MOVE";
    _aircraft land "NONE";
    _aircraft flyInHeight 90;
    _aircraft setVariable ["CBE_CortexQA_Target",_redirect,true];
    private _nativeOrder=[_group] call CBE_fnc_NativeOrderReceipt;
    private _origin=getPosATL _aircraft;
    ["LAND-handover-successor-released",[_aircraft,"QA_SUCCESSOR",_successorToken,"QA_NATIVE_HANDOVER"] call CBE_fnc_FlightLeaseRelease] call _check;
    private _restored=[{
        private _ack=_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseResult",[]];
        (_ack select [0,4]) isEqualTo ["RELEASED",_revision,_snapshot select 1,_until]
            && {(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot",[]]) isEqualTo []}
            && {(_aircraft getVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",[]]) isEqualTo []}
            && {_aircraft checkAIFeature "MOVE"} && {_aircraft checkAIFeature "PATH"}
            && {_pilot checkAIFeature "FSM"}
    },10] call _wait;
    ["LAND-handover-exact-feature-ack",_restored] call _check;
    private _touched=false;
    private _moved=[{
        if (isTouchingGround _aircraft) then {_touched=true};
        alive _aircraft && {_aircraft distance2D _origin > 150}
            && {_aircraft distance2D _redirect < 100} && {((getPosATL _aircraft) select 2) > 15}
    },100] call _wait;
    ["LAND-handover-physical-native-redirection",_restored && {_moved} && {!_touched}
        && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _nativeOrder},
        str [getPosATL _aircraft,speed _aircraft,isTouchingGround _aircraft]] call _check;
    call _dispose;
};
[_saved] call CBE_fnc_ImprovedHelicopterLandingConfigureServer;
