/*
 * Author: WaldoTheWarfighter
 * Actual-owner active rows defer to crew flight and queued treatment, independent of task labels.
 * Purpose: Observe an acknowledged queue reverse or bound crossing path without weakening admission.
 * CROSSING requires explicit root binding and a frozen path installed by every owner.
 * Only its exact QUEUE path journal can substitute owned root task receipts.
 * All yielding rows remain stopped at their original bounded reverse poses; no completion credit.
 * Locality/authority: Read-only server or participant owner. The caller must already own an
 * authenticated moving phase; this observation never grants a phase or issues native work.
 * Repeat/JIP: Original context, token, expiry and bounded reverse envelope only. No state,
 * command replay, new lifetime, worker or cached clearance. All other participants stay still.
 * Arguments: 0 agreement HASHMAP empty; 1 require local-owner rows BOOL false.
 * Agreement motionBinding=[leaf OBJECT, token STRING, expires NUMBER, rear budget NUMBER].
 * Return: BOOL - current acknowledged reverse observation, not physical success or clearance.
 * Cost: At most four canonical crew/pose rows and23 crossing segments; no world search or geometry ray.
 * Current callers: DrivingQueueAgreementServer and DrivingQueueHold moving-phase observation.
 * Example: private _current=[_agreement,true] call CBE_fnc_DrivingQueueReverseCurrent;
 */
params [["_agreement",createHashMap,[createHashMap]],["_localRows",false,[true]]];
private _vehicles=_agreement getOrDefault ["vehicles",[]];
private _context=_agreement getOrDefault ["context",[]];
private _rearRequirements=_agreement getOrDefault ["rearRequirements",[]];
private _binding=_agreement getOrDefault ["motionBinding",[]];
private _token=_agreement getOrDefault ["token",""];
private _expires=_agreement getOrDefault ["expires",-1];
private _roles=_agreement getOrDefault ["roles",[]];
private _dependencies=_agreement getOrDefault ["dependencies",[]];
private _movingIndex=_agreement getOrDefault ["movingIndex",count _vehicles-1];
private _heldIndices=_agreement getOrDefault ["heldIndices",[]];
private _crossing=(_agreement getOrDefault ["motionStage",""]) == "CROSSING";
private _crossBinding=_agreement getOrDefault ["crossingBinding",[]];
private _crossPath=_agreement getOrDefault ["crossingPath",[]];
private _crossPoses=_agreement getOrDefault ["crossingPoses",[]];
private _rootWork=if (_vehicles isEqualType [] && {count _vehicles > 0} && {(_vehicles select 0) isEqualType objNull}) then {
    (_vehicles select 0) getVariable ["CBE_DrivingBypass_Work",createHashMap]
} else {createHashMap};
if (!(_vehicles isEqualType []) || {!(_context isEqualType [])} || {!(_token isEqualType "")}
    || {!(_expires isEqualType 0)} || {!finite _expires}
    || {count _vehicles < 2} || {count _vehicles > 4} || {count _roles != count _vehicles} || {count _dependencies != count _vehicles}
    || {!(_rearRequirements isEqualType [])} || {count _rearRequirements != count _vehicles}
    || {_rearRequirements findIf {!(_x isEqualType []) || {count _x != 2}
        || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}
    || {(_rearRequirements select 0) isNotEqualTo [0,0]}
    || {(_rearRequirements select [1]) findIf {(_x select 1) < 6 || {(_x select 1) > 24}
        || {(_x select 1) != floor (_x select 1)} || {(_x select 0) != (_x select 1)+2}} >= 0}
    || {(_dependencies select (count _vehicles-1)) != -1} || {count _context != count _vehicles}
    || {!(_binding isEqualType [])} || {count _binding != 4}
    || {!((_binding select 0) isEqualType objNull)} || {!((_binding select 1) isEqualType "")}
    || {!((_binding select 2) isEqualType 0)} || {!finite (_binding select 2)}
    || {!((_binding select 3) isEqualType 0)} || {!finite (_binding select 3)}
    || {_token == ""} || {(_binding select 1) != _token} || {(_binding select 2) != _expires}
    || {serverTime >= _expires} || {(_binding select 3) <= 0} || {(_binding select 3) != selectMax (_rearRequirements apply {_x select 0})}
    || {!(_movingIndex isEqualType 0)} || {_movingIndex != floor _movingIndex}
    || {_movingIndex < ([1,0] select _crossing)} || {_movingIndex >= count _vehicles}
    || {!(_heldIndices isEqualType [])}
    || {_heldIndices isNotEqualTo ([1,2,3] select {_x > _movingIndex && {_x < count _vehicles}})}
    || {(_binding select 0) != (_vehicles select _movingIndex)}) exitWith {false};
if (_crossing && {_movingIndex != 0 || {!(_crossBinding isEqualType [])} || {count _crossBinding != 4}
    || {(_crossBinding select [0,2]) isNotEqualTo [_token,_expires]}
    || {(_crossBinding select 2) isNotEqualTo (count _vehicles-2)}
    || {!((_crossBinding select 3) in [1,2])}
    || {!(_crossPoses isEqualType [])} || {count _crossPoses != count _vehicles}
    || {_crossPoses findIf {!(_x isEqualType []) || {count _x != 3}
        || {_x findIf {!(_x isEqualType []) || {count _x != 3}
            || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}} >= 0}
    || {!(_crossPath isEqualType [])} || {count _crossPath < 2} || {count _crossPath > 24}
    || {_crossPath findIf {!(_x isEqualType []) || {count _x != 3}
        || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}}) exitWith {false};
private _pathSegmentsValid=true;
if (_crossing) then {
    for "_segment" from 1 to (count _crossPath-1) do {
        private _segmentLength=(_crossPath select _segment) vectorDistance (_crossPath select (_segment-1));
        if (_segmentLength <= 0.01 || {_segmentLength > 8.01}) exitWith {_pathSegmentsValid=false};
    };
};
if (!_pathSegmentsValid) exitWith {false};
private _pathPrepared=_crossing && {count _rootWork > 0}
    && {(_rootWork getOrDefault ["controller",[]]) isEqualTo ["QUEUE",-1]}
    && {(_rootWork getOrDefault ["queueCrossingBinding",[]]) isEqualTo _crossBinding}
    && {(_rootWork getOrDefault ["points",[]]) isEqualTo _crossPath}
    && {(_rootWork getOrDefault ["deadline",-1]) == _expires}
    && {(_rootWork getOrDefault ["phase",""]) in ["PLAN","FOLLOW"]};
private _pathOwned=_pathPrepared && {(_rootWork get "phase") == "FOLLOW"};
if (_localRows && {[_token] call CBE_fnc_DrivingQueueTokenClosed}) exitWith {false};
// ARMED owners must all know the bounded moving context before the leaf receives
// EXECUTE. Until native issue exists, retain the unchanged stationary comparison.
// Pending issued BACK requires its own journal acknowledgement path, not this fallback.
if (!((_agreement getOrDefault ["motionStage",""]) in ["ARMED","CROSSING"])) exitWith {false};
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
        if (!(_original isEqualType []) || {count _original != 11}) exitWith {_valid=false};
        if (_crossing && {_moving} && {_pathOwned}) then {
            private _taskKey=["driverTask","operatorTask"] select (_x == 3);
            private _goalKey=["driverCommand","command"] select (_x == 3);
            if ((_actor select [0,8]) isNotEqualTo (_original select [0,8])
                || {(_actor select 10) isNotEqualTo (_original select 10)}
                || {toUpperANSI (_actor select 8) != (_rootWork getOrDefault [_taskKey,"__MISSING__"])}
                || {(_actor select 9) isNotEqualTo (_rootWork getOrDefault [_goalKey,[]])}
                || {(_rootWork getOrDefault ["group",grpNull]) != (_actor select 2)}
                || {(_rootWork getOrDefault ["route",[]]) isNotEqualTo (_original select 10)}
                || {(_rootWork getOrDefault [["driver","operator"] select (_x == 3),objNull]) != (_actor select 0)}) then {_valid=false};
        } else {
            private _pendingStop=false;
            if (_crossing && {_moving} && {!(_localRows && {local _vehicle})}
                && {serverTime <= (_agreement getOrDefault ["crossingIssueUntil",-1])}
                && {(_actor select [0,8]) isEqualTo (_original select [0,8])}
                && {(_actor select 10) isEqualTo (_original select 10)} && {toUpperANSI (_actor select 8) == "STOP"}) then {
                private _goal=(_actor select 9) param [0,[]];
                _pendingStop=_goal isEqualType [] && {count _goal == 3}
                    && {_goal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                    && {_goal distance2D (getPosATL _vehicle) <= 3};
            };
            if (_actor isNotEqualTo _original && {!_pendingStop}) then {_valid=false};
        };
    } forEach [2,3];
    if (!_valid) exitWith {};
    private _pose=_row select 4;private _before=_old select 4;
    if (!(_before isEqualType []) || {count _before != 3}
        || {_before findIf {!(_x isEqualType []) || {count _x != 3}
            || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}) exitWith {_valid=false};
    if (abs ((vectorMagnitude (_before select 1))-1) > 0.01
        || {abs ((vectorMagnitude (_before select 2))-1) > 0.01}
        || {abs ((_before select 1) vectorDotProduct (_before select 2)) > 0.02}) exitWith {_valid=false};
    if (_crossing && {_held}) then {
        private _frozenPose=_crossPoses select _forEachIndex;
        if ((_pose select 0) vectorDistance (_frozenPose select 0) > 0.25
            || {(_pose select 1) vectorDotProduct (_frozenPose select 1) < cos 1}
            || {(_pose select 2) vectorDotProduct (_frozenPose select 2) < cos 1}) exitWith {_valid=false};
    };
    if (!_valid) exitWith {};
    private _delta=(_pose select 0) vectorDiff (_before select 0);
    private _forward=_before select 1;private _up=_before select 2;
    private _right=_forward vectorCrossProduct _up;
    private _rear=-(_delta vectorDotProduct _forward);
    private _linear=vectorMagnitude velocity _vehicle;
    private _angular=vectorMagnitude angularVelocity _vehicle;
    if (!finite _linear || {!finite _angular} || {!canMove _vehicle}
        || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {!(_crossing && {_moving}) && {(_pose select 1) vectorDotProduct _forward < cos 5}}
        || {(_pose select 2) vectorDotProduct _up < cos ([5,20] select (_crossing && {_moving}))}
        || {_vehicle getVariable ["CBE_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}) exitWith {_valid=false};
    if (_crossing && {_moving}) then {
        private _native=_row select 5;
        if (toUpperANSI (_native param [0,""]) in ["BACK","DIRECTBYCOMANDER"]
            || {toUpperANSI (_native param [1,""]) in ["LEFT","RIGHT"]}
            || {_linear > (8/3.6)+0.2} || {_angular > 0.5}
            || {!_pathOwned && {vectorMagnitude _delta > 1.5 || {_linear >= 0.1} || {_angular >= 0.01}
                || {(_pose select 1) vectorDotProduct _forward < cos 5}
                || {(_pose select 2) vectorDotProduct _up < cos 5}}}) then {_valid=false};
        if (!_pathOwned) then {
            private _rootPose=_crossPoses select 0;
            if ((_pose select 0) vectorDistance (_rootPose select 0) > 0.25
                || {(_pose select 1) vectorDotProduct (_rootPose select 1) < cos 1}
                || {(_pose select 2) vectorDotProduct (_rootPose select 2) < cos 1}) then {_valid=false};
        };
        if (_pathOwned) then {
            private _nearPath=false;private _rootASL=getPosASL _vehicle;
            for "_segment" from 1 to (count _crossPath-1) do {
                private _start=_crossPath select (_segment-1);private _end=_crossPath select _segment;
                private _axis=_end vectorDiff _start;private _length=vectorMagnitude _axis;
                if (_length > 0.01 && {_length <= 8.01}) then {
                    private _fraction=(((_rootASL vectorDiff _start) vectorDotProduct _axis)/(_length*_length)) max 0 min 1;
                    private _closest=_start vectorAdd (_axis vectorMultiply _fraction);
                    if (_rootASL distance2D _closest <= 3 && {abs ((_rootASL select 2)-(_closest select 2)) <= 2}
                        && {(_pose select 1) vectorDotProduct (vectorNormalized _axis) >= cos 60}) exitWith {_nearPath=true};
                };
            };
            if (!_nearPath) then {_valid=false};
        };
    } else {
    if (_moving || {_held}) then {
        private _moveInput=toUpperANSI ((_row select 5) param [0,""]);
        private _pendingInput=!_held && {(_row select 5) isEqualTo (_old select 5)};
        if (!(_moveInput in ["BACK","STOP"]) && {!_pendingInput}
            || {toUpperANSI ((_row select 5) param [1,""]) != "NONE"}
            || {_rear < -0.25} || {_rear > ((_rearRequirements select _forEachIndex) select 0)+0.5}
            || {abs (_delta vectorDotProduct _right) > 1}
            || {abs (_delta vectorDotProduct _up) > 1.5}
            || {_linear > (10/3.6)} || {_angular > 0.05}
            || {_held && {_moveInput != "STOP" || {_linear >= 0.1} || {_angular >= 0.01}}}) then {_valid=false};
    } else {
        if (vectorMagnitude _delta > 1.5 || {_linear >= (1/3.6)} || {_angular >= 0.01}
            || {(_row select 5) isNotEqualTo (_old select 5)}) then {_valid=false};
    };
    };
    if (!_valid) exitWith {};
    if (_localRows && {local _vehicle}) then {
        // Active reverse/crossing may retain MOVE/STOP while native flight or queued
        // treatment takes over. Remote observation never substitutes for this owner check.
        if ([driver _vehicle,effectiveCommander _vehicle] findIf {
            isNull _x || {!local _x} || {fleeing _x}
                || {(_x getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
        } >= 0) exitWith {_valid=false};
        _localCount=_localCount+1;
        private _group=group driver _vehicle;
        private _brain=_group getVariable ["CBE_Driving_Brain",createHashMap];
        if (_crossing && {_moving}) then {
            if (!_pathPrepared) then {
                if (count _rootWork > 0 || {!([_vehicle,"QUEUE"] call CBE_fnc_DrivingPassCanConsent)}) then {_valid=false};
            } else {
                private _state=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
                private _cap=getForcedSpeed _vehicle;
                if (!local _group || {!local driver _vehicle} || {!local effectiveCommander _vehicle}
                    || {(_rootWork getOrDefault ["group",grpNull]) != _group}
                    || {(_rootWork getOrDefault ["driver",objNull]) != driver _vehicle}
                    || {(_rootWork getOrDefault ["operator",objNull]) != effectiveCommander _vehicle}
                    || {(_rootWork getOrDefault ["route",[]]) isNotEqualTo ((_row select 2) select 10)}
                    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                    || {(_state param [3,grpNull]) != _group} || {!finite _cap} || {_cap < 0} || {_cap > 8/3.6}
                    || {abs ((_state param [0,-100])-_cap) > 0.001}
                    || {!([_group] call CBE_fnc_DrivingMovementAvailable)} || {!([_group] call CBE_fnc_CortexIsEligible)}
                    || {[_group] call CBE_fnc_CortexZeusHeld} || {[_group] call CBE_fnc_CortexExternalTakeover}
                    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
                    || {(_group getVariable ["CBE_Driving_FSM",-1]) < 0}
                    || {completedFSM (_group getVariable ["CBE_Driving_FSM",-1])}
                    || {[driver _vehicle,effectiveCommander _vehicle] findIf {
                        !(_x checkAIFeature "MOVE") || {!(_x checkAIFeature "PATH")}
                            || {!([_x] call CBE_fnc_CortexCombatEffective)} || {[_x] call CBE_fnc_CortexActorMoveReserved}
                    } >= 0}) then {_valid=false};
            };
        } else {
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
                || {private _required=_rearRequirements select _forEachIndex;
                    private _issued=_work getOrDefault ["rearEnvelope",[]];
                    !(_issued isEqualTo _required || {_required isEqualTo [8,6] && {_issued isEqualTo [3.5,2]}})}
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
    };
    if (!_valid) exitWith {};
} forEach _live;
_valid && {!_localRows || {_localCount > 0}}
