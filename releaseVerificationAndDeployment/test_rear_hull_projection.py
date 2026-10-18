"""Analytic full-hull bounds versus an independent eight-corner affine oracle.

This verifies the geometry identity, not Arma native precision or runtime overhead.
"""
from itertools import product
from pathlib import Path
import random
import unittest

ROOT=Path(__file__).resolve().parents[1]

def transform(point,matrix,offset):
    return [sum(row[j]*point[j] for j in range(3))+offset[i] for i,row in enumerate(matrix)]

def corner_oracle(low,high,matrix,offset):
    corners=[transform(p,matrix,offset) for p in product(*zip(low,high))]
    return [min(p[i] for p in corners) for i in range(3)],[max(p[i] for p in corners) for i in range(3)]

def edge_bounds(low,high,matrix,offset):
    origin=transform(low,matrix,offset)
    lower=origin.copy();upper=origin.copy()
    for dimension in range(3):
        endpoint=low.copy();endpoint[dimension]=high[dimension]
        moved=transform(endpoint,matrix,offset)
        for axis in range(3):
            delta=moved[axis]-origin[axis]
            lower[axis]+=min(delta,0)
            upper[axis]+=max(delta,0)
    return lower,upper

class RearHullProjectionTests(unittest.TestCase):
    def test_full_extents_match_corners_for_tilt_scale_and_asymmetric_boxes(self):
        rng=random.Random(20261018)
        matrices=[[[1,0,0],[0,1,0],[0,0,1]],[[0,0,2],[0.5,0,0],[0,3,0]]]
        matrices += [[[rng.uniform(-4,4) for _ in range(3)] for _ in range(3)] for _ in range(300)]
        for matrix in matrices:
            low=[rng.uniform(-20,0) for _ in range(3)]
            high=[rng.uniform(0,20) for _ in range(3)]
            offset=[rng.uniform(-100000,100000) for _ in range(3)]
            expected=corner_oracle(low,high,matrix,offset)
            actual=edge_bounds(low,high,matrix,offset)
            for boundary in range(2):
                for axis in range(3):
                    self.assertAlmostEqual(actual[boundary][axis],expected[boundary][axis],places=7)
                    self.assertLessEqual(actual[0][axis]-0.05,expected[0][axis])
                    self.assertGreaterEqual(actual[1][axis]+0.05,expected[1][axis])

    def test_native_integration_uses_four_transform_pairs_and_preserves_prediction(self):
        source=(ROOT/'addons/vehicles/functions/drivingRearClear.sqf').read_text()
        block=source.split('private _origin=',1)[1].split('private _current=',1)[0]
        self.assertEqual(block.count('worldToModel'),2)
        self.assertEqual(block.count('modelToWorld'),2)
        self.assertIn('[_otherHigh select 0,_otherLow select 1,_otherLow select 2]',block)
        self.assertIn('[_otherLow select 0,_otherHigh select 1,_otherLow select 2]',block)
        self.assertIn('[_otherLow select 0,_otherLow select 1,_otherHigh select 2]',block)
        for guard in ('_minZ <= (_high select 2)+0.3','_maxZ >= (_low select 2)-0.3','private _entry=0;private _exit=_predictionSeconds'):
            self.assertIn(guard,source)

if __name__=='__main__': unittest.main()
