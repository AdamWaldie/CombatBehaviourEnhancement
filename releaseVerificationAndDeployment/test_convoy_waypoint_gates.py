"""Convoy route recovery must preserve authored waits and same-index replacements."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ConvoyWaypointGateTests(unittest.TestCase):
    def test_recovery_reads_gates_without_executing_them(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        gate=s.split('private _mayRecoverWaypoint=',1)[1].split('// A stalled engine route',1)[0]
        for field in ('waypointStatements','waypointScript','waypointTimeout','synchronizedTriggers','triggerActivated',
                      'isNull waypointAttachedVehicle _waypoint','isNull waypointAttachedObject _waypoint',
                      '(synchronizedWaypoints _waypoint) isEqualTo []'):
            self.assertIn(field,gate)
        for forbidden in ('compile','execVM','call compile'):
            self.assertNotIn(forbidden,gate)
        self.assertIn('[_watchedWaypoint] call _mayRecoverWaypoint',s)
        self.assertIn('[_waypoint] call _mayRecoverWaypoint',s)
    def test_watched_metadata_and_lead_retry_identity_are_checked(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertIn('isEqualTo _watchedReceipt',s)
        self.assertIn('isNotEqualTo _leadRouteReceipt',s)
        self.assertIn('_state set ["leadRouteReceipt",_leadRouteReceipt]',s)
        self.assertIn('_leadProgress=[getPosATL _lead,time,0]',s)
        helper=(ROOT/'addons/core/functions/authoredRouteReceipt.sqf').read_text(encoding='utf-8')
        self.assertIn('["_waypointIndex",-1,[0]]',helper)
        self.assertIn('(_x select 1) == _waypointIndex',helper)
    def test_implicit_waypoint_and_movement_operator_are_not_recalled(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertIn('(_waypoint select 1) > 0',s)
        self.assertIn('&& {_waypointIndex > 0}',s)
        self.assertIn('&& {_routeIndex > 0}',s)
        restart=s.split('// Clear a previous HALT',1)[1].split('call CBE_fnc_ConvoyUnloadPolicy',1)[0]
        for guard in ('currentWaypoint _group > 0','driver _lead != leader _group','driver _lead != _leadOperator','vehicle leader _group == _lead'):
            self.assertIn(guard,restart)
    def test_final_endpoint_retry_commits_under_current_controller_and_native_order(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        retry=s.split('private _routeWatch=',1)[1].split('private _routeDone',1)[0]
        commit=retry.split('isNil {',1)[1]
        write=commit.index('_group setCurrentWaypoint _watchedWaypoint')
        for guard in ('!local _group', '!local _leadOperator', 'driver _lead != _recoveryDriver',
                      'call _mayRecallLead', 'isNotEqualTo _recoveryBrain',
                      'CBE_Convoy_LocalJobToken', 'CBE_Convoy_ReceivedRevision',
                      'CBE_Convoy_LocalRegistry', '_phase != "TRAVEL"',
                      'isNotEqualTo _watchedReceipt', 'isNotEqualTo _recoveryCommands',
                      'call _mayRecoverWaypoint', 'CBE_DrivingCorridor_Work',
                      'CBE_DrivingBypass_Work', 'CBE_Convoy_BypassPassage'):
            self.assertIn(guard,commit[:write])
        self.assertGreater(commit.index('_leadOperator doMove'),write)
        self.assertGreater(commit.index('_state set ["routeRecoveryAt"'),write)
        self.assertGreater(commit.index('CBE_Convoy_RouteRecoveries'),write)
    def test_endpoint_allowance_survives_local_state_and_cannot_renew_same_route(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        retry=s.split('private _routeWatch=',1)[1].split('private _routeDone',1)[0]
        journal=retry.split('private _endpointEpisode=',1)[1]
        creation=journal.split('_endpointEpisode=[',1)[0]
        self.assertIn('CBE_Convoy_EndpointRecovery',creation)
        self.assertIn('(_endpointEpisode select 0) != _revision',creation)
        self.assertIn('(_endpointEpisode select 1) isNotEqualTo _watchedReceipt',creation)
        self.assertNotIn('owner',creation)
        self.assertNotIn('time+120',creation)
        write=journal.index('_group setCurrentWaypoint')
        for guard in ('serverTime >= (_endpointEpisode select 3)',
                      '(_endpointEpisode select 4) >= 6',
                      'serverTime < (_endpointEpisode select 5)',
                      '(_endpointEpisode select 6) == "EXHAUSTED"'):
            self.assertIn(guard,journal[:write])
        self.assertIn('serverTime,serverTime+120,0,serverTime,"ACTIVE"',journal[:write])
        self.assertIn('_endpointEpisode set [4,(_endpointEpisode select 4)+1]',journal[write:])
        self.assertIn('_endpointEpisode set [5,serverTime+15]',journal[write:])
        for forbidden in ('_endpointEpisode set [2,','_endpointEpisode set [3,','deleteWaypoint','addWaypoint'):
            self.assertNotIn(forbidden,journal)
        release=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text(encoding='utf-8')
        self.assertNotIn('"CBE_Convoy_EndpointRecovery", nil',release)
    def test_recall_requires_native_task_authority_on_both_actual_seats(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        helper=s.split('private _mayRecallLead=',1)[1].split('// A stalled engine route',1)[0]
        for guard in ('effectiveCommander _vehicle','[_driver,_operator] findIf',
                      'CortexCombatEffective','CortexActorMoveReserved','CortexExternalOwner',
                      'remoteControlled','checkAIFeature "MOVE"','checkAIFeature "PATH"',
                      'currentCommand _x in ["","MOVE","WAIT"]',
                      'expectedDestination _operator','_destination vectorDistance _target <= 0.25'):
            self.assertIn(guard,helper)
        for forbidden in ('doMove','doFollow','forceSpeed','setVariable'):
            self.assertNotIn(forbidden,helper)
        endpoint=s.split('private _routeWatch=',1)[1].split('private _routeDone',1)[0]
        self.assertLess(endpoint.index('call _mayRecallLead'),endpoint.index('_group setCurrentWaypoint'))
        active=s.split('// Speed limits cannot restart',1)[1].split('private _followers',1)[0]
        commit=active.split('isNil {',1)[1]
        self.assertLess(commit.index('call _mayRecallLead'),commit.index('_leadOperator doMove'))
        self.assertLess(commit.index('call _mayRecoverWaypoint'),commit.index('_leadOperator doMove'))
        for effect in ('private _attempts=', 'CBE_fnc_ConvoyHaltServer', '_leadProgress set [2,'):
            self.assertLess(commit.index('call _mayRecallLead'),commit.index(effect))
        self.assertIn('isNotEqualTo _leadRetryBrain',commit)
        self.assertIn('CBE_Convoy_LocalRegistry',commit)

if __name__=='__main__': unittest.main()
