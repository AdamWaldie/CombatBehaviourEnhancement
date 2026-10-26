/*
 * Author: WaldoTheWarfighter
 * Releases CBE vector-flight control and restores only the AI systems changed during an approach.
 * A normal airborne abort does not impose a new flight height: the current waypoint/Zeus order is
 * allowed to resume with the aircraft's existing altitude policy. A ground anchor is different
 * because it deliberately used forced height zero; only that path receives a safe, non-forced
 * release height. This prevents moved waypoints and newly grouped formations being driven down to
 * the old 30 metre landing-transit value. Cleanup is safe after landing, cancellation, locality
 * migration, pilot takeover or feature stop.
 * Locality and authority: Runs on the current helicopter owner and restores only CBE's
 * local approach changes. It rejects a null or non-local aircraft.
 * Requires the exact feature snapshot/revision. Other flight leases are preserved while
 * original aircraft features enter finite release-only cleanup; pilot FSM remains actor-local.
 * Repeat/JIP: Safe to call after the controller stops; cleanup of the published active/anchor
 * flags is visible to JIP clients without replaying a past flight action.
 *
 * Arguments:
 * 0: helicopter <OBJECT>
 * 1: landed successfully <BOOL> (default false)
 * 2: waypoint type <STRING> (default "")
 * 3: stabilise airborne handoff <BOOL> (default false) - removes only downward velocity left by
 *    CBE when formation/group control supersedes an active approach.
 * 4: expected landing revision <NUMBER>, -1 uses the current revision for administrative release.
 *
 * Return Value: BOOL - true when matching landing control is retired/release offered. It is not
 * proof of feature restoration; FeatureReleaseResult reports PENDING, RELEASED or retained UNRESOLVED.
 * Deferred retries never issue native flight handback commands.
 *
 * Example: [_helicopter, true, "GETOUT"] call CBE_fnc_ImprovedHelicopterLandingRestoreLocal;
 * Result: True after matching landing control retirement/release offer; feature completion is separate.
 * Current callers: the landing controller and local tracker cleanup.
 */

params [
    ["_helicopter", objNull, [objNull]],
    ["_landed", false, [true]],
    ["_waypointType", "", [""]],
    ["_stabiliseAirborne", false, [true]],
    ["_expectedRevision",-1,[0]]
];
if (isNull _helicopter) exitWith {false};
if (!local _helicopter || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _releasedRevision=_helicopter getVariable ["CBE_ImprovedHelicopterLanding_ControlRevision",0];
if (!(_releasedRevision isEqualType 0) || {!finite _releasedRevision}
    || {!finite _expectedRevision}) exitWith {false};
private _snapshot=_helicopter getVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot",[]];
if (!(_snapshot isEqualType []) || {count _snapshot != 6}
    || {[0,1] findIf {!((_snapshot select _x) isEqualType 0) || {!finite (_snapshot select _x)}} >= 0}
    || {!((_snapshot select 2) isEqualType objNull)}
    || {[3,4,5] findIf {!((_snapshot select _x) isEqualType true)} >= 0}) exitWith {false};
private _pendingRelease=_helicopter getVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",[]];
// Repeat administrative/old-controller release may service only its existing retired receipt.
if (_pendingRelease isEqualType [] && {count _pendingRelease == 2}
    && {_snapshot isEqualType []} && {count _snapshot == 6}
    && {(_pendingRelease select 0) isEqualTo _snapshot}
    && {(_pendingRelease select 1) isEqualType 0} && {finite (_pendingRelease select 1)}
    && {!(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_Active",false])}
    && {(_snapshot select 0) isEqualType 0}
    && {_releasedRevision == (_snapshot select 0)+1}
    && {_expectedRevision < 0 || {_expectedRevision == (_snapshot select 0)}}) exitWith {
    [_helicopter,_pendingRelease] call CBE_fnc_ImprovedHelicopterLandingFeatureReleaseLocal;
    true
};
if (_expectedRevision < 0) then {_expectedRevision=_releasedRevision};
if (_releasedRevision != _expectedRevision
    || {(_snapshot select 0) isNotEqualTo _expectedRevision}) exitWith {false};
private _pilot=_snapshot select 2;
private _lease=_helicopter getVariable ["CBE_FlightLease",createHashMap];
if !(_lease isEqualType createHashMap) exitWith {false};
private _matchingLease=count _lease > 0 && {(_lease getOrDefault ["controller",""]) == "LANDING"}
    && {(_lease getOrDefault ["token",""]) == str _expectedRevision}
    && {(_lease getOrDefault ["owner",-1]) == (_snapshot select 1)};
// Another controller retains its lease. Retire only our metadata and defer our feature writes.
private _wasGroundAnchored=_helicopter getVariable ["CBE_ImprovedHelicopterLanding_GroundAnchored",false];
private _releaseHeight=_helicopter getVariable ["CBE_ImprovedHelicopterLanding_ReleaseHeight",100];
private _restored=false;
isNil {
    if (local _helicopter
        && {(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_ControlRevision",-1]) == _expectedRevision}
        && {(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot",[]]) isEqualTo _snapshot}
        && {(_helicopter getVariable ["CBE_FlightLease",createHashMap]) isEqualTo _lease}) then {
        private _leaseReleased=true;
        if (_matchingLease) then {
            if ((_lease getOrDefault ["owner",-1]) == clientOwner) then {
                _leaseReleased=[_helicopter,"LANDING",str _releasedRevision,["ABORTED","LANDED"] select _landed]
                    call CBE_fnc_FlightLeaseRelease;
            } else {
                // Exact previous-owner metadata may retire on actual aircraft-local adoption.
                _helicopter setVariable ["CBE_FlightLeaseLast",["LANDING",str _expectedRevision,
                    _lease getOrDefault ["revision",-1],["ABORTED","LANDED"] select _landed,serverTime],true];
                _helicopter setVariable ["CBE_FlightLease",nil,true];
            };
        };
        if (!_leaseReleased) exitWith {};
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_ControlRevision",_expectedRevision+1,true];
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_Active",false,true];
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_GearLocal",false];
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_GroundAnchored",false,true];
        _pendingRelease=[+_snapshot,serverTime+60];
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",_pendingRelease,true];
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseResult",
            ["PENDING",_snapshot select 0,_snapshot select 1,_pendingRelease select 1,serverTime],true];
        _restored=true;
    };
};
if (!_restored) exitWith {false};
// The actor-local bounded release service preserves unresolved provenance across migration.
// No current/replacement pilot receives FSM restoration from this cleanup.
if (!isNull _pilot && {local _pilot}) then {
    private _pilotReceipt=_pilot getVariable ["CBE_AirPilotFeatureReceipt",[]];
    if (_pilotReceipt isEqualType [] && {count _pilotReceipt == 8} && {(_pilotReceipt select 0) isEqualTo 2}
        && {(_pilotReceipt select 1) isEqualTo _pilot} && {(_pilotReceipt select 2) isEqualTo _helicopter}
        && {(_pilotReceipt select 4) == "LANDING:"+str _expectedRevision}
        && {(_pilotReceipt select 5) isEqualTo (_snapshot select 1)}
        && {(_pilotReceipt select 6) isEqualTo ["FSM"]}) then {
        [_pilot,_pilotReceipt] call CBE_fnc_CortexAirPilotFeatureRelease;
    };
};
// A deferred feature-only retry must never replay this native flight handback.
private _featuresRestored=[_helicopter,_pendingRelease] call CBE_fnc_ImprovedHelicopterLandingFeatureReleaseLocal;
if (!_featuresRestored) exitWith {true};
// Actor release can defer through helpers. Final native handback is its own short commit,
// never permission carried across cleanup into a successor flight controller.
isNil {
    private _nativeLease=_helicopter getVariable ["CBE_FlightLease",createHashMap];
    if (!local _helicopter || {!alive _helicopter} || {isNull _pilot}
        || {currentPilot _helicopter != _pilot} || {!local _pilot}
        || {isPlayer _pilot} || {!isNull remoteControlled _pilot}
        || {!([_pilot] call CBE_fnc_CortexActorFireTaskAvailable)}
        || {!(_nativeLease isEqualType createHashMap)} || {count _nativeLease > 0}
        || {(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_ControlRevision",-1]) != _expectedRevision+1}
        || {[group _pilot] call CBE_fnc_CortexExternalTakeover}
        || {[group _pilot] call CBE_fnc_CortexZeusHeld}) exitWith {};
if (_landed) then {
    _helicopter setVelocity [0, 0, 0];
    _helicopter land "LAND";
    if (toUpperANSI _waypointType == "GETOUT") then {_helicopter engineOn false;};
} else {
    _helicopter land "NONE";
    if (_stabiliseAirborne && {!isTouchingGround _helicopter}) then {
        private _velocity = velocity _helicopter;
        // The vector controller may have issued a strong descent immediately before Zeus grouped
        // the aircraft. Arma formation control does not reliably arrest that inherited velocity in
        // time. Preserve horizontal flight and any climb, but remove CBE's residual dive.
        _helicopter setVelocity [_velocity select 0, _velocity select 1, (_velocity select 2) max 0];
    };
    if (
        _wasGroundAnchored
        && {!isNull _pilot}
        && {!isPlayer _pilot}
        && {isNull (remoteControlled _pilot)}
        && {isEngineOn _helicopter}
    ) then {
        // The anchor used forced height zero, which must be replaced before a new route can take
        // effect. Use the pre-approach height without forcing it: vanilla collision avoidance and
        // formation spacing retain priority after CBE releases ownership.
        _helicopter flyInHeight ((_releaseHeight max 20) min 500);
    };
};
};
true
