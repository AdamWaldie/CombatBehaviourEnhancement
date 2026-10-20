/*
 * Author: WaldoTheWarfighter
 * Automatic and explicit admission refuse visibly incapacitated, player-controlled or dormant
 * operating crew before reservation. Remote observations never replace owner-local task checks.
 * Magazine preference is ranked only among currently loaded target-reaching candidates.
 * A stronger but out-of-range shell cannot hide another eligible loaded magazine.
 * Queues a finite mission of bounded bursts on the authoritative server. This is dispatch
 * acceptance, not proof that a shell fired. The selected battery's owner executes later physical
 * fire steps through the shared scheduler.
 * Locality/authority: server-only mission validation and reservation. Requests from headless
 * clients are accepted only when that machine owns the requesting group, spotter or battery;
 * player clients must use the authenticated Zeus path.
 * Repeat/JIP: mission tokens and the battery busy key reject duplicate or stale work. Active
 * server mission state survives owner migration through normal state adoption, but is not JIP
 * replayed as a new fire request and does not survive a mission restart.
 * DANGER is reserved for one exact, owner-authenticated static mortar reacting to a live hostile
 * which its effective commander already knows. It uses the same token, safety, warning and shot
 * confirmation path as other fire missions, but does not require the optional support-artillery
 * feature. Danger, Vehicles and Vehicle Gunnery are its three live gates.
 * Arguments: 0: battery <OBJECT>, objNull selects a same-side gun for the spotter; 1: reported ATL <ARRAY>; 2: error <NUMBER>, 0; 3: mode <STRING>, HE; 4: rounds <NUMBER>, -1; 5: scoot <BOOL/NUMBER>, -1; 6: purpose <STRING>, SUPPORT; 7: spotter <OBJECT>, objNull; 8: enemy <OBJECT>, objNull; 9: retreat requester <GROUP>, grpNull (SUPPORT SMOKE only); 10: counter observer server time <NUMBER>, -1 (local legacy calls derive native last-seen time; remote observer calls require it).
 * Counter missions retain the server cancellation generation through their queued shots.
 * Target coordinates must be finite ATL pairs/triples; error, rounds and numeric scoot
 * defaults must be finite before planning or reservation. Invalid input has no busy/cooldown effect.
 * Return Value: Boolean, request queued or accepted.
 * Current callers: ArtilleryRequest, CounterBattery, Retreat and server mission scripts.
 * Example: [_gun, _reportedPosition, 40] call CBE_fnc_CortexArtilleryFire;
 */
params [["_battery", objNull, [objNull]], ["_target", [], [[]]], ["_error", 0, [0]], ["_mode", "HE", [""]],
    ["_rounds", -1, [0]], ["_scoot", -1, [0, true]], ["_purpose", "SUPPORT", [""]], ["_spotter", objNull, [objNull]], ["_enemy", objNull, [objNull]], ["_requester", grpNull, [grpNull]], ["_observedAt",-1,[0]]];
if (!isServer) exitWith {_this remoteExecCall ["CBE_fnc_CortexArtilleryFire", 2]; true};
// Capture before planning so an off/on during admission cannot adopt the new session.
private _fireEpochs=[missionNamespace getVariable ["CBE_Artillery_SupportFireGeneration",0],
    missionNamespace getVariable ["CBE_Artillery_DangerFireGeneration",0],
    missionNamespace getVariable ["CBE_Artillery_SmokeFireGeneration",0],
    missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0]];
private _retreatSmoke = !isNull _requester;
private _danger = _purpose == "DANGER";
if (_retreatSmoke && {_mode != "SMOKE" || {_purpose != "SUPPORT"} || {!isNull _spotter}}) exitWith {false};
if (remoteExecutedOwner > 2) then {
    // Only AI owners may forward these internal requests. Player clients use authenticated Zeus APIs.
    private _hc = allPlayers findIf {_x isKindOf "HeadlessClient_F" && {owner _x == remoteExecutedOwner}};
    if (_hc < 0 || {if (_retreatSmoke) then {remoteExecutedOwner != groupOwner _requester} else {if (isNull _spotter) then {remoteExecutedOwner != owner _battery} else {remoteExecutedOwner != owner _spotter}}}) then {_purpose = ""};
};
// Validate before range/aim planning and any token, busy or observer cooldown mutation.
if (!(_purpose in ["SUPPORT", "COUNTER", "DANGER"]) || {!(_mode in ["HE", "SMOKE"])}
    || {!(count _target in [2,3])} || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!finite _error} || {!finite _rounds} || {_scoot isEqualType 0 && {!finite _scoot}}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active", false])} || {[] call CBE_fnc_CortexIsPaused}) exitWith {false};
if (_retreatSmoke && {isNull ([_requester] call CBE_fnc_CortexGroupTransmitter)
    || {!([_requester] call CBE_fnc_CortexIsEligible)}
    || {!([_requester,"CBE_AIPass_Artillery_Enable",false] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_requester,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled)}}) exitWith {false};
private _requestSide = if (_retreatSmoke) then {side _requester} else {side group _spotter};
private _counter = _purpose == "COUNTER";
// Preserve observation age across owner/server delivery, before reserving any battery.
if (_counter && {!isNull _spotter}) then {
    if (_observedAt == -1 && {local _spotter} && {!isNull _enemy}) then {
        private _knowledge=_spotter targetKnowledge _enemy;
        if (_knowledge select 1) then {_observedAt=serverTime-((time-(_knowledge select 2)) max 0)};
    };
    if (!finite _observedAt || {_observedAt < 0} || {_observedAt > serverTime+1}
        || {serverTime-_observedAt > 10}) then {_purpose=""};
};
if (_purpose == "") exitWith {false};
private _feature = if (_danger) then {"CBE_AIPass_VehicleGunnery_Enable"} else {["CBE_AIPass_Artillery_Enable", "CBE_AIPass_CounterBattery_Enable"] select _counter};
if (!isNull _spotter && {!([group _spotter,_feature,false] call CBE_fnc_CortexFeatureEnabled)}) exitWith {false};
if (!_danger && {!(missionNamespace getVariable [["CBE_AIPass_Artillery_Enable", "CBE_AIPass_CounterBattery_Enable"] select _counter, false])}) exitWith {false};
if (!isNull _spotter && {!alive _spotter || {!(_spotter getVariable ["CBE_AIPass_Spotter", false])}}) exitWith {false};
if (!isNull _spotter && {time < (_spotter getVariable ["CBE_AIPass_NextFireRequest_" + _purpose, -1])}) exitWith {false};
if (_counter && {!isNull _enemy} && {!isNull _spotter || {!isNull _battery}}) then {
    private _sideKey = str (if (isNull _spotter) then {side group gunner _battery} else {side group _spotter});
    if (time < (_enemy getVariable ["CBE_AIPass_CounterUntil_" + _sideKey, -1])) then {_purpose = ""};
};
if (_purpose == "") exitWith {false};
private _missions = missionNamespace getVariable ["CBE_AIPass_FireMissions", createHashMap];
if (_danger) then {
    private _crewGroup=if (isNull _battery || {isNull gunner _battery}) then {grpNull} else {group gunner _battery};
    private _commander=if (isNull _battery) then {objNull} else {effectiveCommander _battery};
    if (isNull _battery || {isNull _crewGroup} || {isNull _commander} || {isNull _enemy}
        || {!alive _battery} || {!alive _enemy} || {!(_battery isKindOf "StaticMortar")}
        || {isPlayer _commander} || {_commander knowsAbout _enemy <= 0}
        || {(side _crewGroup) getFriend (side _enemy) >= 0.6}
        || {_target distance2D (getPosATL _enemy) > 75}
        || {time < (_battery getVariable ["CBE_AIPass_NextDangerFire",-1])}
        || {!([_crewGroup] call CBE_fnc_CortexIsEligible)}
        || {!([_crewGroup,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_crewGroup,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_crewGroup,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {[_crewGroup] call CBE_fnc_CortexExternalTakeover}) exitWith {_purpose=""};
    _requestSide=side _crewGroup;
};
if (_purpose == "") exitWith {false};
// Server-visible eligibility only. Current actor tasks and inventory remain owner checks.
private _batteryCrewUsable={
    params ["_asset"];
    private _gunner=gunner _asset;
    alive _asset && {simulationEnabled _asset} && {!isObjectHidden _asset}
        && {[_gunner] call CBE_fnc_CortexCombatEffective}
        && {!isPlayer _gunner} && {isNull remoteControlled _gunner}
        && {simulationEnabled _gunner} && {!isObjectHidden _gunner}
};
if (isNull _battery) then {
    private _candidates = missionNamespace getVariable ["CBE_AIPass_AllArtillery", []];
    private _index = _candidates findIf {
        alive _x && {alive gunner _x} && {[_x] call _batteryCrewUsable} && {side group gunner _x == _requestSide}
        && {!((netId _x) in _missions)} && {[_x, _purpose] call CBE_fnc_CortexArtilleryRole}
        && {[group gunner _x] call CBE_fnc_CortexIsEligible}
        && {[group gunner _x,_feature,false] call CBE_fnc_CortexFeatureEnabled}
        && {_mode != "SMOKE" || {[group gunner _x,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled}}
        && {combatMode group gunner _x != "BLUE" && {unitCombatMode gunner _x != "BLUE"}}
        && {_target inRangeOfArtillery [[_x], [_x, _mode == "SMOKE",_target] call CBE_fnc_CortexArtilleryAmmo]}
    };
    if (_index >= 0) then {_battery = _candidates select _index};
};
if (isNull _battery || {!alive gunner _battery} || {!([_battery] call _batteryCrewUsable)} || {(netId _battery) in _missions}
    || {!_danger && {!([_battery, _purpose] call CBE_fnc_CortexArtilleryRole)}}
    || {!([group gunner _battery] call CBE_fnc_CortexIsEligible)}
    || {!([group gunner _battery,_feature,false] call CBE_fnc_CortexFeatureEnabled)}
    || {_mode == "SMOKE" && {!([group gunner _battery,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled)}}
    || {!isNull _spotter && {side group _spotter != side group gunner _battery}}
    || {_retreatSmoke && {_requestSide != side group gunner _battery}}) exitWith {false};
private _magazine = [_battery, _mode == "SMOKE",_target] call CBE_fnc_CortexArtilleryAmmo;
// Explicit batteries need the same range admission as automatically selected candidates.
// Reject before token/busy reservation; later aim checks still enforce safety and live range.
if (_magazine == "" || {combatMode group gunner _battery == "BLUE"} || {unitCombatMode gunner _battery == "BLUE"}
    || {!(_target inRangeOfArtillery [[_battery],_magazine])}) exitWith {false};
if (_danger) then {
    _rounds=1;
    _scoot=false;
    _error=(_error max 0) min 25;
} else {
    if (_rounds < 1) then {_rounds = missionNamespace getVariable [["CBE_AIPass_Artillery_Rounds", "CBE_AIPass_CounterBattery_Rounds"] select _counter, 3]};
    if (_scoot isEqualType 0) then {_scoot = missionNamespace getVariable [["CBE_AIPass_Artillery_ShootAndScoot", "CBE_AIPass_CounterBattery_ShootAndScoot"] select _counter, true]};
};
private _serial = (missionNamespace getVariable ["CBE_AIPass_FireSerial", 0]) + 1;
missionNamespace setVariable ["CBE_AIPass_FireSerial", _serial];
private _token = format ["%1:%2", netId _battery, _serial];
private _mission = createHashMapFromArray [
    ["battery", _battery], ["key", netId _battery], ["token", _token], ["fix", [+_target, _error max 0]], ["mode", _mode], ["purpose", _purpose],
    ["counterGeneration",_fireEpochs select 3],["shotSerial",0],
    ["fireGeneration",_fireEpochs select (if (_counter) then {3} else {[0,1] select _danger})],
    ["smokeGeneration",_fireEpochs select 2],
    ["spotter", _spotter], ["enemy", _enemy], ["requester",_requester], ["remaining", (round _rounds max 1) min 10], ["fired", 0], ["burstSize", (round _rounds max 1) min 10],
    ["burstsLeft", if (_mode == "SMOKE" || {_danger}) then {1} else {(round (missionNamespace getVariable ["CBE_AIPass_Artillery_Bursts", 3]) max 1) min 5}],
    ["burstsCompleted", 0], ["opening", !_danger], ["location", +_target],
    ["offset", if (_danger || {_mode == "SMOKE"}) then {0} else {300}], ["bearing", random 360], ["magazine", _magazine],
    ["phase", "WAIT"], ["due", time], ["deadline", time + 900], ["scoot", _scoot], ["side", side group gunner _battery]
];
if (!isNull _spotter) then {_spotter setVariable ["CBE_AIPass_NextFireRequest_" + _purpose, time + 900]};
if (_counter && {!isNull _enemy}) then {_enemy setVariable ["CBE_AIPass_CounterUntil_" + str (side group gunner _battery), time + 900]};
if (_danger) then {_battery setVariable ["CBE_AIPass_NextDangerFire",time+120,true]};
_missions set [netId _battery, _mission];
missionNamespace setVariable ["CBE_AIPass_FireMissions", _missions];
_battery setVariable ["CBE_AIPass_FireToken", _token, true];
_battery setVariable ["CBE_AIPass_BusyUntil", time + 900, true];
[_mission,0] call CBE_fnc_ArtilleryMissionStart;
true
