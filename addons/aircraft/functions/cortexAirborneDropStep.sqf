/*
 * Author: WaldoTheWarfighter
 * Runs one airborne insertion started by CBE_fnc_CortexAirborneCheck: soldiers jump one at a time,
 * then the squad is sent to fight once it is on the ground.
 *
 * DROP: every CBE_AIPass_Airborne_JumpInterval seconds the next soldier still aboard jumps
 * (CBE_fnc_CortexParachuteJump). The drop pauses while the aircraft is below
 * CBE_AIPass_Airborne_MinAltitude or over water, and stops if the aircraft is lost or another
 * controller takes the squad; anyone still aboard then stays with the aircraft.
 * LAND: once the surviving original cargo still in this group is on the ground (or180s from
 * the original start), insertion tracking ends. Unrelated pilots/crew/new members cannot count
 * as jumpers or be retasked by the fallback ground order. A cargo-only group without waypoints gets a SAD waypoint
 * on the enemy position that triggered the drop, so it goes and fights rather than standing where it
 * landed. Mixed operating crew/cargo groups automatically form an independent landed squad
 * through CortexAirborneGroundHandover, without moving actors or retasking the crew.
 * Native join/waypoint acknowledgement is assignment only, not ground combat completion.
 * A native STOP retains its hold instead of receiving the fallback ground SAD order.
 * Locality and authority: runs where the group is local; only local soldiers jump.
 *
 * Review contract: Both DROP and LAND recheck eligibility. A landing timeout ends tracking without assigning a ground attack to soldiers still airborne.
 *
 * Exact insertion episodes and owner epochs guard execution and cleanup; legacy jobs retire silently.
 * Matching insertion cleanup retires its group-state climb receipt for repeat use.
 * Every DROP step rechecks live pilot/commander takeover before another passenger exits.
 * Repeat/JIP: current-owner eligibility and automatic feature gates are rechecked before each jump.
 * Attempts rotate through the original roster, including after refusal. Temporarily unavailable
 * passengers still aboard remain pending until the existing deadline; actors leaving the original
 * group are not recalled. Only an accepted exit refreshes the aircraft drop hold.
 * Job-local lastExit records [actor,accepted,local time], not landing/deployment success.
 * Arguments:
 * 0: job state <HASHMAP> - group, aircraft, jumpers, index, phase, target, deadline
 *
 * Return Value:
 * Number - seconds until the next step, or -1 when finished
 *
 * Example:
 * [CBE_fnc_CortexAirborneDropStep, _job, 0] call CBE_fnc_CortexQueueJob;
 * Result: the squad parachutes out one soldier at a time.
 *
 * Current caller: CBE_fnc_CortexAirborneCheck (through the scheduler).
 */

params [["_job", createHashMap, [createHashMap]]];
private _group = _job getOrDefault ["group", grpNull];
private _aircraft = _job getOrDefault ["aircraft", objNull];
private _episode=_job getOrDefault ["episode",[]];
// Obsolete or legacy jobs cannot execute or retire a successor's insertion state.
if (isNull _group || {!local _group} || {_episode isEqualTo []}
    || {(_job getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {_episode isNotEqualTo (_group getVariable ["CBE_AIPass_DropEpisode",[]])}) exitWith {-1};
private _finish = {
    // A stale owner must not clear the successor's insertion bookkeeping. The shared
    // scheduler captures ownerEpoch when queuing this group job.
    private _sameOwner=!isNull _group && {local _group}
        && {(_job getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_episode isEqualTo (_group getVariable ["CBE_AIPass_DropEpisode",[]])};
    if (_sameOwner) then {
        _group setVariable ["CBE_AIPass_Dropping",nil];
        _group setVariable ["CBE_AIPass_DropEpisode",nil,true];
        (_group getVariable ["CBE_AIPass_State",createHashMap]) deleteAt "airborneClimb";
        if (!isNull _aircraft && {local _aircraft}
            && {_episode isEqualTo (_aircraft getVariable ["CBE_AIPass_DropEpisode",[]])}) then {
            _aircraft setVariable ["CBE_AIPass_DropUntil",nil];
            _aircraft setVariable ["CBE_AIPass_DropEpisode",nil,true];
        };
    };
    -1
};
if (isNull _group || {!local _group} || {!(missionNamespace getVariable ["CBE_AIPass_Active", false])}
    || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {!(_job getOrDefault ["forced",false]) && {!([_group,"CBE_AIPass_Airborne_Enable",false] call CBE_fnc_CortexFeatureEnabled)}}) exitWith {call _finish};

if (_episode isNotEqualTo (_aircraft getVariable ["CBE_AIPass_DropEpisode",[]])) exitWith {call _finish};
if ((_job get "phase") == "DROP") exitWith {
    if (time > (_job get "deadline")) exitWith {call _finish};
    private _roster=_job get "jumpers";
    private _cursor=_job getOrDefault ["index",0];
    if (!(_cursor isEqualType 0) || {!finite _cursor} || {_cursor < 0}
        || {_cursor != floor _cursor} || {_cursor >= count _roster}) then {_cursor=0};
    private _ordered=(_roster select [_cursor])+(_roster select [0,_cursor]);
    private _aboard=_roster select {alive _x && {group _x == _group} && {vehicle _x == _aircraft}};
    private _jumpers = _ordered select {
        group _x == _group && {local _x} && {vehicle _x == _aircraft} && {!isPlayer _x}
            && {[_x] call CBE_fnc_CortexCombatEffective}
            && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
            && {isNull remoteControlled _x}
            && {isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
            && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
    };
    if (_aboard isEqualTo [] || {!alive _aircraft}) exitWith {
        _job set ["phase", "LAND"];
        3
    };
    // Aircraft control can change after admission while the passenger squad remains AI-owned.
    private _pilot=driver _aircraft;
    private _commander=effectiveCommander _aircraft;
    if (!([_pilot] call CBE_fnc_CortexCombatEffective) || {isPlayer _pilot}
        || {isPlayer _commander} || {!isNull remoteControlled _pilot}
        || {!isNull remoteControlled _commander}
        || {!isNull (_pilot getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {!isNull (_commander getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[group _pilot] call CBE_fnc_CortexExternalTakeover}
        || {[group _commander] call CBE_fnc_CortexExternalTakeover}) exitWith {call _finish};
    // The jump itself is an owned action. Stop it before the next passenger leaves if Zeus, a
    // player or a specialist controller takes the group; anyone still aboard remains where that
    // new controller expects rather than completing CBE's earlier drop plan.
    if (time > (_job get "deadline") || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {call _finish};
    // A reservation, brief readiness loss or split locality does not mean everyone landed.
    // Keep the original finite deadline; no command is issued to unavailable passengers.
    if (_jumpers isEqualTo []) exitWith {1};
    if (((getPos _aircraft) select 2) < (missionNamespace getVariable ["CBE_AIPass_Airborne_MinAltitude", 120])
        || {surfaceIsWater getPos _aircraft}) exitWith {1};
    private _jumper=_jumpers select 0;
    // Advance after every attempt, so one failed dismount cannot monopolise the batch.
    _job set ["index",((_roster find _jumper)+1) mod count _roster];
    private _accepted=[_jumper, _aircraft] call CBE_fnc_CortexParachuteJump;
    _job set ["lastExit",[_jumper,_accepted,time]];
    if (_accepted) then {_aircraft setVariable ["CBE_AIPass_DropUntil", time + 30]};
    (missionNamespace getVariable ["CBE_AIPass_Airborne_JumpInterval", 1]) max 0.5
};

// LAND
// Landing evidence belongs to the original passenger roster, not aircraft crew
// or later group arrivals. Departed actors remain with their current commander.
private _roster=_job get "jumpers";
private _alive = _roster select {alive _x && {group _x == _group}};
private _landed = _alive findIf {vehicle _x != _x || {!isTouchingGround _x && {((getPosATL _x) select 2) > 2}}} < 0;
if (!_landed && {time < (_job get "deadline")}) exitWith {3};
// A landing can take long enough for a curator or another controller to issue an order after the
// last jumper left. Do not create a SAD waypoint over that replacement order merely because the
// original automatic drop had no route when it started.
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {call _finish};
// A group waypoint controls all its members. Only an entirely inserted cargo
// group may receive this fallback; preserve mixed crew/cargo and later mission actors.
private _groundOrderScoped=_landed && {_alive isNotEqualTo []} && {
    ((units _group) select {alive _x}) findIf {!(_x in _alive)} < 0
};
// Mixed operating crew keeps its group; original grounded cargo forms a real ground squad.
private _groundHandover=["NOT_REQUIRED",grpNull,[],false];
if (_landed && {_alive isNotEqualTo []} && {!_groundOrderScoped}) then {
    _groundHandover=[_job] call CBE_fnc_CortexAirborneGroundHandover;
};
if ((_groundHandover select 0) == "DEFERRED" && {time < (_job get "deadline")}) exitWith {3};
private _groundHandoverOK=(_groundHandover select 0) in ["NOT_REQUIRED","ASSIGNED"];
if (_groundOrderScoped && {currentWaypoint _group >= count waypoints _group}
    && {_alive findIf {toUpperANSI currentCommand _x == "STOP"} < 0}) then {
    private _groundTarget=((_job get "target") select [0,2])+[0];
    private _waypoint = _group addWaypoint [_groundTarget, 30];
    _waypoint setWaypointType "SAD";
    _group setCurrentWaypoint _waypoint;
};
if (_landed && {_alive isNotEqualTo []} && {_groundHandoverOK}) then {
    missionNamespace setVariable ["CBE_AIPass_AirborneDrops", (missionNamespace getVariable ["CBE_AIPass_AirborneDrops", 0]) + 1];
    diag_log format ["[CBE] %1 airborne insertion complete (%2 on the ground).", _group, count _alive];
} else {
    diag_log format ["[CBE] %1 airborne insertion INCOMPLETE: landing/ground handover incomplete (deadline, unavailable passengers or partial assignment).", _group];
};
call _finish
