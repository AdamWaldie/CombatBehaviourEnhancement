/*
 * Author: WaldoTheWarfighter
 * Purpose: Finds one combat-effective, owner-local actor for finite local lifecycle work when a
 * group leader is killed, incapacitated, player-controlled or specialist-owned. Unlike a transmitter, this helper
 * does not require a radio and must not be used to authorise communication or support requests.
 * Locality/authority: Read-only; returns only an actor local to the calling machine. The bounded
 * twelve-member default scan performs no target, movement, inventory or network mutation.
 * An explicit element instead inspects at most64 supplied members and can return only a local
 * on-foot member of that element and group. An empty explicit element never falls back to the
 * native leader or another squad member. This is a position witness, not command authority.
 * Repeat/JIP: Recomputes from current group membership. A new owner obtains its own local anchor.
 * Arguments: 0: group <GROUP>; 1: optional explicit ground element <ARRAY of OBJECT>.
 * Omit argument1 for the existing group-wide lifecycle anchor; supplying [] returns objNull.
 * Return Value: local combat-effective actor <OBJECT>, objNull when none is available.
 * Current callers: danger/common lifecycle paths, CortexAssaultStart and CortexFlankStep recovery.
 * Example: private _actor = [group player] call CBE_fnc_CortexGroupAnchor;
 */

params [["_group",grpNull,[grpNull]],["_element",[],[[]]]];
private _elementScoped=count _this > 1;
if (isNull _group) exitWith {objNull};
private _eligible={
    params ["_actor"];
    _actor isEqualType objNull && {!isNull _actor} && {local _actor} && {!isPlayer _actor}
        && {isNull remoteControlled _actor}
        && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!_elementScoped || {group _actor == _group && {isNull objectParent _actor}
            && {simulationEnabled _actor} && {!isObjectHidden _actor}}}
};
private _leader=leader _group;
private _members=if (_elementScoped) then {_element select [0,64]} else {[]};
if ((!_elementScoped || {_leader in _members}) && {[_leader] call _eligible}) exitWith {_leader};
if (!_elementScoped) then {_members=(units _group) select [0,12]};
private _index=_members findIf {[_x] call _eligible};
if (_index < 0) exitWith {objNull};
_members select _index
