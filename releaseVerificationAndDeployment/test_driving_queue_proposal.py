"""Queue proposal contracts; no owner consent, movement or physical acceptance implied."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class QueueProposalTests(unittest.TestCase):
    def test_receipt_is_canonical_bounded_and_observational(self):
        s=(ROOT/'addons/vehicles/functions/drivingQueueContext.sqf').read_text(encoding='utf-8')
        body=s.split('params [["_vehicles"',1)[1]
        self.assertIn('count _vehicles > 4',body)
        self.assertIn('arrayIntersect _vehicles',body)
        self.assertNotIn('clientOwner',body)
        self.assertIn('expectedDestination _actor',body)
        self.assertIn('CBE_Driving_State',body)
        self.assertIn('call CBE_fnc_DrivingRouteReceipt',body)
        self.assertIn('getPosWorld _x,vectorDir _x,vectorUp _x',body)
        for command in ('setVariable','doMove','forceSpeed','remoteExec'):
            self.assertNotIn(command,body)
    def test_discovery_has_one_bounded_query_and_no_movement_or_consent(self):
        s=(ROOT/'addons/vehicles/functions/drivingQueueProposal.sqf').read_text(encoding='utf-8')
        body=s.split('params [["_vehicle"',1)[1]
        self.assertEqual(body.count('nearEntities'),1)
        for proof in ('120,120,0,false,120','count _candidates > 64','from 1 to 3',
                      'count _vehicles >= 4','DEPENDENCY_CYCLE','CHAIN_PARTICIPANT_BUDGET',
                      'OWNER_CONSENT_AND_NATIVE_EXECUTION_REQUIRED','(_at+2) min _until'):
            self.assertIn(proof,body)
        for command in ('setVariable','doMove','doStop','setDriveOnPath','forceSpeed',
                        'setPos','setVelocity','remoteExec','spawn','waitUntil'):
            self.assertNotIn(command,body)
    def test_natural_discovery_follows_dwell_and_stays_outside_atomic_retry(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        block=s.split('// Queue proposal discovery',1)[1].split('// Waiting behind traffic',1)[0]
        self.assertIn('serverTime-(_queueRetry get "since") >= 5',block)
        self.assertIn('serverTime-_queuePrior >= 30',block)
        self.assertIn('serverTime-(_queueSeen select 2) <= 1.5',block)
        self.assertEqual(block.count('call CBE_fnc_DrivingQueueProposal'),1)
        self.assertNotIn('isNil {',block)
        self.assertNotIn('remoteExec',block)
        self.assertNotIn('forceSpeed',block)
        self.assertIn('serverTime < (_queueRetry get "deadline")',block)
