/*
 * Author: WaldoTheWarfighter
 * Purpose: Request one finite danger-cover cue for a visibly approaching small hostile UAV.
 * Locality/authority: Internal current group owner only; reuses its existing native knowledge
 * and actor roster. No new detection, target assignment, shot, posture or movement writer.
 * DangerRequest and the existing danger/cover owners retain task, order and native authority.
 * Repeat/JIP: One candidate from at most8 known rows and up to8 members of the existing<=64
 * roster per probe; rotate both bounded cursors. At most one VIEW query, no world discovery.
 * Personal native sighting<=1second, knownByUnit and ignoreTarget checks precede the ray.
 * Live source geometry is used only for that targeted visibility/range test; velocity is read
 * only after visible confirmation. Failed probes wait1second; accepted cues wait4seconds.
 * Both are observation cadence, never renewed movement/recovery allowance. New owners start
 * from their own local group state. No worker, handler, JIP replay or settings mutation.
 * This is visual near-collision avoidance, not armed-drone identification, hearing, shooting,
 * full FPV evasion, swarm handling or a guarantee of timely detection at group-tick cadence.
 * Arguments: group GROUP,grpNull; current group state HASHMAP,empty; native CortexKnowledge
 * rows ARRAY,[]; existing living group actor roster ARRAY,[]. No stored row is execution proof.
 * Return: BOOL accepted UAV_APPROACH observation, never movement, arrival or physical safety.
 * Current callers: CortexGroupTick immediately after its existing native knowledge query.
 * Example: [_group,_state,_enemies,_alive] call CBE_fnc_CortexUAVApproach;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],
    ["_enemies",[],[[]]],["_actors",[],[[]]]];
if (remoteExecutedOwner > 0 || {isNull _group} || {!local _group}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!(_group getVariable ["CBE_AIPass_Managed",false])}
    || {_state isNotEqualTo (_group getVariable ["CBE_AIPass_State",createHashMap])}
    || {!([_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    || {time < (_state getOrDefault ["uavApproachProbeAt",-1])}
    || {time < (_state getOrDefault ["uavApproachCueAt",-1])}) exitWith {false};
private _candidates=[];
{
    private _row=_x;
    if (!(_row isEqualType []) || {count _row < 5}) then {continue};
    private _drone=_row param [0,objNull,[objNull]];
    private _age=_row param [2,1e6,[0]];private _error=_row param [4,1e6,[0]];
    if (isNull _drone || {!alive _drone} || {!(_drone isKindOf "Air")} || {!unitIsUAV _drone}
        || {!finite _age} || {_age < 0} || {_age > 1} || {!finite _error} || {_error < 0} || {_error > 5}
        || {(side _group) getFriend (side _drone) >= 0.6}) then {continue};
    private _scale=getObjectScale _drone;private _size=(sizeOf (typeOf _drone))*_scale;
    if (!finite _scale || {_scale <= 0} || {!finite _size} || {_size <= 0} || {_size > 5}) then {continue};
    _candidates pushBack _drone;
} forEach (_enemies select [0,8]);
if (_candidates isEqualTo []) exitWith {false};
private _candidateCursor=_state getOrDefault ["uavApproachCandidate",0];
if (!(_candidateCursor isEqualType 0) || {!finite _candidateCursor}) then {_candidateCursor=0};
_candidateCursor=((floor _candidateCursor) max 0) mod count _candidates;
private _drone=_candidates select _candidateCursor;
_state set ["uavApproachCandidate",(_candidateCursor+1) mod count _candidates];
_state set ["uavApproachProbeAt",time+1];
private _roster=_actors select [0,64];
if (_roster isEqualTo []) exitWith {false};
private _cursor=_state getOrDefault ["uavApproachActor",0];
if (!(_cursor isEqualType 0) || {!finite _cursor}) then {_cursor=0};
_cursor=((floor _cursor) max 0) mod count _roster;
_state set ["uavApproachActor",(_cursor+1) mod count _roster];
private _observer=objNull;
for "_i" from 0 to ((count _roster min 8)-1) do {
    private _actor=_roster select ((_cursor+_i) mod count _roster);
    if (isNull _actor || {!local _actor} || {group _actor != _group} || {isPlayer _actor}
        || {!isNull remoteControlled _actor} || {!isNull objectParent _actor}
        || {!isNull attachedTo _actor} || {!([_actor] call CBE_fnc_CortexCombatEffective)}
        || {!(currentCommand _actor in ["","ATTACK","FIRE","SUPPRESS"])}
        || {abs speed _actor > 0.5}) then {continue};
    private _knowledge=_actor targetKnowledge _drone;
    private _lastSeen=_knowledge param [2,-1,[0]];
    if ((_knowledge param [1,false,[true]]) && {!(_knowledge param [7,false,[true]])}
        && {finite _lastSeen} && {_lastSeen >= 0} && {time >= _lastSeen} && {time-_lastSeen <= 1}) exitWith {_observer=_actor};
};
if (isNull _observer) exitWith {false};
private _observedAt=time;
private _eye=eyePos _observer;private _droneASL=getPosASL _drone;
private _relative=_droneASL vectorDiff _eye;private _distance=vectorMagnitude _relative;
if (!finite _distance || {_distance <= 0.1} || {_distance > 120}
    || {([_observer,"VIEW",_drone] checkVisibility [_eye,_droneASL]) <= 0.15}) exitWith {false};
private _position=ASLToATL _droneASL;
if ((_position select 2) <= 0.3) exitWith {false};
private _velocity=(velocity _drone) vectorDiff (velocity _observer);
private _speed=vectorMagnitude _velocity;
if (!finite _speed || {_speed <= 4}) exitWith {false};
private _closing=-(_relative vectorDotProduct _velocity);
if (_closing/(_distance*_speed) <= 0.8) exitWith {false};
private _eta=_closing/(_speed*_speed);
private _miss=vectorMagnitude (_relative vectorAdd (_velocity vectorMultiply _eta));
if (!finite _eta || {_eta <= 0} || {_eta > 4} || {!finite _miss} || {_miss > 6}) exitWith {false};
// This is a derived visible approach cue, never a fabricated native HIT/PROXIMITY event.
private _accepted=[_observer,"UAV_APPROACH",_position,_drone,_observedAt+1,_observedAt+1]
    call CBE_fnc_DangerRequest;
if (_accepted) then {_state set ["uavApproachCueAt",_observedAt+4]};
_accepted
