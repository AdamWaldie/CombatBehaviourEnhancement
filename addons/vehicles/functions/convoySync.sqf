/*
 * Author: WaldoTheWarfighter
 * Applies an ordered convoy registry on server/headless machines and queues bounded maintenance through the shared scheduler.
 * Locality/authority: server owns registration; driving commands execute only on current owners.
 * Repeat/JIP: ordered registry snapshots replace old settings; owner-local paths rebuild on migration.
 * Separate passenger owners receive a finite, revision-scoped HALT retry on the shared scheduler.
 * Matching unloaded actors remain in that retry so their owner can execute post-exit cover steps.
 * Each retry handles at most sixteen cargo records and retains the existing safety/task gates.
 * Arguments: 0: revision <NUMBER>; 1: registry <ARRAY> of [group, configuration].
 * Return Value: Nothing.
 * Current callers: SimpleAiConvoy and JIP replay.
 * Example: [_revision, _registry] remoteExecCall ["WAIT_fnc_ConvoySync", 0, "WAIT_Convoy_RegistrySync"];
 */
params ["_revision", "_registry"];
if (remoteExecutedOwner != 2) exitWith {};
if (_revision <= (missionNamespace getVariable ["WAIT_Convoy_ReceivedRevision", -1])) exitWith {};
missionNamespace setVariable ["WAIT_Convoy_ReceivedRevision", _revision];
private _previous = missionNamespace getVariable ["WAIT_Convoy_LocalRegistry", []];
{
    _x params ["_group", "_configuration"];
    private _next = _registry findIf {(_x select 0) == _group};
    if (_next < 0 || {(((_registry select _next) select 1) select 0) != (_configuration select 0)}) then {
        [_group, _configuration, true] call WAIT_fnc_ConvoyDismountLocal;
        private _keepCrew = if (_next < 0) then {[]} else {((_registry select _next) select 1) select 4};
        // Preserve navigation across same-owner halt/resume snapshots. Release clears
        // local state, so saving only inside ConvoyTick is too late.
        private _navigation = _group getVariable ["WAIT_Convoy_LocalState",createHashMap];
        private _retainNavigation = _next >= 0 && {_keepCrew isEqualTo (_configuration select 4)};
        if (_retainNavigation) then {
            // A phase/speed update is not a release. Restoring formation and issuing doFollow
            // here queues native movement immediately before the new HALT/path commands.
            // Keep the existing ownership and seat state through this same-fleet transition.
            _group setVariable ["WAIT_Convoy_LocalState",_navigation];
        } else {
            [_group, true, _configuration select 7, _keepCrew] call WAIT_fnc_ConvoyReleaseLocal;
        };
        private _handler = _group getVariable ["WAIT_Convoy_LocalHandler", -1];
        if (_handler >= 0 && {(_group getVariable ["WAIT_Convoy_Restore", []]) isEqualTo []}) then {
            _group removeEventHandler ["Local", _handler];
            _group setVariable ["WAIT_Convoy_LocalHandler", nil];
        };
    };
} forEach _previous;
missionNamespace setVariable ["WAIT_Convoy_LocalRegistry", _registry];
if (hasInterface && {!isServer}) exitWith {};
[] call WAIT_fnc_CompatibilityHeadlessBridge;
// External managers own transfer selection. WAIT listens only for their confirmed destination-local
// event so a convoy resumes its already-registered route on that owner without starting a second
// headless balancer or replacing a Zeus/player order.
if !(missionNamespace getVariable ["WAIT_Convoy_ACEHeadlessHandlerInstalled",false]) then {
    missionNamespace setVariable ["WAIT_Convoy_ACEHeadlessHandlerInstalled",true];
    ["ace_headless_groupTransferPost", {
        params ["_group","_headlessEntity","_previousOwner","_newOwner","_transferredSuccessfully"];
        if (_transferredSuccessfully && {(isServer || {!hasInterface})} && {clientOwner == _newOwner} && {local _group}) then {
            [_group,_previousOwner,_newOwner,"ACE"] call WAIT_fnc_ConvoyHeadlessAdoptLocal;
        };
    }] call CBA_fnc_addEventHandler;
};
if !(missionNamespace getVariable ["WAIT_Convoy_CompatibilityHeadlessHandlerInstalled",false]) then {
    missionNamespace setVariable ["WAIT_Convoy_CompatibilityHeadlessHandlerInstalled",true];
    ["WAIT_Compatibility_HeadlessMigrated", {
        params ["_group","_previousOwner","_newOwner","_provider"];
        if ((isServer || {!hasInterface}) && {clientOwner == _newOwner} && {local _group}) then {
            [_group,_previousOwner,_newOwner,_provider] call WAIT_fnc_ConvoyHeadlessAdoptLocal;
        };
    }] call CBA_fnc_addEventHandler;
};
{
    _x params ["_group", "_configuration"];
    _group setVariable ["WAIT_Convoy_Restore", _configuration select 7];
    _group setVariable ["WAIT_Convoy_CrewDue", -1];
    _group setVariable ["WAIT_Convoy_NextTick", -1];
    _group setVariable ["WAIT_Convoy_Suspended", false];
    [_group, _configuration] call WAIT_fnc_ConvoyCrewLocal;
    if (!local _group && {(_configuration param [5,""]) == "HALT"}
        && {(_configuration param [6,[]]) findIf {local (_x select 0)} >= 0}) then {
        [{
            params ["_job"];
            private _convoy=_job get "convoy";
            private _configuration=_job get "configuration";
            if (isNull _convoy || {local _convoy} || {time >= (_job get "deadline")}
                || {(_job get "revision") != (missionNamespace getVariable ["WAIT_Convoy_ReceivedRevision",-1])}) exitWith {-1};
            private _current=(missionNamespace getVariable ["WAIT_Convoy_LocalRegistry",[]]) findIf {
                (_x select 0) == _convoy && {(_x select 1) isEqualTo _configuration}
            };
            if (_current < 0) exitWith {-1};
            private _cargo=_configuration param [6,[]];
            private _cursor=_job get "cursor";
            private _records=_cargo select [_cursor,16];
            private _slice=_records select {
                _x params ["_unit","_vehicle"];
                local _unit && {[_unit] call WAIT_fnc_CortexCombatEffective} && {!isPlayer _unit}
                    && {vehicle _unit == _vehicle || {isNull objectParent _unit
                        && {(_unit getVariable ["WAIT_Convoy_Unloaded",[]]) isEqualTo [_convoy,_job get "revision"]}}}
                    && {!([group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover)}
            };
            if (_slice isNotEqualTo []) then {_job set ["cyclePending",true]};
            private _nextCursor=_cursor+count _records;
            private _finishedCycle=_nextCursor >= count _cargo;
            if (_finishedCycle && {!(_job get "cyclePending")}) exitWith {-1};
            _job set ["cursor",[ _nextCursor,0] select _finishedCycle];
            if (_finishedCycle) then {_job set ["cyclePending",false]};
            private _packet=+_configuration;
            private _vehicles=[];{_vehicles pushBackUnique (_x select 1)} forEach _slice;
            _packet set [4,_vehicles];_packet set [6,_slice];
            if (_slice isNotEqualTo []) then {[_convoy,_packet] call WAIT_fnc_ConvoyCrewLocal};
            5
        },createHashMapFromArray [["subsystem","CONVOY"],["convoy",_group],["configuration",_configuration],
            ["revision",_revision],["deadline",time+90],["cursor",0],["cyclePending",false]],2,
            format ["WAIT_CONVOY_PASSENGER_HALT_%1_%2",str _group,clientOwner]] call WAIT_fnc_CortexQueueJob;
    };
    if (isNil {_group getVariable "WAIT_Convoy_LocalHandler"}) then {
        _group setVariable ["WAIT_Convoy_LocalHandler", _group addEventHandler ["Local", {
            params ["_group", "_isLocal"];
            private _brain=_group getVariable ["WAIT_Convoy_Brain",createHashMap];
            if (count _brain > 0) then {_brain set ["cancelled",true];_brain set ["cancelReason",["OWNERSHIP_LOST","LOCALITY_GAINED"] select _isLocal]};
            if (_isLocal && {!(_group getVariable ["WAIT_Convoy_Active", false])}) then {[_group] call WAIT_fnc_ConvoyReleaseLocal};
            _group setVariable ["WAIT_Convoy_LocalState", nil];
        }]];
    };
} forEach _registry;
// A pre-consolidation runtime may still have installed the old convoy-specific handler.
// Retire it once before scheduling the revision-scoped jobs below.
private _legacyHandler = missionNamespace getVariable ["WAIT_Convoy_Worker", -1];
if (_legacyHandler >= 0) then {
    [_legacyHandler] call CBA_fnc_removePerFrameHandler;
    missionNamespace setVariable ["WAIT_Convoy_Worker", nil];
};
missionNamespace setVariable ["WAIT_Convoy_SchedulerActive",_registry isNotEqualTo []];
if (_registry isNotEqualTo []) then {
    {
        _x params ["_group","_configuration"];
        if (!isNull _group) then {
            private _jobToken=format ["%1:%2:SYNC",_revision,clientOwner];
            _group setVariable ["WAIT_Convoy_LocalJobToken",_jobToken];
            [_group,_configuration,_revision,_jobToken] call WAIT_fnc_ConvoyOperationStart;
        };
    } forEach _registry;
};
[] call WAIT_fnc_SchedulerReconcile;
