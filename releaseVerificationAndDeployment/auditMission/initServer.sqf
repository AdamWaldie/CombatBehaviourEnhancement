/*
 * Author: WaldoTheWarfighter
 * Purpose: Start the packaged CBE audit and provide an observer curator and HC registry.
 * Locality/authority: Dedicated server. Only audit fixtures are created.
 * Repeat/JIP: One initialization per mission; arriving or respawned observers receive the curator.
 * The dangerload preflight starts server-side without an observer and remains guarded by the QA runner.
 * Arguments: None. Return: Nothing. Current callers: engine mission initialization.
 * Example: Launch CBE_Audit.VR with the checked-in launcher.
 */
call compile preprocessFileLineNumbers "auditIdentity.sqf";
if (isNil "CBE_AITweaks_PostInitComplete") exitWith {diag_log "CBE AUDIT ERROR: addon absent"};
private _spawn=createMarker ["respawn_west",[5800,5800,0]];
_spawn setMarkerType "Empty";
private _logicGroup=createGroup sideLogic;
private _curator=_logicGroup createUnit ["ModuleCurator_F",[5800,5800,0],[],0,"NONE"];
_curator setVariable ["Addons",3,true];
[_curator] spawn {
    params ["_curator"];
    waitUntil {sleep 0.5; (allPlayers select {isPlayer _x && {!(_x isKindOf "HeadlessClient_F")}}) isNotEqualTo []};
    private _observer=(allPlayers select {isPlayer _x && {!(_x isKindOf "HeadlessClient_F")}}) select 0;
    _observer assignCurator _curator;
    _curator addCuratorEditableObjects [allUnits + vehicles,true];
    diag_log "CBE AUDIT OBSERVER ZEUS READY";
    [] execVM "cortexQAServer.sqf";
    while {!isNull _curator} do {
        sleep 2;
        private _observers=allPlayers select {isPlayer _x && {!(_x isKindOf "HeadlessClient_F")}};
        if (_observers isNotEqualTo []) then {
            private _current=_observers select 0;
            if (getAssignedCuratorLogic _current != _curator) then {
                unassignCurator _curator;
                _current assignCurator _curator;
                diag_log "CBE AUDIT OBSERVER ZEUS READY";
            };
        };
        _curator addCuratorEditableObjects [allUnits + vehicles,true];
    };
};
[] spawn {
    while {true} do {
        private _hcs=allPlayers select {_x isKindOf "HeadlessClient_F"};
        missionNamespace setVariable ["CBE_Headless_Clients",_hcs apply {[owner _x,_x]},true];
        sleep 2;
    };
};
// When the mission is hosted alongside CBE, exercise its real authoritative migration funnel so
// CBE receives the published adoption revision and destination-local event. The standalone audit
// retains a deliberately labelled engine-only fallback for packaged CBE-only candidates.
CBE_fnc_HeadlessMigrateGroup={
    params ["_group","_owner"];
    if (isNull _group || {_owner < 2}) exitWith {false};
    if !(isNil "Waldo_fnc_HeadlessMigrateGroup") exitWith {[_group,_owner] call Waldo_fnc_HeadlessMigrateGroup};
    // The fallback is an engine request, not proof of migration. Respect the fixture's
    // exclusion contract and retain a failed return so acceptance cannot infer success.
    if (_owner != 2 && {_group getVariable ["CBE_Headless_ExcludeGroup",false]}) exitWith {false};
    // Newly created groups may still report owner 0 in the creation frame. Wait only
    // for native initialization, never fabricate locality or retry a rejected transfer.
    if (groupOwner _group < 2 && {canSuspend}) then {
        private _readyUntil=diag_tickTime+2;
        waitUntil {
            sleep 0.03;
            isNull _group || {groupOwner _group >= 2} || {diag_tickTime >= _readyUntil}
        };
    };
    if (isNull _group || {groupOwner _group < 2}) exitWith {false};
    if (groupOwner _group == _owner) exitWith {true};
    private _requested=_group setGroupOwner _owner;
    diag_log format ["[CBE AUDIT] Engine-only HC transfer group=%1 owner=%2 requested=%3 actual=%4; CBE migration provider unavailable.",_group,_owner,_requested,groupOwner _group];
    _requested
};
diag_log "CBE AUDIT SERVER READY";
if ((missionNamespace getVariable ["CBE_CortexQA_Focus", "all"]) isEqualTo "dangerload") then {
    [] execVM "cortexQAServer.sqf";
};
