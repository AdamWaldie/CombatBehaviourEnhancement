/*
 * Author: WaldoTheWarfighter
 * Purpose: Veto CBE scripted aircraft release requests near protected actors. Guns/rockets
 * use the shared direct-fire cone; bombs/guided weapons check config-based blast areas at
 * the intended target and, for bombs, the predicted ballistic impact. Native autonomous
 * firing and projectiles already released are outside this request-only check.
 * Locality/authority: Read-only on the aircraft owner; caller retains operator, ROE and lease checks.
 * Repeat/JIP: Stateless, no handlers, commands, public state or persistent permissions.
 * Arguments: 0 operator <OBJECT, objNull>; 1 target ASL <ARRAY, []>, three finite numbers;
 * 2 loaded magazine <STRING, "">; 3 weapon class <STRING, "">, GUN/ROCKET/BOMB/GUIDED;
 * 4 predicted bomb impact ASL <ARRAY, []>, required for BOMB, otherwise unused.
 * Return Value: BOOL - no veto in bounded current-position observations; not guaranteed safe fire.
 * Current callers: CortexAirAttack, only when an otherwise ready scripted request is due.
 * Example: [_pilot,_targetASL,_loadedMagazine,"BOMB",_impactASL] call CBE_fnc_CortexAirReleaseSafe;
 * Limits: At most two native blast queries, <=250m each, <=64 results each; overflow refuses.
 * Radius max12m/four times configured indirectHitRange for damaging explosive ammunition.
 * Blast checks include own platform and vehicle occupants. No predicted actor motion, fragment,
 * hull/penetration or entire guided flight-path guarantee; query cost remains engine-dependent.
 */
params [["_operator",objNull,[objNull]],["_targetASL",[],[[]]],
    ["_magazine","",[""]],["_weaponClass","",[""]],["_impactASL",[],[[]]]];
if (isNull _operator || {!alive _operator} || {_magazine == ""}
    || {!(_weaponClass in ["GUN","ROCKET","BOMB","GUIDED"])}
    || {count _targetASL != 3}
    || {_targetASL findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {false};
if (_weaponClass in ["GUN","ROCKET"]) exitWith {
    [_operator,_targetASL,_magazine] call CBE_fnc_CortexLineOfFireClear
};
private _points=[+_targetASL];
if (_weaponClass == "BOMB") then {
    if (count _impactASL != 3
        || {_impactASL findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {_points=[]};
    _points pushBackUnique +_impactASL;
};
if (_points isEqualTo []) exitWith {false};
private _ammo=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
if (!isClass _ammo) exitWith {false};
private _range=getNumber (_ammo >> "indirectHitRange");
private _damage=getNumber (_ammo >> "indirectHit");
private _explosive=getNumber (_ammo >> "explosive");
if (!finite _range || {_range < 0} || {!finite _damage} || {_damage < 0}
    || {!finite _explosive} || {_explosive < 0}) exitWith {false};
// Non-explosive guided rounds still need an endpoint exclusion, not an unchecked free pass.
private _radius=12;
if (_damage > 0 || {_explosive > 0}) then {_radius=_radius max (4*_range)};
if (_radius > 250) exitWith {false};
private _side=side group _operator;
_points findIf {
    private _point=_x;
    private _candidates=(ASLToAGL _point) nearEntities [["CAManBase","LandVehicle","Air","Ship"],_radius];
    count _candidates > 64 || {
        _candidates findIf {
            private _entity=_x;
            alive _entity && {
                ([_entity]+crew _entity) findIf {
                    alive _x && {captive _x || {_x getVariable ["ace_captives_isSurrendering",false]}
                        || {_x getVariable ["ace_captives_isHandcuffed",false]}
                        || {side _x == civilian} || {_side getFriend (side _x) >= 0.6}}
                } >= 0
            }
        } >= 0
    }
} < 0
