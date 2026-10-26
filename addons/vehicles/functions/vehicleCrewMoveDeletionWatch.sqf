/*
 * Author: WaldoTheWarfighter
 * Purpose: Track one scoped platform-deletion callback and retire work whose recorded original crew can no longer write movement.
 * Locality/authority: INSTALL needs the current local platform/group and exact producer journal.
 * DELETED consumes the native callback frame with matching entity/event/private handler
 * ID/reference, local platform/group
 * and the private original-crew snapshot captured while both objects existed. Each original
 * must now be deleted or local and dead. A missing initial object is never loss proof.
 * No native movement, replacement crew, forced control, timer or global observer is created.
 * Repeat/JIP: One local Deleted handler per active selected episode. Exact normal retirement
 * releases it; replacement removes the old handler. New owners install their own callback while
 * maintaining retirement, including unresolved original work. Observing deletion never adopts
 * movement. The old owner removes only its local callback on actual group-locality loss.
 * The genuine deletion event can retire this work despite a still-live old FSM: its platform
 * is being deleted and its only original actors are dead or no longer exist. No alive actor
 * is adopted. Private provenance does not transfer to a new owner with already-missing actors.
 * Arguments: platform OBJECT,objNull; mode STRING,"RELEASE";
 * data ARRAY,[]: INSTALL [work key STRING,group reference key STRING,lease owner STRING];
 * RELEASE exact original reference ARRAY; DELETED [entity OBJECT,event STRING,handler ID NUMBER]
 * passed explicitly by the internal native callback, never as a queued task or public module.
 * Return: BOOL install/release/dead-crew deletion retirement succeeded; not tactical success.
 * Current callers: selected artillery/tactical start/step, shared retirement and group locality cleanup.
 * Example: [_vehicle,"INSTALL",[_workKey,_referenceKey,_leaseOwner]] call CBE_fnc_VehicleCrewMoveDeletionWatch;
 */
params [["_battery",objNull,[objNull]],["_mode","RELEASE",[""]],["_data",[],[[]]]];
if (isNull _battery || {!(_mode in ["INSTALL","RELEASE","DELETED"])}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} && {_mode != "DELETED"}}) exitWith {false};
private _result=false;
isNil {
    _result=call {
        private _watch=_battery getVariable ["CBE_VehicleCrewMove_DeletedWatch",[]];
        private _typed=_watch isEqualType [] && {count _watch == 8}
            && {(_watch select 0) isEqualType []} && {count (_watch select 0) == 5}
            && {(_watch select 1) isEqualType grpNull}
            && {[2,3,4] findIf {!((_watch select _x) isEqualType "") || {(_watch select _x) == ""}} < 0}
            && {(_watch select 5) isEqualType []}
            && {(_watch select 6) isEqualType 0} && {finite (_watch select 6)} && {(_watch select 6) >= 0}
            && {(_watch select 7) isEqualType []} && {count (_watch select 7) == 2}
            && {(_watch select 7) findIf {!(_x isEqualType objNull)} < 0};
        if (_mode == "RELEASE") exitWith {
            if (!_typed || {(_watch select 0) isNotEqualTo _data}) exitWith {false};
            _battery removeEventHandler ["Deleted",_watch select 6];
            _battery setVariable ["CBE_VehicleCrewMove_DeletedWatch",nil];
            true
        };
        if (_mode == "INSTALL") exitWith {
            if (!local _battery || {count _data != 3}
                || {_data findIf {!(_x isEqualType "") || {_x == ""}} >= 0}
                || {_watch isNotEqualTo [] && {!_typed}}) exitWith {false};
            _data params ["_workKey","_referenceKey","_leaseOwner"];
            private _work=_battery getVariable [_workKey,createHashMap];
            if !(_work isEqualType createHashMap) exitWith {false};
            private _group=_work getOrDefault ["group",grpNull];
            private _reference=_work getOrDefault ["reference",[]];
            if (isNull _group || {!local _group} || {count _reference != 5}
                || {(_reference select 0) isNotEqualTo _battery}
                || {(_work getOrDefault ["owner",-1]) != (_reference select 4)}
                || {(_reference select 3) != (_work getOrDefault ["epoch",-1])}
                || {(_group getVariable [_referenceKey,[]]) isNotEqualTo _reference}) exitWith {false};
            private _crew=_work getOrDefault ["crew",[]];
            if (!(_crew isEqualType []) || {count _crew != 2}
                || {_crew findIf {!(_x isEqualType objNull)} >= 0}) exitWith {false};
            if (_typed && {(_watch select 0) isEqualTo _reference}
                && {(_watch select 1) isEqualTo _group} && {(_watch select [2,3]) isEqualTo _data}) exitWith {
                _crew isEqualTo (_watch select 7)
            };
            // Only a private snapshot made while the originals exist can later prove
            // that a null object is a deleted original, rather than missing input.
            if (_crew findIf {isNull _x} >= 0) exitWith {false};
            if (_typed) then {_battery removeEventHandler ["Deleted",_watch select 6]};
            _battery setVariable ["CBE_VehicleCrewMove_DeletedWatch",nil];
            private _publicLease=_group getVariable ["CBE_Cortex_MovementLease",[]];
            private _ours=_publicLease isEqualType [] && {count _publicLease == 2}
                && {(_publicLease select 0) == _leaseOwner}
                && {(_publicLease select 1) isEqualType 0} && {finite (_publicLease select 1)}
                && {(_publicLease select 1) == (_work getOrDefault ["holdUntil",-1])};
            private _leaseSnapshot=if (_ours) then {+_publicLease} else {[]};
            private _id=_battery addEventHandler ["Deleted",{
                params ["_entity"];
                [_entity,"DELETED",[_entity,_thisEvent,_thisEventHandler]] call CBE_fnc_VehicleCrewMoveDeletionWatch;
            }];
            if (!(_id isEqualType 0) || {!finite _id} || {_id < 0}) exitWith {false};
            _battery setVariable ["CBE_VehicleCrewMove_DeletedWatch",[+_reference,_group,_workKey,
                _referenceKey,_leaseOwner,_leaseSnapshot,_id,+_crew]];
            true
        };
        // This branch must be reached synchronously from this actual native handler.
        if (!_typed || {count _data != 3} || {!((_data select 0) isEqualType objNull)}
            || {(_data select 0) isNotEqualTo _battery} || {!((_data select 1) isEqualType "")}
            || {(_data select 1) != "Deleted"} || {!((_data select 2) isEqualType 0)}
            || {!finite (_data select 2)} || {(_data select 2) != (_watch select 6)}
            || {!local _battery}) exitWith {false};
        _watch params ["_reference","_group","_workKey","_referenceKey","_leaseOwner","_publicLease"];
        if (isNull _group || {!local _group}
            || {(_group getVariable [_referenceKey,[]]) isNotEqualTo _reference}) exitWith {false};
        private _work=_battery getVariable [_workKey,createHashMap];
        if (!(_work isEqualType createHashMap)
            || {(_work getOrDefault ["reference",[]]) isNotEqualTo _reference}
            || {(_work getOrDefault ["group",grpNull]) isNotEqualTo _group}
            || {(_work getOrDefault ["owner",-1]) != (_reference select 4)}) exitWith {false};
        private _crew=_work getOrDefault ["crew",[]];
        if (_crew isNotEqualTo (_watch select 7)
            || {_crew findIf {!isNull _x && {!local _x || {alive _x}}} >= 0}) exitWith {false};
        private _reason=if (_crew findIf {isNull _x} >= 0) then {
            "PLATFORM_DELETED_ORIGINAL_CREW_GONE"
        } else {"PLATFORM_DELETED_ORIGINAL_CREW_DEAD"};
        // A newer or unknown public lease also protects its private state from old cleanup.
        private _currentPublicLease=_group getVariable ["CBE_Cortex_MovementLease",[]];
        private _leaseStillOurs=_currentPublicLease isEqualTo []
            || {_publicLease isNotEqualTo [] && {_currentPublicLease isEqualTo _publicLease}};
        if (_publicLease isNotEqualTo [] && {_currentPublicLease isEqualTo _publicLease}) then {
            [_group,_leaseOwner,false] call CBE_fnc_CortexOwnershipLease;
        };
        private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
        if (_leaseStillOurs
            && {(_state getOrDefault ["movementLease",[]]) isEqualTo (_work getOrDefault ["localLease",["UNKNOWN"]])}) then {
            _state deleteAt "movementLease";
        };
        private _terminal=+_work;
        _terminal set ["phase","RETIRED"];_terminal set ["result",_reason];
        _battery setVariable [_workKey,_terminal];
        _group setVariable [_referenceKey,nil,true];
        _group setVariable ["CBE_VehicleCrewMove_DeletionResult",[_reference select 1,_reference select 2,
            _reason,serverTime],true];
        if (_leaseStillOurs && {"operationGeneration" in _work}) then {
            private _generation=_work get "operationGeneration";
            [_group,_generation,"INCOMPLETE",_reason] call CBE_fnc_OperationRelease;
            if ((_state getOrDefault ["vehicleOperationGeneration",-1]) == _generation) then {
                _state deleteAt "vehicleOperationGeneration";
            };
        };
        // The entity is being removed; its own handler ends with it.
        _battery setVariable ["CBE_VehicleCrewMove_DeletedWatch",nil];
        true
    };
};
_result
