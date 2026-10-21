/*
 * Author: WaldoTheWarfighter
 * Purpose: Bind garrison stance/speed writers and retirement to the shared exact actor-settings lease.
 * Locality/authority: Actual group/actor owner. Live public garrison issuer admits acquisition;
 * original actor issuer admits cleanup only, including after order removal or owner adoption.
 * Repeat/JIP: Baselines are captured by ActorSettings before writes, never from legacy mirrors.
 * Refused release retains proof and one original30second retirement window on the existing brain.
 * No movement, watch, new worker or retry deadline renewal is issued here.
 * Arguments: 0 actor OBJECT objNull;1 group GROUP grpNull;2 mode STRING APPLY (CHECK, RELEASE);
 * 3 requested HASHMAP empty;4 allow deferral BOOL true.
 * Return: ActorSettings status STRING, REFUSED when authority is absent.
 * Current callers: CortexGarrisonApplyLocal, CortexGarrisonRelease and GroupBrainStep.
 * Example: [soldier1,group soldier1,"APPLY",createHashMapFromArray [["SPEED",4]]] call CBE_fnc_CortexGarrisonSettings;
 */
params [["_actor",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_mode","APPLY",[""]],["_requested",createHashMap,[createHashMap]],["_defer",true,[true]]];
private _status="REFUSED";
isNil {
if (isNull _actor || {!local _actor} || {isNull _group} || {!local _group}
    || {group _actor != _group} || {!(_mode in ["APPLY","CHECK","RELEASE"])}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {};
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _issuer=_group getVariable ["CBE_Cortex_GarrisonSettingIssuer",""];
private _actorIssuer=_actor getVariable ["CBE_Cortex_GarrisonSettingToken",""];
private _lease=_actor getVariable ["CBE_ActorSettings",[]];
private _retireWindow=_actor getVariable ["CBE_Cortex_GarrisonSettingRetireUntil",[]];
private _retiring=_retireWindow isEqualType [] && {count _retireWindow == 2}
    && {(_retireWindow select 0) isEqualTo _actorIssuer};
private _known=_lease isEqualType [] && {count _lease == 3}
    && {(_lease select 0) isEqualType []} && {count (_lease select 0) == 5}
    && {_actorIssuer isEqualType ""} && {_actorIssuer != ""}
    && {((_lease select 0) select 0) isEqualTo _group}
    && {((_lease select 0) select 1) isEqualTo _actorIssuer};
private _mirrors=["CBE_AIPass_GarrisonStance","CBE_Cortex_GarrisonAppliedStance",
    "CBE_Cortex_GarrisonDuckStance","CBE_Cortex_GarrisonForcedSpeed",
    "CBE_Cortex_GarrisonAppliedSpeed","CBE_Cortex_GarrisonSettingToken"];
if (_mode == "RELEASE" || {_known && {_actorIssuer != _issuer || {_retiring}}}) then {
    if (_known) then {
        private _context=+(_lease select 0); _context set [3,_epoch];
        _status=["RELEASE",_actor,_context] call CBE_fnc_ActorSettings;
        if (_status == "RELEASED") then {
            {_actor setVariable [_x,nil,true]} forEach _mirrors;
            _actor setVariable ["CBE_Cortex_GarrisonSettingRetireUntil",nil,true];
            _lease=[]; _known=false; _actorIssuer="";
        } else {
            if (_defer) then {
                private _window=_actor getVariable ["CBE_Cortex_GarrisonSettingRetireUntil",[]];
                if (_window isEqualTo [] || {_window isEqualType [] && {count _window == 2}
                    && {(_window select 0) isNotEqualTo _actorIssuer}}) then {
                    _window=[_actorIssuer,serverTime+30];
                    _actor setVariable ["CBE_Cortex_GarrisonSettingRetireUntil",_window,true];
                };
                if (_window isEqualType [] && {count _window == 2}
                    && {(_window select 0) isEqualTo _actorIssuer}
                    && {(_window select 1) isEqualType 0} && {finite (_window select 1)}
                    && {serverTime < (_window select 1)}) then {
                    private _pending=_group getVariable ["CBE_Cortex_GarrisonSettingsPending",[]];
                    if (_pending isEqualType [] && {count _pending < 64} && {!(_actor in _pending)}) then {
                        _pending pushBack _actor;
                        _group setVariable ["CBE_Cortex_GarrisonSettingsPending",_pending,true];
                    };
                };
            };
        };
    } else {
        if (_lease isEqualTo [] && {_mirrors findIf {!isNil {_actor getVariable _x}} < 0}) then {_status="ABSENT"};
    };
};
if (_mode == "RELEASE") exitWith {};
// Partial old mirrors never grant permission to recapture a temporary applied value as baseline.
if (_lease isEqualTo [] && {_mirrors findIf {!isNil {_actor getVariable _x}} >= 0}) exitWith {};
if (!(_issuer isEqualType "") || {_issuer == ""}) exitWith {};
private _context=[_group,_issuer,_group getVariable ["CBE_AIPass_GarrisonGeneration",-1],_epoch,0];
private _ready=true;
if (_known && {(_lease select 0) isNotEqualTo _context}) then {
    _status=["ADOPT",_actor,_context,createHashMap,"GARRISON"] call CBE_fnc_ActorSettings;
    _ready=_status == "ADOPTED";
};
if (!_ready) exitWith {};
_status=[_mode,_actor,_context,_requested,"GARRISON"] call CBE_fnc_ActorSettings;
if (_status in ["APPLIED","PENDING"]) then {
    private _owned=(_actor getVariable ["CBE_ActorSettings",[]]) select 1;
    private _values=[["CBE_Cortex_GarrisonSettingToken",_issuer]];
    if ("STANCE" in _owned) then {
        _values pushBack ["CBE_AIPass_GarrisonStance",(_owned get "STANCE") select 0];
        _values pushBack ["CBE_Cortex_GarrisonAppliedStance",(_owned get "STANCE") select 1];
    };
    if ("SPEED" in _owned) then {
        _values pushBack ["CBE_Cortex_GarrisonForcedSpeed",(_owned get "SPEED") select 0];
        _values pushBack ["CBE_Cortex_GarrisonAppliedSpeed",(_owned get "SPEED") select 1];
    };
    {if ((_actor getVariable [_x select 0,[]]) isNotEqualTo (_x select 1)) then {
        _actor setVariable [_x select 0,_x select 1,true];
    }} forEach _values;
};
};
_status
