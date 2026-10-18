"""Authored tasks retain native semantics when an owned clearance leg is released."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearNativeTaskHandoverTests(unittest.TestCase):
    def test_non_move_leader_releases_native_formation_without_fabricated_route(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        handback=s.split('if (_reason == "NEW_ORDER" && {local _group}',1)[1].split('forEach _handbacks;',1)[0]
        for guard in ('local _group','CBE_AIPass_Epoch','CBE_AIPass_ClearGeneration',
                      'currentCommand _actor == _command','_destination vectorDistance _target <= 0.25',
                      'call _actorAvailable','call _actorTaskFree','CortexExternalTakeover',
                      'call CBE_fnc_NativeOrderReceipt','count (_group getVariable ["CBE_Operation"'):
            self.assertIn(guard,handback)
        # The native return now covers leaders for MOVE as well as non-MOVE tasks,
        # preserving attachments/scripts instead of flattening MOVE to one position.
        self.assertIn('_actor doFollow leader _group;',handback)
        self.assertNotIn('if (_actor == leader _group)',handback)
        self.assertNotIn('doMove',handback)
        self.assertNotIn('waypointPosition',handback)
        for forbidden in ('addWaypoint','deleteWaypoint','setCurrentWaypoint','joinSilent','enableAI'):
            self.assertNotIn(forbidden,handback)

    def test_replacement_operation_defers_hold_retirement_and_old_drill_reunion(self):
        brain=(ROOT/'addons/infantry/functions/groupBrainStep.sqf').read_text()
        branch=brain.split('private _clearHold=',1)[1].split('private _legacyJob=',1)[0]
        admission=branch.split('setVariable ["CBE_Cortex_ClearHold",nil,true]',1)[0]
        self.assertIn('if (!_owned ||',admission)
        self.assertIn('count (_group getVariable ["CBE_Operation",createHashMap]) == 0',admission)
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        holder=tick.split('private _holderClearHold=',1)[1].split('private _holders =',1)[0]
        self.assertIn('|| {count _holderOperation > 0}',holder)
        self.assertIn('_ownedMovers append (_holderClearHold select 3)',holder)
        self.assertNotIn('doFollow',holder)
        self.assertNotIn('doMove',holder)

    def test_prepared_native_matrix_requires_real_clearance_travel_and_retained_waypoint(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        matrix=s.split('// Native waypoint handover matrix:',1)[1]
        for requirement in ('CBE_CortexQA_HeadlessBatch','call CBE_fnc_CortexClearBuilding',
                            'call _observedRoomVisit','count _entered == count _members',
                            '_visits findIf {!_x} < 0','currentCommand _x != "STOP"',
                            'movementTargets','_leader distance2D (_starts select _leaderIndex) >= 2',
                            'forEach ["HOLD","GATED_MOVE"]','forEach [false,true]',
                            'setWaypointStatements ["false",""]','_x distance2D _origin < 15',
                            'distance2D _destination) < 10','currentWaypoint _group != (_waypoint select 1)',
                            'diag_tickTime+8','isNotEqualTo _receipt',
                            '(leader _group) distance2D _destination > 20',
                            'getVariable ["CBE_Cortex_ClearHold",[]]) isEqualTo []'):
            self.assertIn(requirement,matrix)
        observe=matrix.split('// Cleanup occurs only',1)[0]
        for shortcut in ('doMove','doFollow','doStop','setPos','call _finish',
                         'setVariable ["CBE_Cortex_ClearHold"','setVariable ["CBE_Cortex_ClearResult"'):
            self.assertNotIn(shortcut,observe)
        self.assertLess(matrix.index('"-native-waypoint-retained"'),matrix.index('call CBE_fnc_CortexClearRelease'))
