"""Bounded callback history and retired-work attribution contracts, not perf acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class SchedulerSampleTests(unittest.TestCase):
    def test_ring_retains_latest_terminal_work_with_fixed_capacity(self):
        ring=[];cursor=0
        for value in range(1000):
            if cursor==len(ring):ring.append(value)
            else:ring[cursor]=value
            cursor=(cursor+1)%256
            self.assertLessEqual(len(ring),256)
        self.assertEqual(set(ring),set(range(744,1000)))
        self.assertEqual(cursor,1000%256)
    def test_recording_precedes_job_retirement_and_excludes_skips(self):
        s=(ROOT/'addons/core/functions/cortexSchedulerTick.sqf').read_text(encoding='utf-8')
        recording=s.split('if (!_stale && {!_jobPaused}) then {',1)[1].split('_state set ["lastRunAt"',1)[0]
        self.assertIn('(_cursor+1) mod 256',recording)
        self.assertIn('select [0,160]',recording)
        for forbidden in ('sort ','spawn','remoteExec','nearEntities','allGroups'):
            self.assertNotIn(forbidden,recording)
        self.assertLess(s.index('"CBE_AIPass_CallbackSamples",_samples'),s.index('if (!isNil "_delay"'))
    def test_invalid_delay_notifies_waiting_fsm_instead_of_silent_drop(self):
        import math
        tick=(ROOT/'addons/core/functions/cortexSchedulerTick.sqf').read_text(encoding='utf-8')
        queue=(ROOT/'addons/core/functions/cortexQueueJob.sqf').read_text(encoding='utf-8')
        rejection=tick.split('private _rejectDelay={',1)[1].split('};\n{',1)[0]
        for marker in ('["cancelled",true]','["cancelReason","INVALID_JOB_DELAY"]',
                       '["pending",false]','["completed",true]'):
            self.assertIn(marker,rejection)
        self.assertIn('!finite _delay',tick)
        self.assertIn('if (finite _rescheduledAt) then {',tick)
        self.assertIn('!finite (time + (_delay max 0))',queue)
        self.assertLess(queue.index('"INVALID_JOB_DELAY"'),queue.index('_state set ["ownerEpoch"'))
        self.assertIn('[] call _rejectFiniteBrain',queue)
        # The old scheduler discarded nil/non-number returns without notifying its brain.
        old={'pending':True,'completed':False,'cancelled':False}
        self.assertTrue(old['pending'])
        for delay in (None,'invalid',float('nan'),float('inf')):
            state=dict(old)
            if not isinstance(delay,(int,float)) or not math.isfinite(delay):
                state.update(pending=False,completed=True,cancelled=True)
            self.assertFalse(state['pending'])
            self.assertTrue(state['cancelled'])
        for delay in (-1,0,0.25,5):
            self.assertTrue(math.isfinite(delay))  # Ordinary terminal and retry contract retained.
        for forbidden in ('doMove','doFollow','enableAttack','setUnitPos','remoteExec'):
            self.assertNotIn(forbidden,rejection)

    def test_report_is_on_demand_and_does_not_claim_frame_budget_acceptance(self):
        s=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertIn('"cortex-callback-samples"',s)
        self.assertIn('["NOT_SAMPLED","MEASURED"]',s)
        self.assertIn('_ranked select [0,8]',s)
        self.assertIn('not matched frame-time overhead',s)
        self.assertIn('ceil (_sampleCount*0.95)-1',s)
    def test_distributed_sampler_reads_retired_callback_ring_in_matching_clock_window(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runPerformanceOwner.sqf').read_text(encoding='utf-8')
        sample=s.split('while {diag_tickTime < _until',1)[1].split('sleep 1;',1)[0]
        self.assertIn('CBE_AIPass_CallbackSamples', sample)
        self.assertIn('(_completed select [0,256])', sample)
        self.assertIn('(_x select 4) >= _sampleStartedTick', sample)
        self.assertIn('(_x select 4) <= _observedAt', sample)
        self.assertNotIn('lastRunAt', sample)
        self.assertIn('private _sampleStartedTick=diag_tickTime;', s)
        self.assertIn('overwritten between samples', s)

class SchedulerExecutionContextTests(unittest.TestCase):
    def test_context_is_observed_and_old_samples_remain_unknown(self):
        tick=(ROOT/'addons/core/functions/cortexSchedulerTick.sqf').read_text()
        self.assertIn('private _callbackCanSuspend=canSuspend;',tick)
        self.assertIn('_callbackMs,_queueLatency,_callbackStarted,_callbackCanSuspend',tick)
        self.assertIn('"lastCallbackCanSuspend",_callbackCanSuspend',tick)
        report=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        self.assertIn('(_x select 5) isEqualTo true',report)
        self.assertIn('(_x select 5) isEqualTo false',report)
        self.assertIn('_sampleCount-_scheduledSamples-_unscheduledSamples',report)
        reconcile=(ROOT/'addons/core/functions/schedulerReconcile.sqf').read_text()
        self.assertIn('CBA_fnc_addPerFrameHandler',reconcile)
        self.assertIn('{[_state] call _job}',tick)

class DistributedCallbackSchemaTests(unittest.TestCase):
    def test_owner_sampler_keeps_both_ring_schemas_and_unknown_absence(self):
        source=(ROOT/'releaseVerificationAndDeployment/cortexQA/runPerformanceOwner.sqf').read_text()
        sample=source.split('private _completed=',1)[1].split('sleep 1;',1)[0]
        self.assertIn('count _x in [5,6]',sample)
        self.assertIn('!finite _x',sample)
        self.assertIn('(_x select 5) isEqualType true',sample)
        self.assertIn('_sawUnknownContext=true',sample)
        self.assertIn('private _maxCallbackMs=-1;',source)
        self.assertIn('private _maxCompletedLatency=-1;',source)
        self.assertIn('[_sawUnscheduled,_sawScheduled,_sawUnknownContext]',source)
        self.assertIn('(_x select 4) >= _sampleStartedTick',sample)
        self.assertIn('(_x select 4) <= _observedAt',sample)

if __name__=='__main__':unittest.main()
