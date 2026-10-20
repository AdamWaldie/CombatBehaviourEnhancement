/*
 * Author: WaldoTheWarfighter
 * Purpose: Tests material cover or visual concealment between two ASL points without
 * treating a human body as screening. Shared by cover selection and live-leg adoption.
 * Locality/authority: Read-only anywhere; this is observation, never movement authority.
 * Repeat/JIP: No state, handlers or cached permission. Consumers retain their live owner,
 * task, order and deadline receipts. At most one terrain test and one object ray with
 * four returned surfaces; saturation may conservatively miss screening behind people.
 * Arguments: 0 threat eye ASL <ARRAY, []>; 1 candidate chest ASL <ARRAY, []>;
 * 2 intended actor <OBJECT, objNull>, excluded from the ray; 3 mode <STRING, COVER>,
 * exactly COVER or CONCEALMENT. Invalid/degenerate points refuse before world queries.
 * Return: BOOL - observed non-human screening, not path reachability or invulnerability.
 * Current callers: CortexFindCover and DangerCoverStep.
 * Example: [eyePos enemy1,(getPosASL soldier1) vectorAdd [0,0,1],soldier1,"COVER"] call CBE_fnc_CortexCoverScreened;
 */
params [["_start",[],[[]]],["_end",[],[[]]],["_actor",objNull,[objNull]],["_mode","COVER",[""]]];
if ([_start,_end] findIf {!(_x isEqualType []) || {count _x != 3}
    || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0) exitWith {false};
_mode=toUpperANSI _mode;
if !(_mode in ["COVER","CONCEALMENT"]) exitWith {false};
private _length=_start vectorDistance _end;
if (!finite _length || {_length <= 0.05}) exitWith {false};
if (terrainIntersectASL [_start,_end]) exitWith {true};
// Skip the source's immediate body vicinity without overshooting a close endpoint.
private _rayStart=_start vectorAdd ((_start vectorFromTo _end) vectorMultiply (2 min (_length*0.5)));
private _hits=lineIntersectsSurfaces [_rayStart,_end,_actor,objNull,true,4,
    ["FIRE","VIEW"] select (_mode == "CONCEALMENT"),
    ["GEOM","NONE"] select (_mode == "CONCEALMENT")];
_hits findIf {
    private _object=if (!isNull (_x select 3)) then {_x select 3} else {_x select 2};
    !isNull _object && {!(_object isKindOf "CAManBase")}
} >= 0
