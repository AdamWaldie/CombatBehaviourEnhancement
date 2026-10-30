/*
 * Author: WaldoTheWarfighter
 * Purpose: Rank existing interior posts for medical protection or MG outward observation.
 * Locality/authority: Read-only geometry on the calling owner; returns an index, never movement,
 * target, ownership, access, occupation or firing permission. Callers retain all task guards.
 * Repeat/JIP: The caller supplies a private per-plan/callback cache. At most16 new profiles
 * consume its original budget; refill/reroute callers use4. No public cache or owner adoption.
 * Only the first16 remaining posts are considered. Unknown observations retain normal fallback.
 * Arguments: 0 posts ARRAY,[] - existing [ATL,bearing,building,transform] interior assignments;
 * 1 role STRING,RIFLE - MEDIC or MG ranks geometry, other roles keep index0;
 * 2 budget HASHMAP,empty - remaining NUMBER0..16, profiles HASHMAP and roofs HASHMAP.
 * The original cache is updated only with observations and remaining query allowance.
 * Return: NUMBER selected index;0 fallback, -1 for no posts. Does not reject native routes.
 * Current callers: CortexGarrison, CortexGarrisonRefill, CortexGarrisonApplyLocal rerouting.
 * Example: private _i=[_posts,"MEDIC",createHashMapFromArray [["remaining",4],
 * ["profiles",createHashMap],["roofs",createHashMap]]] call CBE_fnc_CortexGarrisonPostChoice;
 */
params [["_posts",[],[[]]],["_role","RIFLE",[""]],["_budget",createHashMap,[createHashMap]]];
if (_posts isEqualTo []) exitWith {-1};
if (!(_role in ["MEDIC","MG"]) || {count _posts > 512}) exitWith {0};
private _remaining=_budget getOrDefault ["remaining",0];
private _profiles=_budget getOrDefault ["profiles",createHashMap];
private _roofs=_budget getOrDefault ["roofs",createHashMap];
if (!(_remaining isEqualType 0) || {!finite _remaining} || {_remaining < 0} || {_remaining > 16}
    || {!(_profiles isEqualType createHashMap)} || {!(_roofs isEqualType createHashMap)}) exitWith {0};
private _best=0;
private _bestScore=-1e12;
{
    private _post=_x;
    private _postIndex=_forEachIndex;
    if (_post isEqualType [] && {count _post == 4}) then {
        private _position=_post param [0,[],[[]]];
        private _bearing=_post param [1,0,[0]];
        private _building=_post param [2,objNull,[objNull]];
        private _transform=_post param [3,[],[[]]];
        if (!isNull _building && {alive _building} && {finite _bearing} && {count _position == 3}
            && {_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_transform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building,getObjectScale _building]}) then {
            private _key=str _post;
            private _profile=_profiles getOrDefault [_key,[]];
            if (!(_profile isEqualType [])) then {_profile=[]};
            if (_profile isEqualTo [] && {_remaining > 0}) then {
                _remaining=_remaining-1;
                _budget set ["remaining",_remaining];
                private _asl=AGLToASL _position;
                private _roofKey=str _building;
                private _roof=_roofs getOrDefault [_roofKey,[]];
                if (!(_roof isEqualType []) || {count _roof != 2} || {(_roof select 0) isNotEqualTo _transform}) then {
                    _roof=[_transform,[_building] call CBE_fnc_BuildingRoofTop];
                    _roofs set [_roofKey,_roof];
                };
                private _top=_roof param [1,-1e12,[0]];
                private _roofed=false;
                if (finite _top && {_top != -1e12} && {_top > (_asl select 2)+1}) then {
                    private _hits=lineIntersectsSurfaces [_asl vectorAdd [0,0,1],
                        [_asl select 0,_asl select 1,_top],objNull,objNull,true,4,"GEOM","NONE"];
                    _roofed=_hits findIf {(_x select 2) == _building || {(_x select 3) == _building}} >= 0;
                };
                // Sample material screening from four virtual directions, not hostile beliefs.
                // Human bodies cannot supply cover through the shared read-only predicate.
                private _sides=0;
                private _heading=getDir _building;
                {
                    private _angle=_heading+_x;
                    private _from=_asl vectorAdd [8*sin _angle,8*cos _angle,1.6];
                    if ([_from,_asl vectorAdd [0,0,1],objNull,"COVER"] call CBE_fnc_CortexCoverScreened) then {_sides=_sides+1};
                } forEach [0,90,180,270];
                private _eye=_asl vectorAdd [0,0,1.5];
                private _near=_eye vectorAdd [5*sin _bearing,5*cos _bearing,0];
                private _field=0;
                if (!terrainIntersectASL [_eye,_near]) then {
                    private _far=_eye vectorAdd [50*sin _bearing,50*cos _bearing,0];
                    _field=50;
                    {
                        private _hits=lineIntersectsSurfaces [_eye,_far,objNull,objNull,true,1,_x,"NONE"];
                        if (_hits isNotEqualTo []) then {_field=_field min (_eye vectorDistance ((_hits select 0) select 0))};
                    } forEach ["VIEW","FIRE"];
                    if (terrainIntersectASL [_eye,_far]) then {_field=_field min 5};
                    if (_field < 5) then {_field=0};
                };
                _profile=[_roofed,_sides,_field];
                _profiles set [_key,_profile];
            };
            if (count _profile == 3) then {
                _profile params ["_roofed","_sides","_field"];
                private _score=if (_role == "MEDIC") then {
                    (if (_roofed) then {1000} else {0})+100*_sides-_field
                } else {10*_field+5*_sides+(if (_roofed) then {10} else {0})};
                if (_score > _bestScore) then {_bestScore=_score;_best=_postIndex};
            };
        };
    };
} forEach (_posts select [0,16]);
_best
