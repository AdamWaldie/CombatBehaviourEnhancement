"""Negotiated roles must not acquire overlapping queue and passing consent."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name): return (ROOT/'addons/vehicles/functions'/name).read_text(encoding='utf-8')
class QueuePassExclusion(unittest.TestCase):
    def test_default_passing_admission_refuses_live_or_unknown_queue_consent(self):
        text=source('drivingPassCanConsent.sqf')
        for proof in ('["_protocol","PASS"','_protocol in ["PASS","QUEUE"]',
                      'CBE_DrivingQueue_Consent','_phase in ["PENDING","AGREED"]',
                      '["deadline","expires"]','serverTime < _until',
                      '_queue isEqualType createHashMap','finite _until','_until < 0','_token == ""'):
            self.assertIn(proof,text)
        self.assertLess(text.index('_protocol == "BUSY"'),text.index('private _driver='))
        for forbidden in ('setVariable','forceSpeed','doMove','doStop','spawn'):
            self.assertNotIn(forbidden,text)
    def test_queue_bypasses_only_its_own_marker_and_still_refuses_passing(self):
        text=source('drivingQueueProposalCurrent.sqf')
        self.assertIn('[_vehicle,"QUEUE"] call CBE_fnc_DrivingPassCanConsent',text)
        self.assertIn('CBE_DrivingPass_Consent',text)
        self.assertIn('|| {_passBusy}',text)
        for caller in ('drivingPassAdmission.sqf','drivingPassAgreementOwner.sqf',
                       'drivingPassBegin.sqf','drivingPassPrepare.sqf'):
            self.assertNotIn(',"QUEUE"] call CBE_fnc_DrivingPassCanConsent',source(caller))
if __name__=='__main__': unittest.main()
