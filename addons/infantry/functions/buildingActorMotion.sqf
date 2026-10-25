/*
 * Author: WaldoTheWarfighter
 * Purpose: Records or adopts existing clearance-owned native movement/holds without replay.
 * Locality / Authority: Current actor owner; ADOPT/write also require current local CLEAR
 * operation, actor membership/eligibility, original visit nonce, building transform and route.
 * Writes require the actual live building brain and unexpired job. Adoption changes metadata only.
 * Repeat/JIP: One public actor receipt, coalesced by value. Fresh clears have different nonces.
 * RETIRE removes only the supplied group/context, including after operation cancellation.
 * Arguments: 0 mode <STRING, ADOPT>, MOVE/HOLD/ADOPT/RETIRE; 1 actor <OBJECT, objNull>;
 * 2 job <HASHMAP, empty>; 3 target <ARRAY, []>: native AGL for MOVE, sampled ATL for HOLD.
 * Receipt: [group, visitContext, MOVE/HOLD, target (MOVE AGL / HOLD ATL), optional owned-settings triple].
 * Return Value: BOOL - matching metadata recorded/adopted/retired, never physical progress.
 * Current callers: BuildingOperationStep, CortexClearBuilding resume and clearance cleanup.
 * Example: ["ADOPT",soldier1,_job] call CBE_fnc_BuildingActorMotion;
 */
params [["_mode","ADOPT",[""]],["_actor",objNull,[objNull]],
    ["_job",createHashMap,[createHashMap]],["_target",[],[[]]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}
    || {isNull _actor} || {!local _actor} || {!(_mode in ["MOVE","HOLD","ADOPT","RETIRE"])}) exitWith {false};
private _group=_job getOrDefault ["group",grpNull];
private _context=_job getOrDefault ["visitContext",[]];
if (isNull _group || {!(_context isEqualType [])} || {count _context != 4}
    || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}) exitWith {false};
private _positionValid={
    _this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
private _result=false;
isNil {
    _result=call {
        private _receipt=_actor getVariable ["CBE_Cortex_ClearMotion",[]];
        if (_mode == "RETIRE") exitWith {
            if (_receipt isEqualType [] && {count _receipt == 5}
                && {(_receipt select 0) isEqualTo _group} && {(_receipt select 1) isEqualTo _context}) then {
                private _return=_actor getVariable ["CBE_Cortex_ClearEvasionReturn",[]];
                if (count _return == 6 && {(_return select 0) isEqualTo _receipt}) then {
                    _actor setVariable ["CBE_Cortex_ClearEvasionReturn",nil];
                };
                _actor setVariable ["CBE_Cortex_ClearMotion",nil,true];true
            } else {false}
        };
        private _building=_job getOrDefault ["building",objNull];
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        if (!local _group || {group _actor != _group} || {isPlayer _actor} || {!isNull objectParent _actor}
            || {!([_actor] call CBE_fnc_CortexCombatEffective)} || {!simulationEnabled _actor} || {isObjectHidden _actor}
            || {!(_actor checkAIFeature "MOVE")} || {!(_actor checkAIFeature "PATH")}
            || {!isNull remoteControlled _actor}
            || {!isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_actor] call CBE_fnc_CortexActorMoveReserved}
            || {[_actor] call CBE_fnc_CortexExternalOwner != ""}
            || {[_actor] call CBE_fnc_CompatibilityExternalControl}
            || {[_group,false,_actor] call CBE_fnc_CortexExternalTakeover}
            || {[_group] call CBE_fnc_CortexZeusHeld}
            || {isNull _building} || {!alive _building}
            || {(_job getOrDefault ["generation",-1]) != (_group getVariable ["CBE_AIPass_ClearGeneration",-2])}
            || {(_job getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {(_operation getOrDefault ["generation",-2]) != (_job getOrDefault ["operationGeneration",-1])}
            || {(_operation getOrDefault ["intent",""]) != "CLEAR"}
            || {(_operation getOrDefault ["ownerEpoch",-2]) != (_job getOrDefault ["ownerEpoch",-1])}
            || {(_operation getOrDefault ["objective",objNull]) isNotEqualTo _building}
            || {!(_actor in (_operation getOrDefault ["participants",[]]))}
            || {_actor in (_operation getOrDefault ["unavailable",[]])}
            || {(_group getVariable ["CBE_Cortex_ClearVisitContext",[]]) isNotEqualTo _context}
            || {(_context select 0) isNotEqualTo _building}
            || {(_context select 1) isNotEqualTo (_job getOrDefault ["buildingTransform",[]])}
            || {(_context select 2) isNotEqualTo (_job getOrDefault ["hardDeadline",-1])}
            || {(_job getOrDefault ["buildingTransform",[]]) isNotEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
            || {(_job getOrDefault ["nativeOrderReceipt",[]]) isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}) exitWith {false};
        private _kind=_mode;
        private _settings=[];
        if (_mode == "ADOPT") then {
            if (_receipt isEqualType [] && {count _receipt == 5}
                && {(_receipt select 0) isEqualTo _group} && {(_receipt select 1) isEqualTo _context}
                && {(_receipt select 2) in ["MOVE","HOLD"]}
                && {(_receipt select 3) call _positionValid} && {(_receipt select 4) isEqualType []}
                && {count (_receipt select 4) in [0,3]}) then {
                _kind=_receipt select 2;_target=+(_receipt select 3);_settings=+(_receipt select 4);
            };
        };
        if (!(_target call _positionValid) || {!(_kind in ["MOVE","HOLD"])}) exitWith {false};
        private _command=toUpperANSI currentCommand _actor;
        private _native=(expectedDestination _actor) param [0,[],[[]]];
        private _matches=if (_kind == "MOVE") then {
            _command == "MOVE" && {_native call _positionValid} && {_native vectorDistance _target <= 0.25}
        } else {
            _command == "STOP" && {(getPosASL _actor) vectorDistance (ATLToASL _target) <= 1.5}
                && {abs (((getPosASL _actor) select 2)-((ATLToASL _target) select 2)) <= 0.75}
        };
        if (!_matches) exitWith {false};
        if (_mode != "ADOPT") exitWith {
            private _brain=_group getVariable ["CBE_BuildingBrain",createHashMap];
            if ((_brain getOrDefault ["job",createHashMap]) isNotEqualTo _job
                || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
                || {serverTime >= ((_job getOrDefault ["deadline",-1]) min (_job getOrDefault ["hardDeadline",-1]))}) exitWith {false};
            private _stance=_actor getVariable ["CBE_Cortex_ClearStance",""];
            private _baseline=_actor getVariable ["CBE_Cortex_ClearForcedSpeed",[]];
            private _applied=_actor getVariable ["CBE_Cortex_ClearAppliedSpeed",[]];
            if (_actor in (_job getOrDefault ["started",[]])
                && {([_actor,_job,4,"CHECK"] call CBE_fnc_CortexClearSettingsApply) == "OWNED"}
                && {_stance in ["UP","MIDDLE","DOWN","AUTO"]}
                && {_baseline isEqualType 0} && {finite _baseline} && {_applied isEqualType 0} && {finite _applied}
                && {unitPos _actor == "UP"} && {abs ((getForcedSpeed _actor)-_applied) <= 0.1}) then {
                _settings=[_stance,_baseline,_applied];
            };
            private _next=[_group,+_context,_kind,+_target,_settings];
            if (_receipt isNotEqualTo _next) then {_actor setVariable ["CBE_Cortex_ClearMotion",_next,true]};true
        };
        if (_kind == "MOVE") then {
            private _moves=_job getOrDefault ["movementTargets",createHashMap];
            _moves set [netId _actor,+_target];_job set ["movementTargets",_moves];
        } else {
            private _holds=_job getOrDefault ["formationFallbackHolds",createHashMap];
            _holds set [netId _actor,+_target];_job set ["formationFallbackHolds",_holds];
        };
        // Adopt unchanged settings metadata only. Never reapply a stance, cap or native order.
        if (count _settings == 3
            && {([_actor,_job,4,"CHECK"] call CBE_fnc_CortexClearSettingsApply) == "OWNED"}
            && {(_settings select 0) in ["UP","MIDDLE","DOWN","AUTO"]}
            && {(_settings select 1) isEqualType 0} && {finite (_settings select 1)}
            && {(_settings select 2) isEqualType 0} && {finite (_settings select 2)}
            && {(_actor getVariable ["CBE_Cortex_ClearStance",""]) isEqualTo (_settings select 0)}
            && {(_actor getVariable ["CBE_Cortex_ClearForcedSpeed",[]]) isEqualTo (_settings select 1)}
            && {(_actor getVariable ["CBE_Cortex_ClearAppliedSpeed",[]]) isEqualTo (_settings select 2)}
            && {unitPos _actor == "UP"} && {abs ((getForcedSpeed _actor)-(_settings select 2)) <= 0.1}) then {
            private _started=_job getOrDefault ["started",[]];_started pushBackUnique _actor;_job set ["started",_started];
        };
        true
    };
};
_result
