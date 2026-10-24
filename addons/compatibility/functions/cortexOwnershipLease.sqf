/*
 * Author: WaldoTheWarfighter
 * Purpose: Gives one finite CBE operation exclusive ownership of the group's CBE movement domain.
 * Locality / Authority: Call only where the group is local. The public lease follows group locality so a server or headless-client owner can renew or release it.
 * Repeat/JIP: Reacquiring the same owner uses the explicitly supplied live deadline.
 * Missing expiry defaults to thirty seconds; invalid/expired explicit expiry is refused before
 * ordinary-driving handback. No minimum duration is minted and release is independent of expiry.
 * Unknown/malformed existing leases refuse acquisition and release; only their producer or an
 * explicit administrative repair can resolve unrecognised state. Discovery never renews a lease.
 * A competing unexpired CBE owner is refused; external ownership is handled before acquisition. Repeated release is safe.
 * Acquiring finite movement synchronously retires the ordinary driving FSM and its unchanged
 * speed leases before the new tactical owner is published; later ordinary samples are refused.
 * Pending controlled-vehicle driving journals/cap releases and queue/pass consent or agreement
 * receipts refuse acquisition. A selected artillery crew reference also refuses acquisition
 * before any driving retirement, even after its ordinary lease expires. Only its exact producer
 * retires native proof; an acquisition attempt never clears it. Absence of metadata
 * is not proof of native physical quiescence; no cleanup receipt is erased to force handover.
 * Arguments: 0 group <GROUP>; 1 owner <STRING>; 2 acquire <BOOL>, true; 3 expiry <NUMBER>, serverTime + 30.
 * Return Value: Boolean - true when acquired/released, false for invalid locality or competing work.
 * Current callers: Finite CBE group movement start/end, discovery expiry and group release.
 * Example: [_group,"SUPPORT",true,serverTime + 180] call CBE_fnc_CortexOwnershipLease;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_owner","",[""]],
    ["_acquire",true],
    ["_expires",serverTime + 30]
];
if (isNull _group || {!local _group} || {!(_acquire isEqualType true)}) exitWith {false};

private _lease=_group getVariable ["CBE_Cortex_MovementLease",[]];
private _typed=_lease isEqualType [] && {count _lease == 2}
    && {(_lease select 0) isEqualType ""} && {(_lease select 0) != ""}
    && {(_lease select 1) isEqualType 0} && {finite (_lease select 1)};
if (_lease isNotEqualTo [] && {!_typed}) exitWith {false};
private _live=_typed && {serverTime < (_lease select 1)};
if (_acquire) exitWith {
    if ((_group getVariable ["CBE_ArtilleryCrew_Reference",[]]) isNotEqualTo []) exitWith {false};
    if (_owner == "" || {!(_expires isEqualType 0)} || {!finite _expires} || {_expires <= serverTime}
        || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
    if (_live && {(_lease select 0) != _owner}) exitWith {
        missionNamespace setVariable [
            "CBE_Cortex_OwnershipBusyRefusals",
            (missionNamespace getVariable ["CBE_Cortex_OwnershipBusyRefusals",0]) + 1
        ];
        false
    };
    // Release the ordinary cap while it is still the current owner, before publishing the
    // successor tactical lease or allowing its caller to issue movement/speed commands.
    private _drivingBrain=_group getVariable ["CBE_Driving_Brain",createHashMap];
    if (count _drivingBrain > 0) then {[_drivingBrain,"TACTICAL_HANDOVER"] call CBE_fnc_DrivingOperationFinish};
    if (!local _group || {_expires <= serverTime} || {(_group getVariable ["CBE_Cortex_MovementLease",[]]) isNotEqualTo _lease}
        || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
    private _members=units _group;
    if (count _members > 64) exitWith {false};
    private _checked=[];
    private _drivingPending=_members findIf {
        private _vehicle=objectParent _x;
        !isNull _vehicle && {!(_vehicle in _checked)}
            && {driver _vehicle in _members || {effectiveCommander _vehicle in _members}}
            && {
                _checked pushBack _vehicle;
                if (!local _vehicle) exitWith {true};
                ["CBE_DrivingAssist_State","CBE_DrivingAssist_Restore","CBE_DrivingCapRelease_Work",
                    "CBE_DrivingRecovery_Work","CBE_DrivingPass_Work","CBE_DrivingCorridor_Work",
                    "CBE_DrivingBypass_Work","CBE_DrivingCrew_Work","CBE_DrivingQueue_Consent",
                    "CBE_DrivingPass_Consent","CBE_DrivingPass_Agreement"] findIf {
                    private _pending=_vehicle getVariable [_x,[]];
                    // Crew journals retain terminal evidence; they are not live work.
                    // Native boarding/action admission remains the movement executor's check.
                    if (_x == "CBE_DrivingCrew_Work" && {_pending isEqualType createHashMap}
                        && {(_pending getOrDefault ["phase",""]) in ["COMPLETE","CANCELLED","EXPIRED"]}) exitWith {false};
                    !(_pending isEqualType [] || {_pending isEqualType createHashMap}) || {count _pending > 0}
                } >= 0
            }
    } >= 0;
    if (_drivingPending) exitWith {false};
    _group setVariable ["CBE_Cortex_MovementLease",[_owner,_expires],true];
    true
};

if (_lease isEqualTo []) exitWith {true};
if (_owner != "" && {(_lease select 0) != _owner}) exitWith {false};
_group setVariable ["CBE_Cortex_MovementLease",nil,true];
true
