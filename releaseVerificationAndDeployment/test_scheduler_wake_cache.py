"""Cache invariant regressions; not SQF runtime or performance acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class SchedulerWakeCacheTests(unittest.TestCase):
    @staticmethod
    def cache(earliest, raised):
        return raised if raised >= 0 and (earliest < 0 or raised < earliest) else earliest

    def test_later_callback_wakes_previously_skipped_job(self):
        # Job A was sampled at 100; job B runs at 10 and coalesces A to 10.
        # The row remains in the queue with wakeAt=10; only the idle cache was lost.
        self.assertEqual(self.cache(100,10),10)
        self.assertNotEqual(self.cache(100,10),100)

    def test_ordinary_future_cache_does_not_inherit_previous_due_frame(self):
        self.assertEqual(self.cache(100,-1),100)
        self.assertEqual(self.cache(-1,-1),-1)
        self.assertEqual(self.cache(20,30),20)
        self.assertEqual(self.cache(-1,10),10)

    def test_tick_separates_old_cache_and_merges_callback_requests(self):
        source=(ROOT/'addons/core/functions/cortexSchedulerTick.sqf').read_text()
        reset=source.index('missionNamespace setVariable ["WAIT_AIPass_NextJobDue", -1];',
                           source.index('if (_jobs isEqualTo []) exitWith'))
        # First match is the empty-queue branch; reset again before processing.
        reset=source.index('missionNamespace setVariable ["WAIT_AIPass_NextJobDue", -1];',reset+1)
        traversal=source.index('} forEach _jobs;')
        merge=source.index('private _raisedDue=')
        final=source.index('missionNamespace setVariable ["WAIT_AIPass_NextJobDue", _earliest];',merge)
        self.assertLess(reset,source.index('private _start = diag_tickTime;'))
        self.assertLess(traversal,merge)
        self.assertLess(merge,final)
        self.assertIn('_raisedDue < _earliest',source)
        self.assertIn('_next append _rescheduled;',source)

if __name__ == '__main__': unittest.main()
