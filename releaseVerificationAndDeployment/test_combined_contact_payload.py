"""Combined-arms contact transport admission; static/analytic, not physical acceptance."""
from pathlib import Path
import math
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CombinedContactPayloadTests(unittest.TestCase):
    def test_request_server_owner_share_finite_three_coordinate_boundary(self):
        files=['cortexCombinedArmsRequest','cortexCombinedArmsServer','cortexCombinedArmsLocal']
        for name in files:
            s=(ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')
            self.assertIn('count _position != 3',s)
            self.assertIn('!finite _x',s)
            self.assertIn('abs _x > 1e6',s)
            boundary=s.index('count _position != 3')
            if name.endswith('Request'):
                self.assertLess(boundary,s.index('_state set ["combinedArmsDue"'))
            elif name.endswith('Server'):
                self.assertLess(boundary,s.index('_requester setVariable ["CBE_Cortex_CombinedDue"'))
            else:
                self.assertLess(boundary,s.index('private _asset='))
    def test_invalid_positions_cannot_be_valid_contact_vectors(self):
        def admitted(p):
            return isinstance(p,list) and len(p)==3 and all(type(v) in (int,float) and math.isfinite(v) and abs(v)<=1e6 for v in p)
        for p in ([1,2],[1,2,3,4],[1,2,float('nan')],[float('inf'),2,3],[1,2,'3'],[1,2,1e6+1]):
            self.assertFalse(admitted(p),repr(p))
        self.assertTrue(admitted([1250,3500,0]))
        self.assertTrue(admitted([-1e6,1e6,-10]))
    def test_contact_receipt_is_preserved_without_fallback_or_replay_refresh(self):
        def source(name):
            return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')
        knowledge=source('cortexKnowledge')
        request=source('cortexCombinedArmsRequest')
        server=source('cortexCombinedArmsServer')
        owner=source('cortexCombinedArmsLocal')
        self.assertIn('_confidence=_group knowsAbout _enemy',knowledge)
        self.assertNotIn('_confidence=_confidence max (_x knowsAbout _enemy)',knowledge)
        self.assertIn('if (isNull _group || {!local _group}) exitWith {[[],0]}',knowledge)
        self.assertIn('_contact param [5,1,[0]]',request)
        self.assertIn('serverTime-_age,_confidence min 2.5',request)
        self.assertIn('_contactReceipt=[1,_observedAt,_confidence min 2.5]',server)
        self.assertIn('serverTime-(_contactReceipt select 1) <= 10',owner)
        self.assertIn('if (_freshReport && {(_group getVariable ["CBE_Cortex_CombinedReportLocal",[]]) isNotEqualTo _applicationIdentity})',owner)
        self.assertIn('_group reveal [_target,_contactReceipt select 2]',owner)
        self.assertIn('_group setVariable ["CBE_Cortex_CombinedReportLocal",_applicationIdentity]',owner)
        self.assertIn('"NO_KNOWN_CONTACT"',owner)
        for name in ('cortexCombinedAirFallbackServer','cortexCombinedGroundFallbackServer'):
            fallback=source(name)
            self.assertIn('_fallback param [6,[],[[]]]',fallback)
            self.assertIn('+_contactReceipt',fallback)
            self.assertIn('isNotEqualTo _contactReceipt',fallback)
            self.assertNotIn('_contactReceipt=[1,serverTime',fallback)
        tick=source('cortexGroupTick')
        self.assertIn('(count _combinedRole) in [7,8]',tick)
    def test_delayed_replacement_does_not_gain_fresh_observation_or_confidence(self):
        receipt=(1,100,1.2)
        def transferable(r,now):
            return len(r)==3 and r[0]==1 and 0<=r[1]<=now+1 and now-r[1]<=10 and 0<r[2]<=2.5
        self.assertTrue(transferable(receipt,105))
        replacement=tuple(receipt)
        self.assertFalse(transferable(replacement,111))
        self.assertEqual(replacement[2],1.2)
        self.assertFalse(transferable((),105))
        self.assertFalse(transferable((1,100,3),105))
        self.assertFalse(transferable((1,200,1),105))
if __name__=='__main__':unittest.main()


class CombinedGroundPhysicalArrivalTests(unittest.TestCase):
    def test_ground_arrival_and_completed_route_share_asl_distance(self):
        text=(ROOT/'addons/infantry/functions/cortexCombinedGroundStep.sqf').read_text()
        self.assertIn('private _arrivalDistance=(getPosASL _asset) vectorDistance (AGLToASL _destination)',text)
        self.assertEqual(text.count('_arrivalDistance > 70'),2)
        self.assertEqual(text.count('_arrivalDistance <= 70'),1)
        self.assertNotIn('_asset distance2D _destination',text)
        import math
        self.assertLessEqual(math.dist((0,0,4),(0,0,0)),70)
        self.assertGreater(math.dist((0,0,150),(0,0,0)),70)
        self.assertGreater(math.dist((60,0,50),(0,0,0)),70)


class CombinedMountedDiscoveryTests(unittest.TestCase):
    def test_spatial_discovery_explicitly_includes_live_mounted_crew(self):
        text=(ROOT/'addons/infantry/functions/cortexCombinedArmsServer.sqf').read_text()
        discovery=text.split('private _searchRadius=',1)[1].split('private _orderedGroups=',1)[0]
        self.assertIn('_airRange max _groundRange',discovery)
        self.assertIn('[getPosATL _requesterAnchor,_searchRadius,_searchRadius,0,false,_searchRadius]',discovery)
        self.assertIn('_searchArea nearEntities [["Man"],false,true,true]',discovery)
        self.assertNotIn('nearEntities ["Man",',discovery)
        self.assertNotIn('allUnits',discovery)
        self.assertNotIn('allGroups',discovery)
        self.assertIn('netId _candidateGroup',discovery)
        self.assertIn('_candidateSeen set [_candidateKey,true]',discovery)
        config=(ROOT/'addons/main/config.cpp').read_text()
        self.assertIn('requiredVersion = 2.18;',config)


class MountedReportDeliveryTests(unittest.TestCase):
    def test_report_discovery_and_both_endpoints_preserve_radio_and_voice_boundaries(self):
        server=(ROOT/'addons/infantry/functions/cortexReportServer.sqf').read_text()
        owner=(ROOT/'addons/infantry/functions/cortexReportLocal.sqf').read_text()
        self.assertIn('_receiverArea nearEntities [["Man"],false,true,true]',server)
        self.assertIn('<= _voiceRange',server)
        self.assertIn('!isNull _transmitter && {!isNull _receiverTransmitter}',server)
        self.assertIn('> _voiceRange',owner)
        self.assertIn('isNull _transmitter || {isNull _receiverTransmitter}',owner)
        self.assertLess(owner.index('> _voiceRange'),owner.index('setVariable ["CBE_AIPass_AreaReport"'))
        self.assertIn('for "_i" from 1 to 8',server)
        for text in (server,owner):
            self.assertNotIn(' reveal ',text)
            self.assertNotIn('doMove',text)


class ReportObservationAgeTests(unittest.TestCase):
    def test_relay_cannot_refresh_observation_or_invalid_payload_cooldown(self):
        server=(ROOT/'addons/infantry/functions/cortexReportServer.sqf').read_text()
        owner=(ROOT/'addons/infantry/functions/cortexReportLocal.sqf').read_text()
        for text in (server,owner):
            for guard in ('!finite _sent','_sent < 0','!finite _x','abs _x > 1e6',
                          'finite (_x select 1)','finite (_x select 2)','(_x select 2) <= _sent+1'):
                self.assertIn(guard,text)
        self.assertLess(server.index('if (_valid isEqualTo []) exitWith'),server.index('setVariable ["CBE_AIPass_ReportServerDue"'))
        self.assertIn('private _observed=_best select 2',owner)
        self.assertIn('(_previous select 1) >= _observed',owner)
        self.assertIn('[+(_best select 0),_observed,_observed+30,"REPORT"]',owner)
        self.assertNotIn('_sent+30',owner)
