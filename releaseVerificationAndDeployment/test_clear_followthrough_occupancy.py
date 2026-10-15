"""Follow-through destination selection must prefer available space over floor proximity."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class FollowThroughOccupancyTests(unittest.TestCase):
    def test_free_other_floor_precedes_blocked_current_floor(self):
        candidates = [(1, 0, 2.0, 3), (0, 1, 7.0, 5)]
        self.assertEqual(min(candidates)[3], 5)
        candidates += [(0, 0, 9.0, 2)]
        self.assertEqual(min(candidates)[3], 2)
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        rank = source.split('private _ranked=_candidates apply {', 1)[1]
        # Locate the follow-through ranking by its unique reservation snapshot.
        rank = source.split('private _occupied=_followReservations findIf {', 1)[1].split('_ranked sort true;', 1)[0]
        self.assertLess(rank.index('[[0,1] select _occupied'), rank.index('[0,1] select (abs (_unitFloor'))
        self.assertIn('vectorDistance _positionASL < 1.5', rank)

if __name__ == '__main__':
    unittest.main()
