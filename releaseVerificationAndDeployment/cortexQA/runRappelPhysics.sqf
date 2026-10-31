/*
 * Author: WaldoTheWarfighter
 * Purpose: Isolate native rope/Man feasibility against a simulated cargo control. Diagnostic
 * only: a pass cannot accept CBE rappelling or a release. No production executor is called.
 * Locality/authority: Scheduled dedicated server, normal VR batch only, two disposable cells.
 * Aircraft anchors are fixed/simulation-off; payloads stay simulated throughout measurement.
 * A successful crate control is required before the Man result can support an inference.
 * Repeat/JIP: Called once by the guarded server runner. No client worker or JIP replay.
 * Initial fixture placement/protection/PATH exclusion is setup only. HOLD and UNWIND issue
 * no actor position, velocity, animation, simulation or damage assistance. Native ropeUnwind
 * is requested once per cell. At most150 samples/cell, <=60s total, all created resources removed.
 * Arguments: 0 check CODE; 1 phase CODE; 2 wait CODE (shared harness, unused here).
 * Return Value: Nothing; physical findings and raw samples go to the existing RPT/result lane.
 * Current callers: cortexQAServer.sqf explicit rappelphysics focus, never the all batch.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQARappelPhysics.sqf";
 * Limits: No real hover/entry/animation/casualty/migration/roof/handback/performance proof.
 */
params ["_check","_phase","_wait"];
if (!isServer || {missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false]}) exitWith {
    ["RAPPEL-PHYSICS-normal-server",false,"Requires an isolated normal VR batch."] call _check;
};
["Native rappel physics: Man and cargo control",
    "DIAGNOSTIC ONLY. Two fixed helicopter anchors compare a simulated soldier and cargo crate. Native ropes must hold, then lower the payloads without scripted movement. A failed cargo control makes the Man result inconclusive. No CBE descent is implemented by this case.",[2300,1800,0]] call _phase;
private _cells=[];
private _groups=[];
// This transaction is initial fixture construction, before physical observation begins.
isNil {
    {
        private _name=_x;
        private _base=[2300+40*_forEachIndex,1800,0];
        private _aircraft=createVehicle ["B_Heli_Transport_03_unarmed_F",_base vectorAdd [0,0,28],[],0,"CAN_COLLIDE"];
        _aircraft enableSimulationGlobal false;
        _aircraft allowDamage false;
        _aircraft setPosASL (ATLToASL (_base vectorAdd [0,0,28]));
        private _memory=_aircraft selectionPosition ["slingload0","Memory"];
        private _anchor=_aircraft modelToWorldWorld _memory;
        private _point=[0,0,0];
        private _payload=objNull;
        if (_name == "MAN") then {
            private _group=createGroup [east,true];
            _groups pushBack _group;
            _group setVariable ["CBE_AI_Exclude",true,true];
            _group setVariable ["CBE_AIPass_Exclude",true,true];
            _group setVariable ["CBE_Headless_ExcludeGroup",true,true];
            _group setVariable ["acex_headless_blacklist",true,true];
            _payload=_group createUnit ["O_Soldier_F",_base,[],0,"NONE"];
            _payload disableAI "PATH";
            _point=[0,0,1.2];
        } else {
            _payload=createVehicle ["B_supplyCrate_F",_base,[],0,"CAN_COLLIDE"];
        };
        _payload allowDamage false;
        _payload enableRopeAttach true;
        _payload setPosASL (_anchor vectorAdd [0,0,-8] vectorDiff _point);
        private _rope=ropeCreate [_aircraft,"slingload0",_payload,_point,8];
        _cells pushBack (createHashMapFromArray [["name",_name],["aircraft",_aircraft],
            ["payload",_payload],["point",_point],["rope",_rope],["anchor",_anchor],
            ["origin",getPosASL _payload],["samples",[]],["hold",false],["lowered",false],
            ["memoryValid",_memory isNotEqualTo [0,0,0]]]);
    } forEach ["MAN","CARGO"];
};
private _valid=_cells findIf {
    private _payload=_x get "payload";
    !(_x get "memoryValid") || {isNull (_x get "rope")} || {!local (_x get "aircraft")}
        || {!local _payload} || {!alive _payload} || {!simulationEnabled _payload}
} < 0;
["RAPPEL-PHYSICS-fixtures",_valid,"Two original local native ropes; real slingload memory; simulated payloads."] call _check;
private _sample={
    params ["_cell","_phaseName"];
    private _payload=_cell get "payload";
    private _aircraft=_cell get "aircraft";
    private _rope=_cell get "rope";
    private _endpoint=_payload modelToWorldWorld (_cell get "point");
    private _row=[serverTime,_phaseName,getPosASL _payload,+_endpoint,ropeLength _rope,
        isTouchingGround _payload,local _payload,simulationEnabled _payload,
        (_aircraft modelToWorldWorld (_aircraft selectionPosition ["slingload0","Memory"])),alive _payload];
    private _samples=_cell get "samples";
    if (count _samples < 150) then {_samples pushBack _row};
    if ((count _samples) mod 5 == 0) then {
        diag_log format ["CBE RAPPEL PHYSICS SAMPLE|%1|%2",_cell get "name",_row];
    };
    _row
};
if (_valid) then {
    private _holdUntil=diag_tickTime+6;
    waitUntil {
        sleep 0.2;
        {[_x,"HOLD"] call _sample} forEach _cells;
        diag_tickTime >= _holdUntil
    };
    {
        private _samples=_x get "samples";
        private _originalAnchor=_x get "anchor";
        private _held=count _samples >= 20 && {_samples findIf {
            _x params ["_at","_phaseName","_position","_endpoint","_length","_ground","_local","_simulated","_anchor","_alive"];
            !_local || {!_simulated} || {!_alive} || {_ground} || {_anchor distance _originalAnchor > 0.2}
                || {abs ((_endpoint distance _anchor)-_length) > 2}
        } < 0};
        _x set ["hold",_held];
        _x set ["lowerOrigin",getPosASL (_x get "payload")];
        private _targetLength=28 max (ropeLength (_x get "rope"));
        ropeUnwind [_x get "rope",2,_targetLength];
    } forEach _cells;
    private _lowerUntil=diag_tickTime+23;
    waitUntil {
        sleep 0.2;
        {[_x,"UNWIND"] call _sample} forEach _cells;
        diag_tickTime >= _lowerUntil
    };
    {
        private _payload=_x get "payload";
        private _descent=((_x get "lowerOrigin") select 2)-((getPosASL _payload) select 2);
        private _fixedAnchor=_x get "anchor";
        private _stable=(_x get "samples") findIf {
            (_x select 8) distance _fixedAnchor > 0.2 || {!(_x select 6)} || {!(_x select 7)} || {!(_x select 9)}
        } < 0;
        private _lowered=(_x get "hold") && {_stable} && {alive _payload} && {_descent >= 8}
            && {local _payload} && {simulationEnabled _payload} && {isTouchingGround _payload}
            && {((getPosATL _payload) select 2) < 1} && {ropeLength (_x get "rope") >= 25};
        _x set ["lowered",_lowered];
        diag_log format ["CBE RAPPEL PHYSICS RESULT|%1|hold=%2|lowered=%3|descent=%4|samples=%5",
            _x get "name",_x get "hold",_lowered,_descent,count (_x get "samples")];
    } forEach _cells;
};
private _control=_cells select 1;
private _man=_cells select 0;
private _controlOK=_valid && {_control get "hold"} && {_control get "lowered"};
["RAPPEL-PHYSICS-cargo-control",_controlOK,"If false, the fixed-anchor setup did not prove native lowering; Man result is inconclusive."] call _check;
["RAPPEL-PHYSICS-man-held",_controlOK && {_man get "hold"},"Requires passing cargo control; native creation or rope length alone cannot pass."] call _check;
["RAPPEL-PHYSICS-man-lowered-grounded",_controlOK && {_man get "lowered"},"Requires actual unassisted descent >=8m and native ground contact, not a timeout or pose flag."] call _check;
missionNamespace setVariable ["CBE_QA_RappelPhysicsTrace",_cells apply {[_x get "name",_x get "samples"]}];
{if (!isNull (_x get "rope")) then {ropeDestroy (_x get "rope")}} forEach _cells;
sleep 1;
["RAPPEL-PHYSICS-rope-retired",_cells findIf {!isNull (_x get "rope")} < 0,"Native rope destruction observed before fixture removal."] call _check;
{
    deleteVehicle (_x get "payload");
    deleteVehicle (_x get "aircraft");
} forEach _cells;
{deleteGroup _x} forEach _groups;
diag_log "CBE RAPPEL PHYSICS DIAGNOSTIC ONLY: no production descent, animation, ownership handover or release acceptance proven.";
