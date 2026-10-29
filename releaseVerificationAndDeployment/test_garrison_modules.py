"""Offline authority and task-control contracts; physical module acceptance remains pending."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(name): return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text()
class GarrisonModuleTests(unittest.TestCase):
    def test_network_sender_is_authenticated_before_pending_allocation(self):
        dispatch=src('cortexOrderDispatch')
        for required in ('isRemoteExecuted','_requestOwner = _sender','getAssignedCuratorLogic','count _pairs > 16','count _pending >= 64'):
            self.assertIn(required,dispatch)
            self.assertLess(dispatch.index(required),dispatch.index('_pending set [_token'))
        self.assertIn('count _pos == 3',dispatch)
        self.assertIn('_teleport isEqualType true',dispatch)
        self.assertIn('_settings set ["requestSerial",_serial]',dispatch)
    def test_owner_rejects_stale_tasks_before_order_mutation(self):
        local=src('cortexOrderLocal')
        for required in ('remoteExecutedOwner != 2','CBE_Cortex_LastTaskSerial','CBE_fnc_NativeOrderReceipt','_token != str _serial'):
            self.assertLess(local.index(required),local.index('setVariable ["CBE_AIPass_ZeusWaypoints"'))
        self.assertIn('createHashMapFromArray [["teleport",_teleport],["sortByHeight",_sortByHeight]]',local)
    def test_timed_out_task_cannot_later_start_on_the_owner(self):
        dispatch=src('cortexOrderDispatch');local=src('cortexOrderLocal')
        self.assertIn('_settings set ["requestDeadline",serverTime+12]',dispatch)
        self.assertLess(dispatch.index('_settings set ["requestDeadline"'),dispatch.index('remoteExecCall ["CBE_fnc_CortexOrderLocal"'))
        for guard in ('getOrDefault ["requestDeadline",-1]','!(_deadline isEqualType 0)',
                      '!finite _deadline','serverTime >= _deadline'):
            self.assertLess(local.index(guard),local.index('setVariable ["CBE_Cortex_LastTaskSerial"'))
        self.assertIn('The task expired',local)

    def test_garrison_controls_are_explicit_scoped_tasks(self):
        native=src('moduleGarrison'); zen=src('zenGarrisonModule')
        self.assertIn('attachedTo _logic',native)
        self.assertNotIn('nearestObjects',native)
        self.assertNotIn('nearestObjects',zen)
        self.assertIn('[[false,true],["Walk into positions","Instant interior placement"],0]',zen)
        self.assertIn('[15,150,50,0]',zen)
        self.assertIn('call CBE_fnc_CortexOrderDispatch',zen)
        for text in (native,zen):
            self.assertNotIn('CBA_fnc_addSetting',text)
            self.assertNotIn('CBA_settings_fnc_set',text)
        release=src('zenReleaseModule')
        for required in ('["order","RELEASE"]','["group",_group]','call CBE_fnc_CortexOrderDispatch',
                         'count _groups) min 128','No selectable AI squad','["COMBO"'):
            self.assertIn(required,release)
        for forbidden in ('CBA_fnc_addSetting','CBA_settings_fnc_set','enableAI','joinSilent',
                          'clearWaypoints','setPos','doFollow','nearestObjects'):
            self.assertNotIn(forbidden,release)
        config=(ROOT/'addons/main/config.cpp').read_text()
        self.assertIn('class CBE_ModuleRelease: CBE_ModuleGarrison',config)
        self.assertIn('CBE_operation = "RELEASE"',config)
        self.assertIn('call CBE_fnc_ZenReleaseModule',native)
        dispatch=src('cortexOrderDispatch'); local=src('cortexOrderLocal')
        self.assertIn('"GARRISON","DEFEND","CLEAR","RELEASE","AIRBORNE"',dispatch)
        self.assertNotIn('"RELEASE", "AIRBORNE"]',local.split('private _temporaryControl=[];',1)[1].split('private _previousClearFailure=',1)[0])
        self.assertIn('No infantry task was released',local)
        patrol=src('zenPatrolModule')
        self.assertIn('class CBE_ModulePatrol: CBE_ModuleGarrison',config)
        self.assertIn('call CBE_fnc_ZenPatrolModule',native)
        for key in ('patrolNodes','patrolDuration'):
            self.assertIn('"'+key+'"',patrol)
            self.assertIn('getOrDefault ["'+key+'"',dispatch)
            self.assertIn('getOrDefault ["'+key+'"',local)
        for control in ('[25,500,100,0]','[3,8,4,0]','[30,1800,900,0]'):
            self.assertIn(control,patrol)
        self.assertIn('case "PATROL": {["START",_group,',local)
        self.assertIn('["CANCEL",_group,["MODULE_RELEASE"]]',local)
        self.assertIn('_nodes == floor _nodes',dispatch)
        self.assertIn('_patrolNodes != floor _patrolNodes',local)
        self.assertIn('_radius <= 500',dispatch)
        self.assertIn('_radius > 500',local)
        self.assertIn('_duration <= 1800',dispatch)
        self.assertIn('_patrolDuration > 1800',local)
        for private in ('patrolOperation','patrolRouteCommit'):
            self.assertIn('remoteExecutedOwner != 2',src(private))
        for text in (patrol,native,release):
            self.assertNotIn('CBA_fnc_addSetting',text)
            self.assertNotIn('CBA_settings_fnc_set',text)


    def test_height_choice_reaches_executor_and_is_not_rerolled_on_adoption(self):
        zen=src('zenGarrisonModule'); dispatch=src('cortexOrderDispatch'); local=src('cortexOrderLocal'); execute=src('cortexGarrison')
        self.assertIn('["sortByHeight",_sortByHeight]',zen)
        for text in (dispatch,local,execute):
            self.assertIn('_sortByHeight isEqualType true',text)
        self.assertIn('["sortByHeight",_sortByHeight]',local)
        self.assertIn('if (_sortByHeight) then {-(_position select 2)} else {random 1}',execute)
        self.assertNotIn('sortByHeight',src('cortexGarrisonApplyLocal'))
    def test_receipts_include_authored_waits_and_zeus_replacement(self):
        receipt=(ROOT/'addons/core/functions/nativeOrderReceipt.sqf').read_text()
        metadata=(ROOT/'addons/core/functions/authoredRouteReceipt.sqf').read_text()
        self.assertIn('[_group,"",false,_index] call CBE_fnc_AuthoredRouteReceipt',receipt)
        for command in ('waypointCompletionRadius','waypointStatements','waypointTimeout','synchronizedTriggers',
                        'waypointScript','waypointAttachedObject','waypointAttachedVehicle',
                        'synchronizedWaypoints','waypointHousePosition','waypointLoiterAltitude'):
            self.assertIn(command+' _waypoint',metadata)
        self.assertNotIn('call compile',receipt)
        self.assertNotIn('execVM',receipt)
        dispatch=src('cortexOrderDispatch'); local=src('cortexOrderLocal')
        self.assertIn('_settings set ["controlReceipt",[',dispatch)
        for key in ('CBE_AIPass_ZeusHold','CBE_AIPass_ZeusWaypoints','CBE_AIPass_ZeusControlKind'):
            self.assertIn(key,dispatch)
            self.assertIn(key,local)
        self.assertLess(local.index('_controlReceipt isNotEqualTo _currentControl'),local.index('setVariable ["CBE_Cortex_LastTaskSerial"'))
        self.assertLess(local.index('_controlReceipt isNotEqualTo _currentControl'),local.index('setVariable ["CBE_AIPass_ZeusHold"'))
if __name__=='__main__': unittest.main()
