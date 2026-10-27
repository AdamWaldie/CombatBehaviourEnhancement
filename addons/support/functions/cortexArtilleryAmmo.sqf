/*
 * Author: WaldoTheWarfighter
 * Selects available plain HE, smoke or illumination, keeping their payload classes distinct.
 * Known native leaf simulations are required rather than an AI usage flag. Mixed deployers
 * are refused; illumination also excludes explosive configurations; each uncached payload tree permits 64 reads and four levels.
 * Locality/authority: read-only query on the battery owner; callers coordinate fire on the server.
 * Repeat/JIP: repeat-safe; immutable ammunition profiles are cached locally, available rounds are read each call.
 * Arguments: 0: battery <OBJECT>, default objNull; 1: smoke BOOL false or mode STRING HE/SMOKE/ILLUM.
 * 2: reported ATL target <ARRAY>, default [] preserves range-independent selection.
 * 3: optional exact magazine STRING, empty by default; owner checks can qualify the requested
 * class without substituting a newly preferred magazine.
 * A supplied target must be a finite pair/triple; range qualifies each suitable magazine
 * before preference ranking. An unusable preferred shell cannot mask a reachable one.
 * Range checks are live, never cached with immutable ammunition classification.
 * Return Value: String magazine class, or empty string.
 * Current callers: ArtilleryFire and ArtilleryShot.
 * Example: private _mag = [_gun, false] call CBE_fnc_CortexArtilleryAmmo;
 */
if (count _this > 1 && {!((_this select 1) isEqualType true) && {!((_this select 1) isEqualType "")}}) exitWith {""};
params [["_battery", objNull, [objNull]], ["_selection", false, [true,""]],["_target",[],[[]]],["_exactMagazine","",[""]]];
private _mode=if (_selection isEqualType true) then {["HE","SMOKE"] select _selection} else {toUpperANSI _selection};
if (!(_mode in ["HE","SMOKE","ILLUM"])) exitWith {""};
if (isNull _battery || {_target isNotEqualTo [] && {!(count _target in [2,3])
    || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}}}) exitWith {""};
private _best = "";
private _available = (magazinesAllTurrets [_battery,true]) select {(_x select 2) > 0};
private _cache = missionNamespace getVariable ["CBE_AIPass_ArtilleryAmmoProfiles",createHashMap];
private _bestHit = -1;
// Mortar smoke can be a shotDeploy carrier rather than a direct smoke projectile.
// Inspect only immutable config, bounded against recursive addon payload definitions.
private _payloadChecks=0;
private _classifyPayload = {
    params ["_ammoClass",["_depth",0],["_kind","SMOKE"]];
    _payloadChecks=_payloadChecks+1;
    if (_depth >= 4 || {_payloadChecks > 64} || {!isClass (configFile >> "CfgAmmo" >> _ammoClass)}) exitWith {false};
    private _ammoConfig=configFile >> "CfgAmmo" >> _ammoClass;
    private _simulation=toLowerANSI getText (_ammoConfig >> "simulation");
    private _indirect=getNumber (_ammoConfig >> "indirectHit");
    private _explosive=getNumber (_ammoConfig >> "explosive");
    if (!finite _indirect || {_indirect != 0}
        || {_kind == "ILLUM" && {!finite _explosive || {_explosive != 0}}}) exitWith {false};
    private _payload=getText (_ammoConfig >> "submunitionAmmo");
    private _payloadArray=getArray (_ammoConfig >> "submunitionAmmo");
    private _hasPayload=_payload != "" || {isArray (_ammoConfig >> "submunitionAmmo")};
    if (_hasPayload) exitWith {
        private _payloads=if (_payload != "") then {[_payload]} else {+_payloadArray};
        private _validPayload=true;
        if (_payload == "" && {_payloadArray findIf {!(_x isEqualType "")} >= 0}) then {
            // Engine format: alternating class/probability pairs. Preserve every branch,
            // including zero-weight ones, instead of filtering numbers out of malformed data.
            _payloads=[];
            _validPayload=count _payloadArray > 0 && {count _payloadArray <= 32} && {count _payloadArray mod 2 == 0};
            private _positiveWeight=false;
            if (_validPayload) then {
                for "_index" from 0 to ((count _payloadArray)-2) step 2 do {
                    private _class=_payloadArray select _index;
                    private _weight=_payloadArray select (_index+1);
                    if (!(_class isEqualType "") || {_class == ""} || {!(_weight isEqualType 0)}
                        || {!finite _weight} || {_weight < 0}) exitWith {_validPayload=false};
                    _payloads pushBack _class;
                    if (_weight > 0) then {_positiveWeight=true};
                };
            };
            _validPayload=_validPayload && {_positiveWeight};
        };
        _validPayload && {_payloads isNotEqualTo []} && {count _payloads <= 16}
            && {_payloads findIf {!(_x isEqualType "") || {_x == ""}} < 0}
            && {getNumber (_ammoConfig >> "hit") == 0}
            && {_payloads findIf {!([_x,_depth+1,_kind] call _classifyPayload)} < 0}
    };
    // An AI usage flag alone cannot prove this projectile delivers smoke.
    if (_kind == "ILLUM") then {_simulation == "shotilluminating"} else {_simulation in ["shotsmoke","shotsmokex"]}
};
{
    private _profile = _cache getOrDefault [_x,[]];
    if (!(_profile isEqualType []) || {count _profile != 4}) then {
        private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
        private _cfg = configFile >> "CfgAmmo" >> _ammo;
        _payloadChecks=0;
        private _smokeAmmo = [_ammo] call _classifyPayload;
        _payloadChecks=0;
        private _illumAmmo = [_ammo,0,"ILLUM"] call _classifyPayload;
        private _specialAmmo = toLowerANSI getText (_cfg >> "simulation") == "shotilluminating" || {getText (_cfg >> "submunitionAmmo") != ""} || {isArray (_cfg >> "submunitionAmmo")};
        _profile = [_smokeAmmo,_specialAmmo,getNumber (_cfg >> "hit"),_illumAmmo];
        _cache set [_x,_profile];
    };
    _profile params ["_isSmoke","_special","_hit","_isIllum"];
    private _matches=switch (_mode) do {
        case "SMOKE": {_isSmoke};
        case "ILLUM": {_isIllum};
        default {!_isSmoke && {!_special} && {_hit > _bestHit}};
    };
    if (_matches
        && {_target isEqualTo [] || {_target inRangeOfArtillery [[_battery],_x]}}) then {
        _best = _x; _bestHit = _hit
    };
} forEach ((getArtilleryAmmo [_battery]) select {private _magazine = _x;
    (_exactMagazine == "" || {_magazine == _exactMagazine})
        && {_available findIf {(_x select 0) == _magazine} >= 0}});
missionNamespace setVariable ["CBE_AIPass_ArtilleryAmmoProfiles",_cache];

_best
