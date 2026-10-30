"""Static safeguards for bounded squad communication fallbacks."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(name: str) -> str:
    matches = list(ROOT.glob(f"addons/**/functions/{name}.sqf"))
    if len(matches) != 1:
        raise AssertionError(f"Expected one source for {name}, got {matches}")
    return matches[0].read_text(encoding="utf-8")


class GroupCommunicationTests(unittest.TestCase):
    def test_voice_requires_vertical_reach_while_radio_remains_independent(self):
        import math
        owner=source('cortexReportLocal')
        server=source('cortexReportServer')
        # Reports follow mutual mission allegiance, not a same-side shortcut.
        # Delivery must recheck both directions before storing the area estimate.
        for sides in ('(side _receiver) getFriend (side _sender)',
                      '(side _sender) getFriend (side _receiver)'):
            self.assertIn(sides+' >= 0.6',server)
            self.assertIn(sides+' < 0.6',owner)
            self.assertLess(owner.index(sides+' < 0.6'),owner.index('setVariable ["CBE_AIPass_AreaReport"'))
        self.assertNotIn('side _receiver == side _sender',server)
        self.assertNotIn('side _receiver != side _sender',owner)
        sender=source('cortexContactReport')
        self.assertIn('serverTime - (_x select 2),side _target]',sender)
        for text,recipient in ((server,'_sender'),(owner,'_receiver')):
            for proof in ('count _x == 4','(_x select 3) isEqualType west',
                          '(_x select 3) in [west,east,resistance]',
                          '(side '+recipient+') getFriend (_x select 3) < 0.6'):
                self.assertIn(proof,text)
        self.assertLess(owner.index('(side _receiver) getFriend (_x select 3) < 0.6'),
                        owner.index('setVariable ["CBE_AIPass_AreaReport"'))
        combined=source('cortexCombinedArmsServer')
        fallback=source('cortexCombinedGroundFallbackServer')
        self.assertIn('private _receiverArea=[_senderPosition,_range,_range,0,false,-1]',server)
        self.assertIn('private _searchArea=[getPosATL _requesterAnchor,_searchRadius,_searchRadius,0,false,-1]',combined)
        # Receiver discovery must be a superset of the existing horizontal radio rule.
        # The former finite-height cylinder omitted these otherwise valid receivers.
        for radius,point in ((500,(300,0,800)),(4000,(1000,0,5000))):
            horizontal=math.hypot(*point[:2])
            self.assertLessEqual(horizontal,radius)
            self.assertGreater(abs(point[2]),radius)
            self.assertGreater(math.dist((0,0,0),point),35)
        # Without both radio endpoints, unlimited-height discovery grants no voice reach.
        def communication(point,sender_radio,receiver_radio,radius=500):
            return math.hypot(*point[:2])<=radius and (
                (sender_radio and receiver_radio) or math.dist((0,0,0),point)<=35)
        for radios in ((False,False),(True,False),(False,True)):
            self.assertFalse(communication((20,0,800),*radios))
        self.assertTrue(communication((300,0,800),True,True))
        self.assertFalse(communication((501,0,0),True,True))
        self.assertTrue(communication((20,0,28),False,False))
        self.assertIn('_receiverPosition vectorDistance _senderPosition > _voiceRange',owner)
        self.assertIn('getPosASL _senderAnchor',owner)
        self.assertIn('(getPosASL _receiverAnchor) vectorDistance _senderASL <= _voiceRange',server)
        self.assertIn('(getPosASL _candidateAnchor) vectorDistance _requesterASL <= _voiceRange',combined)
        self.assertIn('(getPosASL _anchor) vectorDistance _originASL <= _voiceRange',fallback)
        # Horizontal overlap alone cannot carry voice between stacked floors or an aircraft.
        self.assertGreater(math.dist((0,0,0),(0,0,100)),35)
        self.assertLess(math.dist((0,0,0),(20,0,28)),35)
        self.assertGreater(math.dist((0,0,0),(20,0,30)),35)
        for text in (server,combined,fallback):
            self.assertIn('|| {',text)
        self.assertIn('_senderRadio && {_candidateRadio}',combined)

    def test_combined_owner_checks_delivery_before_effects_but_after_received_task_replay(self):
        owner=source('cortexCombinedArmsLocal')
        start=owner.index('// Selection and owner delivery')
        end=owner.index('private _markApplied=',start)
        delivery=owner[start:end]
        self.assertLess(owner.index('private _applied=[_token,clientOwner,_application select 1]'),start)
        self.assertLess(end,owner.index('_group reveal'))
        self.assertIn('[_requester] call CBE_fnc_CortexGroupTransmitter',delivery)
        self.assertIn('[_group] call CBE_fnc_CortexGroupTransmitter',delivery)
        for check in ('alive _senderAnchor','alive _receiverAnchor',
                      '_receiverASL distance2D _senderASL <= _communicationRange',
                      '_receiverASL vectorDistance _senderASL <= _voiceRange',
                      '!isNull _senderTransmitter && {!isNull _receiverTransmitter}',
                      'CBE_Cortex_CombinedArms_AirRange",4000',
                      'CBE_AIPass_ContactReports_Radius",500',
                      '[_requester,_group,_token,+_opportunity] remoteExecCall',
                      '[_group,_opportunity,"NO_COMMUNICATION",clientOwner] remoteExecCall'):
            self.assertIn(check,delivery)
        self.assertIn('"NO_COMMUNICATION"',source('cortexCombinedRejectServer'))
        self.assertNotIn('call _markApplied',delivery)
        self.assertNotIn(' reveal ',delivery)

    def test_group_transmitter_prefers_leader_but_falls_back_to_a_living_wingman(self):
        transmitter = source("cortexGroupTransmitter")
        self.assertIn('private _leader = leader _group;', transmitter)
        self.assertIn('_checked >= 12', transmitter)
        self.assertIn('if (_leaderEligible && {!_requireRadio || {[_leader] call CBE_fnc_CortexCanTransmit}}) exitWith {_leader}',transmitter)
        self.assertLess(transmitter.index('exitWith {_leader}'),transmitter.index('forEach (units _group)'))
        self.assertNotIn(' select {',transmitter)
        def previous(roster,leader):
            eligible=[r for r in roster if r[1]]
            lead=next((r for r in eligible if r[0]==leader),None)
            if lead: eligible=[lead]+[r for r in eligible if r[0]!=leader]
            return next((r[0] for r in eligible[:12] if r[2]),None)
        def streamed(roster,leader):
            lead=next((r for r in roster if r[0]==leader and r[1]),None)
            if lead and lead[2]: return lead[0]
            checked=int(lead is not None)
            for r in roster:
                if checked>=12: break
                if r[0]!=leader and r[1]:
                    checked+=1
                    if r[2]: return r[0]
            return None
        # Stable rosters preserve the original first12 eligible candidates, including
        # unavailable leaders, sparse eligible members and a13th jam-free candidate.
        for count in (0,1,6,12,13,64):
            for leader in (-1,0,count-1):
                for eligible_stride in (1,2,5):
                    for free in (-1,0,1,11,12,63):
                        roster=[(i,i%eligible_stride==0,i==free) for i in range(count)]
                        self.assertEqual(streamed(roster,leader),previous(roster,leader))
        self.assertIn('[_x] call CBE_fnc_CortexCanTransmit', transmitter)
        self.assertIn('[_leader] call CBE_fnc_CortexCombatEffective',transmitter)
        self.assertIn('["_requireRadio",true,[true]]',transmitter)
        self.assertIn('!_requireRadio || {[_x] call CBE_fnc_CortexCanTransmit}',transmitter)
        for name,groups in (('cortexReportServer',('_sender','_receiver')),
                            ('cortexReportLocal',('_sender','_receiver')),
                            ('cortexCombinedArmsServer',('_requester','_candidateGroup','_candidate')),
                            ('cortexCombinedArmsLocal',('_requester','_group')),
                            ('cortexCombinedGroundFallbackServer',('_requester','_candidate'))):
            text=source(name)
            for group in groups:
                self.assertIn('['+group+',false] call CBE_fnc_CortexGroupTransmitter',text)
        # A jammed but capable voice witness is distinct from radio permission.
        def witness(rows,radio):
            return next((name for name,capable,can_radio in rows
                         if capable and (not radio or can_radio)),None)
        rows=(('leader',False,True),('wingman',True,False))
        self.assertIsNone(witness(rows,True))
        self.assertEqual(witness(rows,False),'wingman')
        self.assertIsNone(witness((('unconscious',False,False),),False))
        self.assertIn('[_x] call CBE_fnc_CortexCombatEffective',transmitter)
        radio=source('cortexCanTransmit')
        self.assertLess(radio.index('[_unit] call CBE_fnc_CortexCombatEffective'),radio.index('private _hook'))
        self.assertLess(transmitter.index('[_x] call CBE_fnc_CortexCombatEffective'),transmitter.index('_checked=_checked+1'))
        readiness=source('cortexCombatEffective')
        for guard in ('alive _unit','ACE_isUnconscious','INCAPACITATED','captive _unit',
                      'ace_captives_isSurrendering','ace_captives_isHandcuffed'):
            self.assertIn(guard,readiness)
        self.assertNotIn('damage _unit',readiness)
        self.assertIn('_factor < 0.5',radio)
        self.assertIn('if (isNil "_factor") exitWith {true}',radio)
        self.assertLess(radio.index('call CBE_fnc_CortexJammingFactor'),radio.index('private _hook'))
        field=source('cortexJammingField');factor=source('cortexJammingFactor')
        for proof in ('!isServer','remoteExecutedOwner','count _original > 32',
                      '_radius > 100000','_sides findIf','CBE_EW_Fields",_fields,true',
                      '_fields isNotEqualTo _original','_fields deleteAt _index'):
            self.assertIn(proof,field)
        for proof in ('count _fields > 32','_side in (_row select 2)',
                      'alive (_row select 0)','getPosASL (_row select 0)',
                      'vectorDistance','exitWith {_factor=1}'):
            self.assertIn(proof,factor)
        for worker in ('spawn','sleep','addPerFrameHandler','allUnits','vehicles select',
                       'setVelocity','engineOn','enableChannel','enableRadio'):
            self.assertNotIn(worker,field)
            self.assertNotIn(worker,factor)

        for forbidden in ['reveal ', 'doMove', 'doFollow', 'setVariable']:
            self.assertNotIn(forbidden, transmitter)

    def test_coordination_uses_group_communication_without_creating_target_knowledge(self):
        callers = [
            'cortexSupportServer', 'cortexSupportApply', 'cortexSupportAssaultServer',
            'cortexReinforce', 'cortexCombinedArmsServer', 'cortexReportServer',
            'cortexReportLocal', 'cortexArtilleryFire', 'cortexRetreat',
        ]
        for caller in callers:
            self.assertIn('CBE_fnc_CortexGroupTransmitter', source(caller), caller)
        report = source('cortexReportServer')
        report_local = source('cortexReportLocal')
        self.assertIn('private _transmitter = [_sender] call CBE_fnc_CortexGroupTransmitter;', report)
        self.assertIn('private _senderPosition = getPosATL _senderAnchor;', report)
        self.assertIn('_receiverAnchor distance2D _senderPosition <= _range', report)
        self.assertIn('private _receiverTransmitter = [_receiver] call CBE_fnc_CortexGroupTransmitter;', report_local)
        self.assertIn('private _receiverPosition = getPosASL _receiverAnchor;', report_local)
        self.assertIn('_receiverPosition distance2D _senderPosition > _range', report_local)
        self.assertNotIn(' reveal ', report)
        self.assertNotIn('doTarget', report)
        self.assertIn('private _receiverTransmitter = [_receiver] call CBE_fnc_CortexGroupTransmitter;', report)
        self.assertIn('_receiverAnchor distance2D _senderPosition <= _range', report)

    def test_support_and_combined_arms_use_live_communication_anchors(self):
        support = source('cortexSupportServer')
        apply = source('cortexSupportApply')
        step = source('cortexSupportStep')
        assault = source('cortexSupportAssaultServer')
        combined = source('cortexCombinedArmsServer')
        self.assertIn('private _requesterPosition=getPosATL _requesterTransmitter;', support)
        self.assertIn('["discoveryOrigin",+_requesterPosition]', support)
        self.assertIn('private _discoveryOrigin=_job get "discoveryOrigin";', step)
        self.assertIn('[_candidate] call CBE_fnc_CortexGroupTransmitter', step)
        self.assertIn('_candidateTransmitter distance2D _discoveryOrigin', step)
        self.assertIn('_groupTransmitter distance2D _requesterTransmitter', apply)
        self.assertIn('private _requesterTransmitter = [_requester] call CBE_fnc_CortexGroupTransmitter;', step)
        self.assertIn('private _helperTransmitter = [_helper] call CBE_fnc_CortexGroupTransmitter;', step)
        self.assertIn('private _supportOrigin=getPosATL _requesterTransmitter;', assault)
        self.assertIn('private _routeOrigin=getPosATL _helperTransmitter;', assault)
        self.assertIn('private _requesterAnchor=if (isNull _requesterTransmitter)', combined)
        self.assertIn('_candidateAnchor distance2D _requesterAnchor', combined)
        self.assertIn('[_candidate] call CBE_fnc_CortexGroupTransmitter', source('cortexCombinedAirFallbackServer'))
        self.assertIn('private _requesterTransmitter=[_requester] call CBE_fnc_CortexGroupTransmitter;', source('cortexSupportCoordinateStep'))

    def test_group_transmitter_is_registered_as_a_wait_function(self):
        config = (ROOT / 'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CortexGroupTransmitter', config)
        self.assertIn('cortexGroupTransmitter.sqf', config)

