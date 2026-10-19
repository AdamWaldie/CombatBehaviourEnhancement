/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe one acknowledged queue leaf reverse without weakening stationary admission.
 * Locality/authority: Read-only server or participant owner. The caller must already own an
 * authenticated moving phase; this observation never grants a phase or issues native work.
 * Repeat/JIP: Original context, token, expiry and bounded reverse envelope only. No state,
 * command replay, new lifetime, worker or cached clearance. All other participants stay still.
 * Arguments: 0 agreement HASHMAP empty; 1 require local-owner rows BOOL false.
 * Agreement motionBinding=[leaf OBJECT, token STRING, expires NUMBER, rear budget NUMBER].
 * Return: BOOL - current acknowledged reverse observation, not physical success or clearance.
 * Cost: At most four canonical crew/pose rows; no world search or geometry ray.
 * Current callers: DrivingQueueAgreementServer and DrivingQueueHold moving-phase observation.
 * Example: private _current=[_agreement,true] call CBE_fnc_DrivingQueueReverseCurrent;
 */
params [["_agreement",createHashMap,[createHashMap]],["_localRows",false,[true]]];
private _vehicles=_agreement getOrDefault ["vehicles",[]];
private _context=_agreement getOrDefault ["context",[]];
private _binding=_agreement getOrDefault ["motionBinding",[]];
private _token=_agreement getOrDefault ["token",""];
private _expires=_agreement getOrDefault ["expires",-1];
private _roles=_agreement getOrDefault ["roles",[]];
private _dependencies=_agreement getOrDefault ["dependencies",[]];
private _movingIndex=_agreement getOrDefault ["movingIndex",count _vehicles-1];
private _heldIndices=_agreement getOrDefault ["heldIndices",[]];
if (!(_vehicles isEqualType []) || {!(_context isEqualType [])} || {!(_token isEqualType "")}
    || {!(_expires isEqualType 0)} || {!finite _expires}
    || {count _vehicles < 2} || {count _vehicles > 4} || {count _roles != count _vehicles} || {count _dependencies != count _vehicles}
    || {(_dependencies select (count _vehicles-1)) != -1} || {count _context != count _vehicles}
    || {!(_binding isEqualType [])} || {count _binding != 4}
    || {!((_binding select 0) isEqualType objNull)} || {!((_binding select 1) isEqualType "")}
    || {!((_binding select 2) isEqualType 0)} || {!finite (_binding select 2)}
    || {!((_binding select 3) isEqualType 0)} || {!finite (_binding select 3)}
    || {_token == ""} || {(_binding select 1) != _token} || {(_binding select 2) != _expires}
    || {serverTime >= _expires} || {(_binding select 3) <= 0} || {(_binding select 3) > 8}
    || {!(_movingIndex isEqualType 0)} || {_movingIndex != floor _movingIndex}
    || {_movingIndex < 1} || {_movingIndex >= count _vehicles}
    || {!(_heldIndices isEqualType [])}
    || {_heldIndices isNotEqualTo ([1,2,3] select {_x > _movingIndex && {_x < count _vehicles}})}
    || {(_binding select 0) != (_vehicles select _movingIndex)}) exitWith {false};
if (_localRows && {[_token] call CBE_fnc_DrivingQueueTokenClosed}) exitWith {false};
// ARMED owners must all know the bounded moving context before the leaf receives
// EXECUTE. Until native issue exists, retain the unchanged stationary comparison.
// Pending issued BACK requires its own journal acknowledgement path, not this fallback.
if ((_agreement getOrDefault ["motionStage",""]) != "ARMED") exitWith {false};
private _leaf=_binding select 0;
if (_heldIndices isEqualTo [] && {count (_leaf getVariable ["CBE_DrivingRecovery_Work",createHashMap]) == 0}
    && {toUpperANSI ((vehicleMoveInfo _leaf) param [0,""]) != "BACK"}
    && {(getPosWorld _leaf) vectorDistance (((_context select _movingIndex) select 4) select 0) <= 1.5}) exitWith {
    [_vehicles,_roles,_dependencies,_context,_localRows] call CBE_fnc_DrivingQueueProposalCurrent
};
private _live=[_vehicles] call CBE_fnc_DrivingQueueContext;
if (count _live != count _context) exitWith {false};
private _valid=true;private _localCount=0;
{
    private _row=_x;private _old=_context select _forEachIndex;
    private _vehicle=_vehicles select _forEachIndex;
    private _moving=_vehicle == (_binding select 0);
    private _held=_forEachIndex in _heldIndices;
    if (!(_old isEqualType []) || {count _old != 6}
        || {(_row select [0,2]) isNotEqualTo (_old select [0,2])}) exitWith {_valid=false};
    {
        private _actor=_row select _x;private _original=_old select _x;
        if (!(_original isEqualType []) || {count _original != 11} || {_actor isNotEqualTo _original}) exitWith {_valid=false};
    } forEach [2,3];
    if (!_valid) exitWith {};
    private _pose=_row select 4;private _before=_old select 4;
    if (!(_before isEqualType []) || {count _before != 3}
        || {_before findIf {!(_x isEqualType []) || {count _x != 3}
            || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}) exitWith {_valid=false};
    if (abs ((vectorMagnitude (_before select 1))-1) > 0.01
        || {abs ((vectorMagnitude (_before select 2))-1) > 0.01}
        || {abs ((_before select 1) vectorDotProduct (_before select 2)) > 0.02}) exitWith {_valid=false};
    private _delta=(_pose select 0) vectorDiff (_before select 0);
    private _forward=_before select 1;private _up=_before select 2;
    private _right=_forward vectorCrossProduct _up;
    private _rear=-(_delta vectorDotProduct _forward);
    private _linear=vectorMagnitude velocity _vehicle;
    private _angular=vectorMagnitude angularVelocity _vehicle;
    if (!finite _linear || {!finite _angular} || {!canMove _vehicle}
        || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {(_pose select 1) vectorDotProduct _forward < cos 5}
        || {(_pose select 2) vectorDotProduct _up < cos 5}
        || {_vehicle getVariable ["CBE_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}) exitWith {_valid=false};
    if (_moving || {_held}) then {
        private _moveInput=toUpperANSI ((_row select 5) param [0,""]);
        private _pendingInput=!_held && {(_row select 5) isEqualTo (_old select 5)};
        if (!(_moveInput in ["BACK","STOP"]) && {!_pendingInput}
            || {toUpperANSI ((_row select 5) param [1,""]) != "NONE"}
            || {_rear < -0.25} || {_rear > (_binding select 3)+0.5}
            || {abs (_delta vectorDotProduct _right) > 1}
            || {abs (_delta vectorDotProduct _up) > 1.5}
            || {_linear > (10/3.6)} || {_angular > 0.05}
            || {_held && {_moveInput != "STOP" || {_linear >= 0.1} || {_angular >= 0.01}}}) then {_valid=false};
    } else {
        if (vectorMagnitude _delta > 1.5 || {_linear >= (1/3.6)} || {_angular >= 0.01}
            || {(_row select 5) isNotEqualTo (_old select 5)}) then {_valid=false};
    };
    if (!_valid) exitWith {};
    if (_localRows && {local _vehicle}) then {
        _localCount=_localCount+1;
        private _group=group driver _vehicle;
        private _brain=_group getVariable ["CBE_Driving_Brain",createHashMap];
        if (!_moving && {!_held}) then {
            if (!([_vehicle,"QUEUE"] call CBE_fnc_DrivingPassCanConsent)) then {_valid=false};
        } else {
            private _work=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
            // A new phase may select a still-held parent with no issued journal yet.
            // The existing ordinary eligibility remains required for that pre-issue state.
            if (_moving && {count _work == 0}) then {
                if (!([_vehicle,"QUEUE"] call CBE_fnc_DrivingPassCanConsent)) then {_valid=false};
            } else {
            private _expected=[_token,_expires,_brain getOrDefault ["ownerEpoch",-1],_brain getOrDefault ["generation",-1]];
            if (!local _group || {!local driver _vehicle} || {!local effectiveCommander _vehicle}
                || {driver _vehicle == effectiveCommander _vehicle}
                || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                || {(_work getOrDefault ["group",grpNull]) != _group}
                || {(_work getOrDefault ["driver",objNull]) != driver _vehicle}
                || {(_work getOrDefault ["operator",objNull]) != effectiveCommander _vehicle}
                || {(_work getOrDefault ["route",[]]) isNotEqualTo ((_row select 2) select 10)}
                || {(_work getOrDefault ["cap",-1]) < 0} || {(_work getOrDefault ["cap",-1]) > (10/3.6)}
                || {[driver _vehicle,effectiveCommander _vehicle] findIf {
                    !simulationEnabled _x || {isObjectHidden _x} || {!(_x checkAIFeature "MOVE")}
                        || {!(_x checkAIFeature "PATH")} || {!([_x] call CBE_fnc_CortexCombatEffective)}
                        || {[_x] call CBE_fnc_CortexActorMoveReserved}
                } >= 0}
                || {(_work getOrDefault ["queueBinding",[]]) isNotEqualTo _expected}
                || {(_work getOrDefault ["commandMode",""]) != "SIMPLE_BACK"}
                || {private _native=vehicleMoveInfo _vehicle;
                    private _back=toUpperANSI (_native param [0,""]) == "BACK" && {_work getOrDefault ["simpleAcknowledged",false]}
                        && {!(_work getOrDefault ["queueStopAcknowledged",false])};
                    private _stop=toUpperANSI (_native param [0,""]) == "STOP" && {_work getOrDefault ["simpleStopIssued",false]};
                    private _pending=!(_work getOrDefault ["simpleAcknowledged",false])
                        && {!(_work getOrDefault ["queueStopAcknowledged",false])} && {_native isEqualTo (_work getOrDefault ["simpleBefore",[]])};
                    !(_back || {_stop} || {_pending})}
                || {_held && {(_work getOrDefault ["queuePhase",""]) != "HELD"
                    || {!(_work getOrDefault ["queueStopAcknowledged",false])}
                    || {(_work getOrDefault ["cap",-1]) != 0}}}
                || {(_work getOrDefault ["kind",""]) != "REVERSE"}
                || {(_work getOrDefault ["hardDeadline",1e12]) > _expires}
                || {serverTime >= (_work getOrDefault ["hardDeadline",-1])}
                || {abs (getForcedSpeed _vehicle-(_work getOrDefault ["cap",-1])) > 0.1}
                || {!([_group] call CBE_fnc_DrivingMovementAvailable)}
                || {!([_group] call CBE_fnc_CortexIsEligible)}
                || {[_group] call CBE_fnc_CortexExternalTakeover}
                || {[_group] call CBE_fnc_CortexZeusHeld}
                || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
                || {(_group getVariable ["CBE_Driving_FSM",-1]) < 0}
                || {completedFSM (_group getVariable ["CBE_Driving_FSM",-1])}
                || {!([_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}) then {_valid=false};
            };
        };
    };
    if (!_valid) exitWith {};
} forEach _live;
_valid && {!_localRows || {_localCount > 0}}
