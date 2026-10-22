/*
 * Author: WaldoTheWarfighter
 * Private ownerOrders capture local native destinations before ACK; duplicates retain exact proof.
 * Purpose: Validates actual-owner queue-role consent and receives matching server results.
 * Locality/authority: Only authenticated server remote calls. Each owner validates its own crew/native orders/current brain plus canonical topology; public markers never count as ACK.
 * Repeat/JIP: Exact token/serial/context/roles/original expiry; duplicate agreed delivery does not renew or replay.
 * One timer per accepted phase retires matching local receipts even after movement scheduling
 * stops. Exact root request metadata retires with terminal results or matching consent expiry.
 * Old-machine private metadata can retire after locality loss; no command is issued.
 * Valid duplicate VERIFY cannot downgrade AGREED; stale owner context releases exact consent.
 * Machine-private original-expiry closures reject deferred readmission, including after local retirement.
 * Explicit server COMMIT arms a hold request only after exact AGREED consent; no native
 * movement, reservation or JIP commands. The existing driving cap writer executes the hold.
 * VERIFY and COMMIT preflight only the actual-owner dependency leaf with the shared
 * long/short rear observer. Blocked leaf refuses before a committed hold; no target
 * is retained and command admission must resample. At most two bounded rear observations
 * per leaf preflight; no recurring scan or new worker.
 * Arguments: 0 mode STRING empty VERIFY/RESULT/COMMIT/PREPARE/ARM/EXECUTE/CHECK_ROOM/CROSS_PLAN/CROSS_ARM/CROSS_EXECUTE/CROSS_MOVE;1 payload ARRAY [],[token,serial,vehicles,roles,dependencies,context,deadline,expires,optional phase]. COMMIT uses the nine-field AGREED message; ARM/EXECUTE optionally append [phaseSerial,movingIndex,heldIndices]; CHECK_ROOM/CROSS_PLAN append request serial1..2 and phaseSerial. CROSS_PLAN stores a private geometry proposal only. CROSS_ARM/CROSS_EXECUTE/CROSS_MOVE append [phaseSerial,planSerial,pathASL,participantPoses]; installation precedes all-owner acknowledgement and root-only grant.
 * PREPARE binds all this owner's settled participants to original token/expiry and their brains.
 * PREPARED acknowledges only those verified applied holds; the server waits for every owner.
 * It adds no timer, native command, cached clearance or execution permission.
 * Positive consent ACK includes the exact derived rear requirements; the server rejects
 * any different per-vehicle plan under the same context/token. Negative ACK needs no plan.
 * ARM acknowledges phase installation on every owner before leaf-only EXECUTE may grant
 * future issue admission. Neither path issues a native command; actual issue must revalidate.
 * Duplicate installed phases/grants do not rewind a running native leg.
 * Return: BOOL reply/result handled, never native issue or physical success.
 * Current callers: DrivingQueueAgreementServer only.
 * Example: ["VERIFY",_payload] remoteExecCall ["CBE_fnc_DrivingQueueAgreementOwner",_owner];
 */
params [["_mode","",[""]],["_payload",[],[[]]]];
if (remoteExecutedOwner != 2 || {!(_mode in ["VERIFY","RESULT","COMMIT","PREPARE","ARM","EXECUTE","CHECK_ROOM","CROSS_PLAN","CROSS_ARM","CROSS_EXECUTE","CROSS_MOVE"])}
    || {!(count _payload in (if (_mode in ["CHECK_ROOM","CROSS_PLAN"]) then {[11]} else {
        if (_mode in ["ARM","EXECUTE"]) then {[9,10]} else {if (_mode in ["CROSS_ARM","CROSS_EXECUTE","CROSS_MOVE"]) then {[10]} else {if (_mode == "RESULT") then {[9,10]} else {[[8],[9]] select (_mode != "VERIFY")}}}
    }))}) exitWith {false};
_payload params ["_token","_serial","_vehicles","_roles","_dependencies","_context","_deadline","_expires"];
if (!(_token isEqualType "") || {!(_serial isEqualType 0)} || {!finite _serial}
    || {!(_vehicles isEqualType [])} || {count _vehicles < 2} || {count _vehicles > 4}
    || {_vehicles findIf {!(_x isEqualType objNull)} >= 0}
    || {!(_roles isEqualType [])} || {!(_dependencies isEqualType [])} || {!(_context isEqualType [])}
    || {!(_deadline isEqualType 0)} || {!finite _deadline}
    || {!(_expires isEqualType 0)} || {!finite _expires}) exitWith {false};
private _owned=_vehicles select {!isNull _x && {local _x}};
private _phase=["PENDING",_payload param [8,""]] select (_mode != "VERIFY");
if (_mode == "RESULT" && {!(_phase in ["AGREED","REFUSED","RELEASED"])}) exitWith {false};
if (_mode in ["COMMIT","PREPARE","ARM","EXECUTE","CHECK_ROOM"] && {_phase != "AGREED"}) exitWith {false};
private _receiptKey={
    params ["_receipt"];
    ["token","serial","vehicles","roles","dependencies","context","deadline","expires","phase"] apply {
        _receipt getOrDefault [_x,""]
    }
};
private _scheduleExpiry={
    params ["_key"];
    private _until=[_key select 6,_key select 7] select ((_key select 8) == "AGREED");
    [{
        params ["_vehicles","_key","_receiptKey"];
        isNil {
            private _retired=false;
            {
                if (!isNull _x) then {
                    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
                    if (([_old] call _receiptKey) isEqualTo _key) then {
                        [_key select 0,_key select 7] call CBE_fnc_DrivingQueueTokenClosed;
                        _x setVariable ["CBE_DrivingQueue_Consent",nil];_retired=true;
                        if (_x == ((_key select 2) select 0) && {
                            (_x getVariable ["CBE_DrivingQueue_Request",[]]) isEqualTo
                                [_key select 1,_key select 5,_key select 6,_key select 7]
                        }) then {_x setVariable ["CBE_DrivingQueue_Request",nil]};
                    };
                };
            } forEach _vehicles;
            if (_retired) then {["RELEASE",[_key select 0]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
            false
        };
    },[+_owned,+_key,_receiptKey],(_until-serverTime) max 0] call CBA_fnc_waitAndExecute;
};
// Terminal token cleanup must work even if another participant was deleted or changed owner.
if (_mode == "RESULT" && {_phase in ["REFUSED","RELEASED"]}) exitWith {
    // Preserve exact accepted root completion before closing the token. Cancellation
    // has no tenth field and can never create route-resume authority.
    if (_phase == "RELEASED" && {count _payload == 10} && {_vehicles isNotEqualTo []}) then {
        private _root=_vehicles select 0;private _binding=_payload select 9;
        private _consent=_root getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        private _work=_root getVariable ["CBE_DrivingBypass_Work",createHashMap];
        if (_root in _owned && {_binding isEqualType []} && {count _binding == 4}
            && {(_binding select [0,2]) isEqualTo [_token,_expires]}
            && {(_consent getOrDefault ["token",""]) == _token}
            && {(_consent getOrDefault ["crossingBinding",[]]) isEqualTo _binding}
            && {(_work getOrDefault ["queueCrossingBinding",[]]) isEqualTo _binding}
            && {_work getOrDefault ["queueCrossed",false]}
            && {serverTime < _expires} && {[_consent,true] call CBE_fnc_DrivingQueueReverseCurrent}) then {
            private _completedWork=createHashMapFromArray (keys _work apply {[_x,_work get _x]});
            _completedWork set ["queueClearanceAccepted",_binding];
            _root setVariable ["CBE_DrivingBypass_Work",_completedWork,true];
        };
    };
    [_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;
    private _root=_vehicles select 0;
    if (_root in _owned && {
        (_root getVariable ["CBE_DrivingQueue_Request",[]]) isEqualTo [_serial,_context,_deadline,_expires]
    }) then {_root setVariable ["CBE_DrivingQueue_Request",nil]};
    {private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        if ((_old getOrDefault ["token",""]) == _token) then {_x setVariable ["CBE_DrivingQueue_Consent",nil]};
    } forEach _owned;
    true
};
if (_owned isEqualTo []) exitWith {false};
private _rearRequirements=if (_mode == "VERIFY") then {
    [_vehicles,_context] call CBE_fnc_DrivingQueueRearRequirements
} else {((_owned select 0) getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["rearRequirements",[]]};
if (count _rearRequirements != count _vehicles) exitWith {
    if (_mode == "VERIFY") then {["ACK",[_token,false,[]]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
    false
};
private _motionLimit=selectMax (_rearRequirements apply {_x select 0});
private _tokenClosed=[_token] call CBE_fnc_DrivingQueueTokenClosed;
private _currentPhase=((_owned select 0) getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["phaseSerial",0];
private _phaseMeta=[0,count _vehicles-1,[]];
if (_mode in ["ARM","EXECUTE"] && {count _payload == 10}) then {_phaseMeta=_payload select 9};
if (!(_phaseMeta isEqualType []) || {count _phaseMeta != 3}
    || {_phaseMeta select [0,2] findIf {!(_x isEqualType 0) || {!finite _x} || {_x != floor _x}} >= 0}
    || {(_phaseMeta select 1) < 1} || {(_phaseMeta select 1) >= count _vehicles}
    || {(_phaseMeta select 0) != count _vehicles-1-(_phaseMeta select 1)}
    || {(_phaseMeta select 2) isNotEqualTo ([1,2,3] select {_x > (_phaseMeta select 1) && {_x < count _vehicles}})}) exitWith {false};
private _requestedPhase=_phaseMeta select 0;private _selectedIndex=_phaseMeta select 1;

private _duplicate=_owned findIf {
    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    (_old getOrDefault ["token",""]) != _token || {(_old getOrDefault ["phase",""]) != "AGREED"}
        || {(_old getOrDefault ["serial",-1]) != _serial}
        || {(_old getOrDefault ["vehicles",[]]) isNotEqualTo _vehicles}
        || {(_old getOrDefault ["deadline",-1]) != _deadline}
        || {(_old getOrDefault ["context",[]]) isNotEqualTo _context}
        || {(_old getOrDefault ["roles",[]]) isNotEqualTo _roles}
        || {(_old getOrDefault ["dependencies",[]]) isNotEqualTo _dependencies}
        || {(_old getOrDefault ["rearRequirements",[]]) isNotEqualTo _rearRequirements}
        || {(_old getOrDefault ["expires",-1]) != _expires} || {serverTime >= _expires}
} < 0;
private _crossingInstalled=_duplicate && {_owned findIf {
    ((_x getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["motionStage",""]) != "CROSSING"
} < 0};
// Reverse-phase delivery cannot rewind an installed crossing. Terminal RESULT was
// already handled. Current native/owner proof still determines whether it survives.
if (!_tokenClosed && {_crossingInstalled} && {_mode in ["VERIFY","RESULT","COMMIT","PREPARE","ARM","EXECUTE","CHECK_ROOM","CROSS_PLAN"]}) exitWith {
    private _currentCross=[(_owned select 0) getVariable ["CBE_DrivingQueue_Consent",createHashMap],true] call CBE_fnc_DrivingQueueReverseCurrent;
    if (!_currentCross) then {[_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
    _currentCross
};
if (_mode in ["CROSS_ARM","CROSS_EXECUTE","CROSS_MOVE"]) exitWith {
    private _descriptor=_payload select 9;
    if (_tokenClosed || {!_duplicate} || {!(_descriptor isEqualType [])} || {count _descriptor != 4}
        || {(_descriptor select 0) isNotEqualTo _currentPhase}
        || {_currentPhase != count _vehicles-2} || {!((_descriptor select 1) in [1,2])}) exitWith {false};
    private _root=_vehicles select 0;private _crossBinding=[_token,_expires,_currentPhase,_descriptor select 1];
    private _path=_descriptor select 2;private _poses=_descriptor select 3;
    private _sameCross=_crossingInstalled && {_owned findIf {
        private _consent=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        (_consent getOrDefault ["crossingBinding",[]]) isNotEqualTo _crossBinding
            || {(_consent getOrDefault ["crossingPath",[]]) isNotEqualTo _path}
            || {(_consent getOrDefault ["crossingPoses",[]]) isNotEqualTo _poses}
    } < 0};
    if (_crossingInstalled && {!_sameCross}) exitWith {false};
    if (_sameCross && {_mode == "CROSS_ARM"}) exitWith {
        if (!([(_owned select 0) getVariable ["CBE_DrivingQueue_Consent",createHashMap],true] call CBE_fnc_DrivingQueueReverseCurrent)) exitWith {false};
        ["CROSS_ARMED",[_token,_currentPhase,_descriptor select 1]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];true
    };
    if (_mode == "CROSS_MOVE") exitWith {
        private _consent=_root getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        private _work=_root getVariable ["CBE_DrivingBypass_Work",createHashMap];
        if (!_sameCross || {!(_root in _owned)} || {!(_consent getOrDefault ["crossingGranted",false])}
            || {(_work getOrDefault ["phase",""]) != "FOLLOW"}
            || {(_work getOrDefault ["queueCrossingBinding",[]]) isNotEqualTo _crossBinding}
            || {!([_consent,true] call CBE_fnc_DrivingQueueReverseCurrent)}) exitWith {false};
        if (_consent getOrDefault ["crossingMotionGranted",false]) exitWith {true};
        private _linear=vectorMagnitude velocity _root;private _angular=vectorMagnitude angularVelocity _root;
        if (!finite _linear || {!finite _angular} || {_linear >= 0.1} || {_angular >= 0.01}
            || {abs getForcedSpeed _root > 0.001}) exitWith {false};
        private _next=createHashMapFromArray (keys _consent apply {[_x,_consent get _x]});
        _next set ["crossingMotionGranted",true];_root setVariable ["CBE_DrivingQueue_Consent",_next];true
    };
    if (_mode == "CROSS_EXECUTE" && {!_sameCross || {!(_root in _owned)}}) exitWith {false};
    if (_sameCross && {_mode == "CROSS_EXECUTE"}
        && {(_root getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["crossingGranted",false]}) exitWith {true};
    private _allowed=[(_owned select 0) getVariable ["CBE_DrivingQueue_Consent",createHashMap],true] call CBE_fnc_DrivingQueueReverseCurrent;
    private _rows=[];
    {
        private _target=_x;private _consent=_target getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        private _targetGroup=group driver _target;private _targetBrain=_targetGroup getVariable ["CBE_Driving_Brain",createHashMap];
        private _state=_target getVariable ["CBE_DrivingAssist_State",[]];
        private _linear=vectorMagnitude velocity _target;private _angular=vectorMagnitude angularVelocity _target;
        if ((_consent getOrDefault ["holdApplied",[]]) isNotEqualTo [_token,_targetBrain getOrDefault ["ownerEpoch",-1],_targetBrain getOrDefault ["generation",-1]]
            || {(_state param [0,-1]) != 0} || {(_state param [3,grpNull]) != _targetGroup}
            || {abs getForcedSpeed _target > 0.001} || {!finite _linear} || {!finite _angular}
            || {_linear >= 0.1} || {_angular >= 0.01}) exitWith {_allowed=false};
        if (_target == _root) then {
            private _proposal=_consent getOrDefault ["crossingProposal",[]];
            if (count _proposal != 8 || {!(_proposal select 0)} || {(_proposal select 3) isNotEqualTo _path}
                || {(_proposal select 7) isNotEqualTo [_token,_expires,_currentPhase,_poses]}
                || {(_consent getOrDefault ["crossingPlanReceipt",[]]) isNotEqualTo [_descriptor select 1,_currentPhase,true,_proposal select 1]}) then {_allowed=false};
        };
        private _next=createHashMapFromArray (keys _consent apply {[_x,_consent get _x]});
        _next set ["motionBinding",[_root,_token,_expires,_motionLimit]];_next set ["motionStage","CROSSING"];
        _next set ["movingIndex",0];_next set ["heldIndices",[1,2,3] select {_x < count _vehicles}];
        _next set ["crossingBinding",_crossBinding];_next set ["crossingPath",_path];_next set ["crossingPoses",_poses];
        if (_mode == "CROSS_ARM") then {
            _next set ["crossingIssueUntil",(serverTime+2) min _expires];
            _next set ["crossingMotionGranted",false];
        };
        _next set ["executionGranted",false];
        _next set ["crossingGranted",_mode == "CROSS_EXECUTE" && {_target == _root}];
        if (!([_next,true] call CBE_fnc_DrivingQueueReverseCurrent)) exitWith {_allowed=false};
        _rows pushBack [_target,_next];
    } forEach _owned;
    if (!_allowed) exitWith {[_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];false};
    {_x params ["_target","_next"];_target setVariable ["CBE_DrivingQueue_Consent",_next]} forEach _rows;
    if (_mode == "CROSS_ARM") then {["CROSS_ARMED",[_token,_currentPhase,_descriptor select 1]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
    true
};
// An installed motion phase owns duplicate initial handshake delivery, including
// phase zero while its first vehicle is already reversing. Recheck current native
// authority; never compare movement against the original stationary admission or
// replay PREPARE. Terminal RESULT has already retired its token above.
private _motionInstalled=_duplicate && {_owned findIf {
    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    (_old getOrDefault ["motionStage",""]) != "ARMED"
        || {count (_old getOrDefault ["motionBinding",[]]) != 4}
        || {(_old getOrDefault ["phaseSerial",0]) != _currentPhase}
} < 0};
if (!_tokenClosed && {_motionInstalled} && {_mode in ["VERIFY","RESULT","COMMIT","PREPARE"]}) exitWith {
    private _stillCurrent=[(_owned select 0) getVariable ["CBE_DrivingQueue_Consent",createHashMap],true]
        call CBE_fnc_DrivingQueueReverseCurrent;
    if (!_stillCurrent) then {
        [_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;
        {private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
            if ((_old getOrDefault ["token",""]) == _token) then {_x setVariable ["CBE_DrivingQueue_Consent",nil]};
        } forEach _owned;
        ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
    };
    _stillCurrent
};
if (!_tokenClosed && {_duplicate} && {_mode in ["ARM","EXECUTE"]}
    && {_requestedPhase < _currentPhase}) exitWith {true};
if (_mode in ["ARM","EXECUTE"] && {_requestedPhase > _currentPhase+1
    || {_mode == "EXECUTE" && {_requestedPhase != _currentPhase}}}) exitWith {false};
if (_mode == "CROSS_PLAN") exitWith {
    private _root=_vehicles select 0;private _planSerial=_payload select 9;private _planPhase=_payload select 10;
    if (_tokenClosed || {!_duplicate} || {!(_root in _owned)}
        || {!(_planSerial isEqualType 0)} || {!(_planSerial in [1,2])}
        || {!(_planPhase isEqualType 0)} || {_planPhase != _currentPhase}) exitWith {false};
    private _rootConsent=_root getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    if ((_rootConsent getOrDefault ["movingIndex",-1]) != 1
        || {_currentPhase != count _vehicles-2}
        || {!([_rootConsent,true] call CBE_fnc_DrivingQueueReverseCurrent)}) exitWith {false};
    private _before=_rootConsent getOrDefault ["crossingPlanReceipt",[]];
    if (_before isEqualType [] && {count _before == 4} && {(_before select 0) >= _planSerial}) exitWith {true};
    private _yield=_vehicles select 1;
    private _solid=[0,_yield,_root distance _yield,time,0,"STATIC",0,0,[getPosWorld _yield,vectorDir _yield,vectorUp _yield]];
    private _proposal=[_root,_solid,[1,-1] select (_planSerial == 2),[],_rootConsent] call CBE_fnc_DrivingBypassPlan;
    if (serverTime >= _expires || {(_root getVariable ["CBE_DrivingQueue_Consent",createHashMap]) isNotEqualTo _rootConsent}
        || {!([_rootConsent,true] call CBE_fnc_DrivingQueueReverseCurrent)}) exitWith {false};
    private _next=createHashMapFromArray (keys _rootConsent apply {[_x,_rootConsent get _x]});
    _next set ["crossingPlanReceipt",[_planSerial,_currentPhase,_proposal select 0,_proposal select 1]];
    _next set ["crossingProposal",if (_proposal select 0) then {_proposal} else {[]}];
    _root setVariable ["CBE_DrivingQueue_Consent",_next];
    // Geometry evidence is not an execution acknowledgement. No native/cap writer here.
    private _planResult=[_proposal select 0,_proposal select 1];
    if (_proposal select 0) then {_planResult append [_proposal select 3,(_proposal select 7) select 3]};
    ["CROSS_PLANNED",[_token,_root,_currentPhase,_planSerial,_planResult]]
        remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
    true
};
if (_mode == "CHECK_ROOM") exitWith {
    if (_tokenClosed || {!_duplicate} || {count _vehicles < 3}) exitWith {false};
    private _requestedRoomPhase=_payload select 10;
    if (!(_requestedRoomPhase isEqualType 0) || {_requestedRoomPhase != _currentPhase}) exitWith {false};
    private _moving=((_owned select 0) getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["movingIndex",count _vehicles-1];
    if (_moving <= 1) exitWith {false};
    private _parent=_vehicles select (_moving-1);private _leaf=_vehicles select _moving;
    if (!(_parent in _owned)) exitWith {false};
    private _roomSerial=_payload select 9;
    if (!(_roomSerial isEqualType 0) || {!finite _roomSerial} || {!(_roomSerial in [1,2])}) exitWith {false};
    private _consent=_parent getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    private _observation=[_parent,_consent] call CBE_fnc_DrivingQueueParentRoom;
    ["ROOM",[_token,_parent,_leaf,_currentPhase,_roomSerial,_observation]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
    _observation select 0
};
// Repeated authenticated ARM/EXECUTE never reapply phase metadata or rewind a
// running leg. Returning the prior acknowledgement is not new movement authority.
if (!_tokenClosed && {_duplicate} && {_mode in ["ARM","EXECUTE"]}) then {
    private _motion=[_vehicles select _selectedIndex,_token,_expires,_motionLimit];
    private _already=_owned isNotEqualTo [] && {_owned findIf {
        private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        (_old getOrDefault ["phaseSerial",0]) != _requestedPhase
            || {(_old getOrDefault ["motionBinding",[]]) isNotEqualTo _motion}
            || {(_old getOrDefault ["motionStage",""]) != "ARMED"}
            || {_mode == "EXECUTE" && {_x == (_motion select 0)}
                && {!(_old getOrDefault ["executionGranted",false])}}
    } < 0} && {_mode != "EXECUTE" || {(_motion select 0) in _owned}};
    if (_already) then {_mode=["ARM_DUPLICATE","EXECUTE_DUPLICATE"] select (_mode == "EXECUTE")};
};
if (_mode in ["ARM_DUPLICATE","EXECUTE_DUPLICATE"]) exitWith {
    if (_mode == "ARM_DUPLICATE") then {["ARMED",[_token,_requestedPhase]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
    true
};
private _accepted=!_tokenClosed && {serverTime < ([_deadline,_expires] select (_mode == "RESULT" || {_duplicate}))}
    && {if (_currentPhase > 0 || {_mode in ["ARM","EXECUTE"] && {_requestedPhase > 0}}) then {
        [(_owned select 0) getVariable ["CBE_DrivingQueue_Consent",createHashMap],true] call CBE_fnc_DrivingQueueReverseCurrent
    } else {[_vehicles,_roles,_dependencies,_context,true] call CBE_fnc_DrivingQueueProposalCurrent}};
{
    if (_x == (_vehicles select 0)) then {
        private _request=_x getVariable ["CBE_DrivingQueue_Request",[]];
        if (count _request != 4 || {(_request select 0) != _serial}
            || {(_request select 1) isNotEqualTo _context} || {(_request select 2) != _deadline}
            || {(_request select 3) != _expires}) then {_accepted=false};
    };
    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    if (_mode == "RESULT" && {_phase == "AGREED"} && {
        (_old getOrDefault ["token",""]) != _token || {(_old getOrDefault ["serial",-1]) != _serial}
        || {(_old getOrDefault ["context",[]]) isNotEqualTo _context}
        || {(_old getOrDefault ["roles",[]]) isNotEqualTo _roles}
        || {(_old getOrDefault ["dependencies",[]]) isNotEqualTo _dependencies}
        || {(_old getOrDefault ["rearRequirements",[]]) isNotEqualTo _rearRequirements}
        || {(_old getOrDefault ["deadline",-1]) != _deadline}
        || {(_old getOrDefault ["expires",-1]) != _expires}
    }) then {_accepted=false};
    if (count _old > 0 && {(_old getOrDefault ["token",""]) != _token}
        && {serverTime < (_old getOrDefault ["expires",-1])}) then {_accepted=false};
} forEach _owned;
// Only the dependency leaf needs rear space before the first reverse. Parents may
// be deliberately blocked by that leaf. This owner-local observation is never cached
// as execution clearance: native issue must obtain another fresh observation.
if (_accepted && {_mode in ["VERIFY","COMMIT"]}) then {
    private _leaf=_vehicles select (count _vehicles-1);
    if (_leaf in _owned) then {
        private _leafPlan=[_leaf,[],24,_rearRequirements select (count _vehicles-1)] call CBE_fnc_DrivingRearPlan;
        private _leafObservation=_leafPlan select 0;
        _accepted=(_leafObservation select 0) && {count (_leafObservation param [4,[]]) == 3}
            && {serverTime < ([_deadline,_expires] select (_mode == "COMMIT" || {_duplicate}))}
            && {[_vehicles,_roles,_dependencies,_context,true] call CBE_fnc_DrivingQueueProposalCurrent};
    };
};
if (_mode in ["ARM","EXECUTE"]) exitWith {
    private _leaf=_vehicles select _selectedIndex;
    private _motion=[_leaf,_token,_expires,_motionLimit];private _rows=[];
    private _allowed=_duplicate && {_accepted} && {_owned isNotEqualTo []}
        && {_mode != "EXECUTE" || {_leaf in _owned}};
    {
        private _target=_x;private _targetGroup=group driver _target;
        private _targetBrain=_targetGroup getVariable ["CBE_Driving_Brain",createHashMap];
        private _consent=_target getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        private _binding=[_token,_expires,_targetBrain getOrDefault ["ownerEpoch",-1],_targetBrain getOrDefault ["generation",-1]];
        private _applied=[_token,_binding select 2,_binding select 3];
        private _state=_target getVariable ["CBE_DrivingAssist_State",[]];
        private _linear=vectorMagnitude velocity _target;private _angular=vectorMagnitude angularVelocity _target;
        if ((_consent getOrDefault ["executionPreparation",[]]) isNotEqualTo _binding
            || {(_consent getOrDefault ["holdApplied",[]]) isNotEqualTo _applied}
            || {(_state param [0,-1]) != 0} || {(_state param [3,grpNull]) != _targetGroup}
            || {abs getForcedSpeed _target > 0.001}
            || {!finite _linear} || {!finite _angular} || {_linear >= 0.1} || {_angular >= 0.01}
            || {(_consent getOrDefault ["phaseSerial",0]) != _currentPhase}
            || {_mode == "EXECUTE" && {(_consent getOrDefault ["motionBinding",[]]) isNotEqualTo _motion
                || {(_consent getOrDefault ["motionStage",""]) != "ARMED"}}}) exitWith {_allowed=false};
        private _next=createHashMapFromArray (keys _consent apply {[_x,_consent get _x]});
        _next set ["motionBinding",+_motion];_next set ["motionStage","ARMED"];
        _next set ["phaseSerial",_requestedPhase];_next set ["movingIndex",_selectedIndex];
        _next set ["heldIndices",+(_phaseMeta select 2)];
        if (_mode == "ARM") then {_next set ["executionGranted",false]};
        if (!([_next,true] call CBE_fnc_DrivingQueueReverseCurrent)) exitWith {_allowed=false};
        if (_mode == "EXECUTE" && {_target == _leaf}) then {_next set ["executionGranted",true]};
        _rows pushBack [_target,_next];
    } forEach _owned;
    if (!_allowed) exitWith {
        [_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;
        ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];false
    };
    {_x params ["_target","_next"];_target setVariable ["CBE_DrivingQueue_Consent",_next]} forEach _rows;
    if (_mode == "ARM") then {["ARMED",[_token,_requestedPhase]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
    true
};
if (_mode == "PREPARE") exitWith {
    private _preparedRows=[];
    private _canPrepare=_duplicate && {_accepted} && {_owned isNotEqualTo []};
    {
        private _heldVehicle=_x;
        private _heldGroup=group driver _heldVehicle;
        private _heldBrain=_heldGroup getVariable ["CBE_Driving_Brain",createHashMap];
        private _consent=_heldVehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        private _applied=[_token,_heldBrain getOrDefault ["ownerEpoch",-1],_heldBrain getOrDefault ["generation",-1]];
        private _state=_heldVehicle getVariable ["CBE_DrivingAssist_State",[]];
        private _linear=vectorMagnitude velocity _heldVehicle;private _angular=vectorMagnitude angularVelocity _heldVehicle;
        private _binding=[_token,_expires,_applied select 1,_applied select 2];
        private _before=_consent getOrDefault ["executionPreparation",[]];
        if (!(_consent getOrDefault ["committed",false])
            || {!(_consent getOrDefault ["holdReadySent",false])}
            || {(_consent getOrDefault ["holdApplied",[]]) isNotEqualTo _applied}
            || {!local _heldGroup} || {(_heldBrain getOrDefault ["ownerEpoch",-1]) != (_heldGroup getVariable ["CBE_AIPass_Epoch",0])}
            || {(_state param [0,-1]) != 0} || {(_state param [3,grpNull]) != _heldGroup}
            || {abs getForcedSpeed _heldVehicle > 0.001} || {!finite _linear} || {!finite _angular}
            || {_linear >= 0.1} || {_angular >= 0.01}
            || {_before isNotEqualTo [] && {_before isNotEqualTo _binding}}) exitWith {_canPrepare=false};
        private _prepared=createHashMapFromArray (keys _consent apply {[_x,_consent get _x]});
        _prepared set ["executionPreparation",_binding];
        _preparedRows pushBack [_heldVehicle,_prepared];
    } forEach _owned;
    if (!_canPrepare) exitWith {
        [_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;
        ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];false
    };
    // Publish all owner-local metadata before acknowledging. No partial successful
    // preparation or duplicate can renew expiry or become a native movement grant.
    {_x params ["_heldVehicle","_prepared"];_heldVehicle setVariable ["CBE_DrivingQueue_Consent",_prepared]} forEach _preparedRows;
    ["PREPARED",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
    true
};
if (_mode == "COMMIT") exitWith {
    if (!_duplicate || {!_accepted}) exitWith {
        [_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;
        {private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
            if ((_old getOrDefault ["token",""]) == _token) then {_x setVariable ["CBE_DrivingQueue_Consent",nil]};
        } forEach _owned;
        ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];false
    };
    {
        private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        if !(_old getOrDefault ["committed",false]) then {
            private _armed=createHashMapFromArray (keys _old apply {[_x,_old get _x]});
            _armed set ["committed",true];_x setVariable ["CBE_DrivingQueue_Consent",_armed];
        };
    } forEach _owned;
    true
};
if (_duplicate) exitWith {
    // Delivery is deferred network work: matching receipt values do not establish that
    // this owner's native order and controller admission still match the proposal.
    // Server topology checks cannot replace these owner-local checks. Do not renew.
    if (!_accepted) exitWith {
        [_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;
        {
            private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
            if ((_old getOrDefault ["token",""]) == _token) then {
                _x setVariable ["CBE_DrivingQueue_Consent",nil];
            };
        } forEach _owned;
        ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
        false
    };
    if (_mode == "VERIFY") then {["ACK",[_token,true,_rearRequirements]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
    true
};
if (_mode == "VERIFY") exitWith {
    if (_accepted) then {
        private _pendingKey=[_token,_serial,_vehicles,_roles,_dependencies,_context,_deadline,_expires,"PENDING"];
        private _pendingDuplicate=_owned findIf {
            ([_x getVariable ["CBE_DrivingQueue_Consent",createHashMap]] call _receiptKey) isNotEqualTo _pendingKey
        } < 0;
        {_x setVariable ["CBE_DrivingQueue_Consent",createHashMapFromArray [["token",_token],
            ["serial",_serial],["vehicles",_vehicles],["roles",_roles],["dependencies",_dependencies],
            ["context",_context],["rearRequirements",_rearRequirements],["deadline",_deadline],["expires",_expires],["phase","PENDING"],
            ["ownerOrders",[driver _x,effectiveCommander _x] apply {
                [_x,currentCommand _x,+(expectedDestination _x)]
            }]]]} forEach _owned;
        if (!_pendingDuplicate) then {[_pendingKey] call _scheduleExpiry};
    } else {
        [_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;
        {
            private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
            if ((_old getOrDefault ["token",""]) == _token) then {
                _x setVariable ["CBE_DrivingQueue_Consent",nil];
            };
        } forEach _owned;
    };
    ["ACK",[_token,_accepted,_rearRequirements]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];true
};
{
    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    if ((_old getOrDefault ["token",""]) == _token) then {
        if (_accepted && {_phase == "AGREED"}) then {
            private _new=createHashMapFromArray ((keys _old) apply {[_x,_old get _x]});
            _new set ["phase","AGREED"];_x setVariable ["CBE_DrivingQueue_Consent",_new];
        } else {_x setVariable ["CBE_DrivingQueue_Consent",nil]};
    };
} forEach _owned;
if (_phase == "AGREED" && {_accepted}) then {
    [[_token,_serial,_vehicles,_roles,_dependencies,_context,_deadline,_expires,"AGREED"]] call _scheduleExpiry;
};
if (_phase == "AGREED" && {!_accepted}) then {
    [_token,_expires] call CBE_fnc_DrivingQueueTokenClosed;
    ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
};
true
