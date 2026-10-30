/*
 * Author: WaldoTheWarfighter
 * Purpose: Own one native rappel pose request and exact cleanup as a controlled-executor
 * building block. Does not reserve, exit, rope, move, land or hand over an insertion.
 * Locality/authority: Actor/group owner; START requires original caller-supplied RAPPEL
 * operation, participant, RAPPEL:<token> actor lease and RAPPEL flight-lease revision.
 * Never stamps today's epoch/generation onto an old request. Only supported ordinary human
 * moves and installed AR rifle/pistol no-actions assets; no launcher/chair-pose fallback.
 * Repeat/JIP: One apply and one clear request per original identity, no repair workers.
 * Exact START retry observes only. Native switchMove supplies replication/JIP; compact
 * ten-field custody and seven-field last identity are passive. Full route stays owner-local.
 * Observed authority loss permanently withdraws reset permission. A different native pose
 * permits passive exact-receipt retirement, never a successor animation reset. Unknown
 * cleanup remains reserved; expiry/marker absence/locality alone proves no handover.
 * No simulation/damage/weapon switch, provider API, handler, timer or physics command.
 * Arguments: 0 mode STRING,START (START/RELEASE); 1 actor OBJECT,objNull;
 * 2 aircraft OBJECT,objNull; 3 token STRING,empty; 4 original time deadline NUMBER,-1;
 * 5 original authority ARRAY,[] [group GROUP,owner epoch NUMBER,operation generation NUMBER,
 * flight-lease revision NUMBER]. Capture once at actor-task admission, never reconstruct.
 * START deadline future<=60s; actor lease expiry must exactly match. Clear permission ends
 * at original deadline+30s and is consumed before its one native request.
 * Return Value: BOOL pose observed/applied or exact receipt retired; never physical descent,
 * arrival or whole-task quiescence. False can retain unresolved custody.
 * Current callers: Controlled rappel actor executor integration pending; no module exposed.
 * Example: ["START",soldier1,heli1,_token,_deadline,_originalAuthority] call CBE_fnc_RappelPoseLocal;
 * Limits: <=64 participant/waypoint entries per action, no per-frame caller or new worker.
 * Caller retains native actor-order, physical safety and full cleanup responsibilities.
 * Custom deformation/replication and engine event timing remain physically unverified.
 */
params [["_mode","START",[""]],["_actor",objNull,[objNull]],
    ["_aircraft",objNull,[objNull]],["_token","",[""]],["_deadline",-1,[0]],
    ["_original",[],[[]]]];
if (isNull _actor || {!local _actor} || {!(_mode in ["START","RELEASE"])}
    || {_token == ""} || {count _token > 128} || {!finite _deadline}
    || {count _original != 4} || {!((_original select 0) isEqualType grpNull)}
    || {[1,2,3] findIf {!((_original select _x) isEqualType 0)
        || {!finite (_original select _x)} || {(_original select _x) < 0}} >= 0}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
_original params ["_group","_epoch","_generation","_flightRevision"];
private _identity=[_aircraft,_token,_group,_epoch,_generation,_deadline,_flightRevision];
private _result=false;
isNil {
    _result=call {
        private _receipt=_actor getVariable ["CBE_Rappel_Pose",[]];
        private _poses=["AR_01_Idle_No_Actions","AR_01_Idle_Pistol_No_Actions"];
        private _matches={
            _receipt isEqualType [] && {count _receipt == 10}
                && {(_receipt select 0) isEqualType 0} && {finite (_receipt select 0)}
                && {[_receipt select 1,_receipt select 2,_receipt select 3,_receipt select 4,
                    _receipt select 5,_receipt select 6,_receipt select 8] isEqualTo _identity}
                && {(_receipt select 7) in _poses} && {(_receipt select 9) isEqualType true}
        };
        private _withdraw={
            if (local _actor && {call _matches} && {_receipt select 9}
                && {(_actor getVariable ["CBE_Rappel_Pose",[]]) isEqualTo _receipt}) then {
                private _withdrawn=+_receipt;_withdrawn set [9,false];
                _actor setVariable ["CBE_Rappel_Pose",_withdrawn,true];
            };
            false
        };
        private _routeMatches={
            private _saved=_actor getVariable ["CBE_Rappel_PoseRoute",[]];
            _saved isEqualType [] && {count _saved == 2} && {(_saved select 0) isEqualTo _identity}
                && {(_saved select 1) isEqualType []} && {count (_saved select 1) <= 64}
                && {count waypoints _group <= 64}
                && {([_group] call CBE_fnc_AuthoredRouteReceipt) isEqualTo (_saved select 1)}
        };
        private _retire={
            if (!local _actor || {!(call _matches)}
                || {(_actor getVariable ["CBE_Rappel_Pose",[]]) isNotEqualTo _receipt}) exitWith {false};
            private _saved=_actor getVariable ["CBE_Rappel_PoseRoute",[]];
            if (_saved isEqualType [] && {count _saved == 2} && {(_saved select 0) isEqualTo _identity}) then {
                _actor setVariable ["CBE_Rappel_PoseRoute",nil];
            };
            _actor setVariable ["CBE_Rappel_Pose",nil,true];true
        };
        private _opCurrent={
            private _live=_group getVariable ["CBE_Operation",createHashMap];
            !isNull _group && {local _group} && {group _actor == _group}
                && {(_group getVariable ["CBE_AIPass_Epoch",-1]) isEqualTo _epoch}
                && {(_group getVariable ["CBE_OperationGeneration",-1]) isEqualTo _generation}
                && {_live isEqualType createHashMap} && {(_live getOrDefault ["intent",""]) == "RAPPEL"}
                && {(_live getOrDefault ["generation",-1]) isEqualTo _generation}
                && {(_live getOrDefault ["ownerEpoch",-1]) isEqualTo _epoch}
        };
        private _ordinary={
            local _actor && {alive _actor} && {!isPlayer _actor} && {isNull remoteControlled _actor}
                && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                && {[_actor] call CBE_fnc_CortexCombatEffective}
                && {simulationEnabled _actor} && {!isObjectHidden _actor}
                && {isNull attachedTo _actor} && {vehicle _actor == _actor}
                && {[_group,false,false,true,_actor] call CBE_fnc_CortexIsEligible}
        };
        private _leaseMatches={
            private _lease=_actor getVariable ["CBE_Cortex_ActorMove",[]];
            _lease isEqualType [] && {count _lease == 3}
                && {(_lease select 0) isEqualTo ("RAPPEL:"+_token)}
                && {(_lease select 1) isEqualType []} && {count (_lease select 1) == 3}
                && {(_lease select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {(_lease select 2) isEqualTo _deadline}
        };
        private _flightMatches={
            [_aircraft,"RAPPEL",_token] call CBE_fnc_FlightLeaseValid
                && {((_aircraft getVariable ["CBE_FlightLease",createHashMap]) getOrDefault ["revision",-1]) isEqualTo _flightRevision}
        };
        if (_mode == "RELEASE") exitWith {
            if (!(call _matches)) exitWith {false};
            private _animation=_receipt select 7;
            if (toLowerANSI animationState _actor != toLowerANSI _animation) exitWith {call _retire};
            if (!(_receipt select 9)) exitWith {false};
            if ((_receipt select 0) != clientOwner || {!(call _opCurrent)} || {!(call _ordinary)}
                || {!(call _leaseMatches)} || {!(call _routeMatches)}
                || {time > _deadline+30}) exitWith {call _withdraw};
            if ((_actor getVariable ["CBE_Rappel_Pose",[]]) isNotEqualTo _receipt) exitWith {false};
            // Consume the one clear attempt before the native command. Refusal leaves an
            // observer-only receipt, never another animation-repair request.
            _receipt=+_receipt;_receipt set [9,false];
            _actor setVariable ["CBE_Rappel_Pose",_receipt,true];
            _actor switchMove ["",0,1,true];
            if (!local _actor || {toLowerANSI animationState _actor == toLowerANSI _animation}) exitWith {false};
            call _retire
        };
        if (!(call _opCurrent) || {!(call _ordinary)} || {!(call _leaseMatches)}
            || {!(call _flightMatches)} || {count waypoints _group > 64}) exitWith {call _withdraw};
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        private _participants=_operation getOrDefault ["participants",[]];
        if (time >= _deadline || {_deadline > time+60} || {[] call CBE_fnc_CortexIsPaused}
            || {!(_participants isEqualType [])} || {count _participants > 64} || {!(_actor in _participants)}
            || {(_operation getOrDefault ["cancelReason",""]) != ""}
            || {(_operation getOrDefault ["phase","ENDED"]) in ["CANCELLED","COMPLETE","ENDED"]}) exitWith {false};
        private _weapon=currentWeapon _actor;
        if (!(_weapon in ["",primaryWeapon _actor,handgunWeapon _actor])
            || {toLowerANSI getText (configOf _actor >> "moves") != "cfgmovesmalesdr"}) exitWith {false};
        private _animation=_poses select (_weapon != "" && {_weapon == handgunWeapon _actor});
        if (!isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _animation)) exitWith {false};
        private _expected=[clientOwner,_aircraft,_token,_group,_epoch,_generation,_deadline,_animation,_flightRevision,true];
        if (_receipt isNotEqualTo []) exitWith {
            if (!(call _matches) || {!(_receipt select 9)} || {!(call _routeMatches)}) exitWith {call _withdraw};
            // A changed held weapon is not permission to replay or replace the original pose.
            _receipt isEqualTo _expected && {toLowerANSI animationState _actor == toLowerANSI _animation}
        };
        if ((_actor getVariable ["CBE_Rappel_PoseLast",[]]) isEqualTo _identity
            || {(toLowerANSI animationState _actor) find "ar_" == 0}) exitWith {false};
        _actor setVariable ["CBE_Rappel_PoseRoute",[+_identity,[_group] call CBE_fnc_AuthoredRouteReceipt]];
        _actor setVariable ["CBE_Rappel_PoseLast",+_identity,true];
        _actor setVariable ["CBE_Rappel_Pose",_expected,true];
        _actor switchMove [_animation,0,1,true];
        // Actual event timing is engine-dependent. Observe current authority and pose
        // after this request without asserting an intra-call scheduler suspension.
        private _after=_group getVariable ["CBE_Operation",createHashMap];
        if (!(call _opCurrent) || {!(call _ordinary)} || {!(call _leaseMatches)}
            || {!(call _flightMatches)} || {!(call _routeMatches)}
            || {(_after getOrDefault ["cancelReason",""]) != ""}
            || {(_after getOrDefault ["phase","ENDED"]) in ["CANCELLED","COMPLETE","ENDED"]}) exitWith {
            _receipt=_expected;call _withdraw
        };
        (_actor getVariable ["CBE_Rappel_Pose",[]]) isEqualTo _expected
            && {toLowerANSI animationState _actor == toLowerANSI _animation}
            && {currentWeapon _actor == _weapon}
    };
    false
};
_result
