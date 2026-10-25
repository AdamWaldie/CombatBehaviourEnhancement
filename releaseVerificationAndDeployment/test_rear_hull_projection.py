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
            # Passing projects onto an arbitrary peer heading, rather than one
            # model axis. Compare that scalar interval to all eight world corners.
            direction=[rng.uniform(-1,1) for _ in range(3)]
            scalar_matrix=[[sum(direction[k]*matrix[k][j] for k in range(3)) for j in range(3)],
                           [0,0,0],[0,0,0]]
            scalar_offset=[sum(direction[k]*offset[k] for k in range(3)),0,0]
            scalar=edge_bounds(low,high,scalar_matrix,scalar_offset)
            corners=[transform(p,matrix,offset) for p in product(*zip(low,high))]
            projected=[sum(direction[k]*p[k] for k in range(3)) for p in corners]
            self.assertAlmostEqual(scalar[0][0],min(projected),places=7)
            self.assertAlmostEqual(scalar[1][0],max(projected),places=7)
            self.assertLessEqual(scalar[0][0]-0.05,min(projected))
            self.assertGreaterEqual(scalar[1][0]+0.05,max(projected))

    def test_native_integration_uses_four_transform_pairs_and_preserves_prediction(self):
        source=(ROOT/'addons/vehicles/functions/drivingRearClear.sqf').read_text()
        block=source.split('private _origin=',1)[1].split('private _current=',1)[0]
        self.assertEqual(block.count('worldToModel'),2)
        self.assertEqual(block.count('modelToWorld'),2)
        self.assertIn('[_otherHigh select 0,_otherLow select 1,_otherLow select 2]',block)
        self.assertIn('[_otherLow select 0,_otherHigh select 1,_otherLow select 2]',block)
        self.assertIn('[_otherLow select 0,_otherLow select 1,_otherHigh select 2]',block)
        for guard in ('_minZ <= (_high select 2)+0.3','_maxZ >= (_low select 2)-0.3','private _entry=0;private _exit=_seconds'):
            self.assertIn(guard,source)

    def test_traffic_uses_the_same_full_hull_identity_without_weakening_admission(self):
        source=(ROOT/'addons/vehicles/functions/drivingFollowingCap.sqf').read_text(encoding='utf-8')
        block=source.split('private _projectTrafficHull={',1)[1].split('private _ownHull=',1)[0]
        self.assertNotIn('worldToModel',block)
        self.assertEqual(block.count('modelToWorldWorld'),2)
        for endpoint in ('[_hullHigh select 0,_hullLow select 1,_hullLow select 2]',
                         '[_hullLow select 0,_hullHigh select 1,_hullLow select 2]',
                         '[_hullLow select 0,_hullLow select 1,_hullHigh select 2]'):
            self.assertIn(endpoint,block)
        self.assertIn('_corner vectorDotProduct _right,_corner vectorDotProduct _forward,_corner select 2',block)
        self.assertIn('_edge vectorDotProduct _right,_edge vectorDotProduct _forward,_edge select 2',block)
        self.assertIn('[_vehicle,_modelLow,_modelHigh] call _projectTrafficHull',source)
        self.assertIn('[_other,_otherLow,_otherHigh] call _projectTrafficHull',source)
        for axis in range(3):
            self.assertIn(f'(_projectedLow select {axis})-0.05',source)
            self.assertIn(f'(_projectedHigh select {axis})+0.05',source)
        for guard in ('count _candidates > 64','_sameHeight','_sameLane',
                      'if (_ahead && {_sameLane} && {_sameHeight})',
                      'if (_sameHeight && {_otherSpeed > 0.8})',
                      '_area nearEntities [["LandVehicle"],false,false,false]'):
            self.assertIn(guard,source)

if __name__=='__main__': unittest.main()
