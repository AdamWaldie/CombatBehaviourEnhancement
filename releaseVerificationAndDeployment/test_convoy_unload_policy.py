"""Convoy unload ownership regressions; no engine or migration acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(name):return (ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class ConvoyUnloadPolicyTests(unittest.TestCase):
    def test_all_convoy_writers_use_the_exact_lease(self):
        for name in ('convoyTick','convoyCrewLocal','convoyReleaseLocal'):
            s=src(name)
            self.assertIn('call CBE_fnc_ConvoyUnloadPolicy',s)
            self.assertNotIn('setUnloadInCombat',s)
        s=src('convoyReleaseLocal')
        self.assertIn('if !(_vehicle in _keepCrew) then {',s)
        self.assertIn('"RELEASE",-1,_restoreUnload',s)
    def test_external_mutation_blocks_even_across_revision_and_owner_changes(self):
        s=src('convoyUnloadPolicy')
        mutation=s.split('if (count _lease == 5 && {getUnloadInCombat',1)[1].split('if (count _lease == 5) then',1)[0]
        self.assertIn('CBE_Convoy_UnloadPolicyLease",nil,true',mutation)
        self.assertIn('CBE_Convoy_UnloadPolicyBlocked",_group,true',mutation)
        self.assertNotIn('setUnloadInCombat',mutation)
        self.assertIn('if (_blocked == _group) exitWith {false}',s)
        self.assertNotIn('_blocked == [_group,_revision]',s)
        adoption=s.split('if (count _lease == 5) then {',1)[1].split('} else {',1)[0]
        self.assertIn('_lease set [1,_revision]',adoption)
        self.assertIn('_lease set [4,clientOwner]',adoption)
        self.assertNotIn('setUnloadInCombat',adoption)
    def test_restore_requires_exact_lease_and_current_applied_value(self):
        s=src('convoyUnloadPolicy')
        release=s.split('if (_action == "RELEASE") exitWith {',1)[1].split('if (_action != "ACQUIRE"',1)[0]
        self.assertIn('count _lease == 5 && {(_lease select 0) == _group}',release)
        self.assertIn('if (_ours) then {',release)
        self.assertIn('_restore && {getUnloadInCombat _vehicle isEqualTo _applied}',release)
        self.assertIn('_vehicle setUnloadInCombat _previous',release)
        self.assertIn('if (_blocked == _group)',release)
    def test_admission_is_current_registered_and_bounded(self):
        s=src('convoyUnloadPolicy')
        for marker in ('local _vehicle','remoteExecutedOwner != 2','CBE_Convoy_Revision',
                       'CBE_Convoy_Group','CBE_Convoy_Active','CortexExternalTakeover',
                       '(_lease select 1) > _revision','group _operator != _group'):
            self.assertIn(marker,s)
        executable=s.split('params [[',1)[1]
        for forbidden in ('spawn','while {','waitUntil','addEventHandler','moveIn','allVehicles'):
            self.assertNotIn(forbidden,executable)
    def test_shared_passenger_motion_guard_preserves_task_and_seat_checks(self):
        passenger=src('cortexPassengerReady')
        for marker in ('vectorMagnitude velocity _vehicle','vectorMagnitude angularVelocity _vehicle',
                       '!finite _linearMotion','!finite _angularMotion','_linearMotion >= (1/3.6)',
                       '_angularMotion >= 0.01','CBE_Cortex_ActorMove','currentCommand _unit',
                       'assignedVehicle _unit != _vehicle','fullCrew'):
            self.assertIn(marker,passenger)
        self.assertNotIn('abs speed _vehicle',passenger)
        for command in ('doGetOut','unassignVehicle','moveInCargo','setPos','setVelocity'):
            self.assertNotIn(command,passenger)
    def test_unload_commit_uses_live_snapshot_and_allows_authoritative_slices(self):
        text=src('convoyCrewLocal')
        helper=text.split('private _haltCurrent={',1)[1].split('};\n{',1)[0]
        for marker in ('CBE_Convoy_LocalRegistry','_live select [0,4]','_configuration select [0,4]',
                       '_live select [7]','_configuration select [7]','== "HALT"',
                       '_transport in (_live select 4)','_live select 6','isEqualTo _passenger'):
            self.assertIn(marker,helper)
        commit=text.split('// Scheduled direct callers must not separate snapshot/task proof',1)[1].split('} forEach _cargo;',1)[0]
        self.assertLess(commit.index('isNil {'),commit.index('call _haltCurrent'))
        self.assertLess(commit.index('call _haltCurrent'),commit.index('CortexPassengerReady'))
        for command in ('orderGetIn false','unassignVehicle _unit','doGetOut _unit'):
            self.assertLess(commit.index('CortexPassengerReady'),commit.index(command))
        self.assertNotIn('_live isEqualTo _configuration',helper)
if __name__=='__main__':unittest.main()
