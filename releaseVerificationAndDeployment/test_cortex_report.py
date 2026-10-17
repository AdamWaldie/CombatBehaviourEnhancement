import unittest
from report_cortex_audit import summarize, render_markdown, staged_mission_path
from pathlib import Path
import tempfile

class CortexReportTests(unittest.TestCase):
    SOURCE = 'CBE CORTEX QA SOURCE|fingerprint=' + ('a' * 64) + '\n'

    def test_provenance_uses_actual_world_and_rejects_missing_or_unsafe_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for world in ('VR', 'Altis'):
                mission = root / ('CBE_Audit.' + world)
                mission.mkdir()
                self.assertEqual(mission, staged_mission_path(root, {'world': world}))
            self.assertEqual(root / 'CBE_Audit.VR', staged_mission_path(root, {}))
            for world in ('../outside', 'Malden', None):
                with self.assertRaises(ValueError):
                    staged_mission_path(root, {'world': world})
            (root / 'CBE_Audit.Altis').rmdir()
            with self.assertRaises(ValueError):
                staged_mission_path(root, {'world': 'Altis'})

    def test_pass_requires_both_completion_markers(self):
        text=self.SOURCE+'CBE CORTEX QA|case|PASS|\nCBE CORTEX QA SERVER COMPLETE: 0 finding(s) []'
        self.assertEqual('INCOMPLETE', summarize({'server.rpt':text})['status'])
        self.assertEqual('PASS', summarize({'server.rpt':text,'client.rpt':self.SOURCE+'CBE CORTEX QA CLIENT COMPLETE: 0 finding(s) []'})['status'])
    def test_later_pass_cannot_hide_failure(self):
        self.assertEqual('FAIL',summarize({'x.rpt':'CBE CORTEX QA|case|FAIL|\nCBE CORTEX QA|case|PASS|'})['status'])
    def test_sqf_error_overrides_clean_summaries(self):
        text='CBE CORTEX QA|case|PASS|\nCBE CORTEX QA SERVER COMPLETE: 0 finding(s) []\nCBE CORTEX QA CLIENT COMPLETE: 0 finding(s) []\nError in expression <test>'
        self.assertEqual('FAIL',summarize({'x.rpt':text})['status'])
    def test_empty_run_is_incomplete(self):
        self.assertEqual('INCOMPLETE',summarize({})['status'])

    def test_missing_script_is_load_failure_with_or_without_warning_prefix(self):
        for prefix in ['', 'Warning Message: ']:
            with self.subTest(prefix=prefix):
                message=prefix+'Script compatibilityHeadlessProvider/init.sqf not found'
                report=summarize({'client.rpt':message})
                self.assertEqual('FAIL',report['status'])
                self.assertEqual(1,len(report['load_errors']))
                self.assertEqual(message,report['load_errors'][0]['message'])

    def test_standalone_parameter_and_arithmetic_errors_fail_without_trace_prefix(self):
        for error in ['Error Params: Type String, expected Number',
                      'Error Type Array, expected Number', 'Error Generic error in expression',
                      'Error Zero divisor']:
            with self.subTest(error=error):
                report=summarize({'client.rpt':error})
                self.assertEqual('FAIL',report['status'])
                self.assertEqual(1,len(report['errors']))
                self.assertEqual(error,report['errors'][0]['message'])

    def test_device_hung_is_a_bounded_fatal_failure(self):
        report=summarize({'client.rpt':'\n'.join([
            'DX11 - device removed - reason: DXGI_ERROR_DEVICE_HUNG',
            'DX11 - device removed - reason: DXGI_ERROR_DEVICE_HUNG',
            'ErrorMessage: DX11 error : buffer Map failed : DXGI_ERROR_DEVICE_REMOVED',
        ])})
        self.assertEqual('FAIL',report['status'])
        self.assertFalse(report['complete'])
        self.assertEqual(2,len(report['runtime_errors']))
        rendered='\n'.join(render_markdown(report))
        self.assertIn('Fatal runtime failures:',rendered)
        self.assertIn('DXGI_ERROR_DEVICE_HUNG',rendered)

    def test_fatal_exception_without_completion_cannot_be_incomplete(self):
        report=summarize({'client.rpt':'Exception code: 0000DEAD'})
        self.assertEqual('FAIL',report['status'])
        self.assertEqual(1,len(report['runtime_errors']))

    def test_fsm_load_failure_is_an_explicit_blocker(self):
        report=summarize({'client.rpt':"Warning Message: FSM 'z\\cbe\\addons\\danger\\danger.fsm' cannot be loaded."})
        self.assertEqual('FAIL',report['status'])
        self.assertEqual(1,len(report['load_errors']))
        rendered='\n'.join(render_markdown(report))
        self.assertIn('Addon or FSM load failures:',rendered)
        self.assertIn('danger.fsm',rendered)

    def test_missing_required_addon_is_an_explicit_blocker(self):
        report=summarize({'server.rpt':'Warning Message: You cannot play/edit this mission; it is dependent on downloadable content that has been deleted.\\na3_characters_f'})
        self.assertEqual('FAIL',report['status'])
        self.assertEqual(1,len(report['load_errors']))

    def test_failure_does_not_imply_completion_and_details_are_visible(self):
        report=summarize({'server.rpt':'CBE CORTEX QA|arrival|FAIL|remaining=63 m | allowed=50 m\nCBE CORTEX QA SERVER COMPLETE: 1 finding(s) []'})
        self.assertEqual('FAIL',report['status'])
        self.assertFalse(report['complete'])
        self.assertEqual(['CLIENT'],report['missing_completion'])
        rendered='\n'.join(render_markdown(report))
        self.assertIn('Run complete: **no**',rendered)
        self.assertIn('remaining=63 m \\| allowed=50 m',rendered)

    def test_failure_summary_precedes_passing_check_table(self):
        report=summarize({'server.rpt':'CBE CORTEX QA|arrival|FAIL|remaining=20 m\nCBE CORTEX QA|firing|PASS|shots=4'})
        rendered='\n'.join(render_markdown(report))
        self.assertIn('Recorded checks: 2; failed checks: 1', rendered)
        self.assertLess(rendered.index('**arrival**'), rendered.index('| Case |'))
        self.assertIn('remaining=20 m', rendered)

    def test_evidence_without_source_fingerprint_fails(self):
        report=summarize({'server.rpt':'CBE CORTEX QA|case|PASS|\nCBE CORTEX QA SERVER COMPLETE: 0 finding(s) []'})
        self.assertEqual('FAIL',report['status'])
        self.assertIn('server.rpt',report['provenance_issues'][0])
        self.assertIn('Source provenance failures:', '\n'.join(render_markdown(report)))

    def test_conflicting_source_fingerprints_fail(self):
        other='CBE CORTEX QA SOURCE|fingerprint='+('b'*64)+'\n'
        report=summarize({
            'server.rpt':self.SOURCE+'CBE CORTEX QA|case|PASS|\nCBE CORTEX QA SERVER COMPLETE: 0 finding(s) []',
            'client.rpt':other+'CBE CORTEX QA CLIENT COMPLETE: 0 finding(s) []',
        })
        self.assertEqual('FAIL',report['status'])
        self.assertIsNone(report['source_fingerprint'])
        self.assertIn('Conflicting staged-source fingerprints',report['provenance_issues'][0])

    def test_matching_source_fingerprint_is_reported(self):
        report=summarize({'server.rpt':self.SOURCE+'CBE CORTEX QA|case|PASS|'})
        self.assertEqual('a'*64,report['source_fingerprint'])
        self.assertEqual([],report['provenance_issues'])
        self.assertIn('`'+('a'*64)+'`','\n'.join(render_markdown(report)))

    def test_documented_character_warning_requires_positive_same_process_runtime_evidence(self):
        warning=r'18:00:00 Warning Message: You cannot play/edit this mission; it is dependent on downloadable content that has been deleted.\na3_characters_f'
        present='CBE AUDIT DEPENDENCIES|owner=2|patches=[[""A3_Characters_F"",true]]|observerClass=true\n'
        activated='CBE AUDIT ADDON ACTIVATION|owner=2|patches=[[""A3_Characters_F"",true]]\n'
        ready='CBE AUDIT OBSERVER ZEUS READY\n'
        done='CBE CORTEX QA|case|PASS|\nCBE CORTEX QA SERVER COMPLETE: 0 finding(s) []\nCBE CORTEX QA CLIENT COMPLETE: 0 finding(s) []'
        report=summarize({'server.rpt':self.SOURCE+warning+'\n'+present+activated+ready+done})
        self.assertEqual('PASS',report['status'])
        self.assertEqual([],report['load_errors'])
        self.assertEqual(warning,report['known_engine_warnings'][0]['message'])
        self.assertIn('Known engine warnings', '\n'.join(render_markdown(report)))
        for evidence in [present+ready,activated+ready,present+activated]:
            with self.subTest(evidence=evidence):
                report=summarize({'server.rpt':self.SOURCE+warning+'\n'+evidence+done})
                self.assertEqual('FAIL',report['status'])
                self.assertEqual([],report['known_engine_warnings'])
        report=summarize({'server.rpt':warning,'client.rpt':present+activated+ready})
        self.assertEqual('FAIL',report['status'])
        self.assertEqual([],report['known_engine_warnings'])

    def test_character_warning_exception_cannot_hide_other_addons_or_real_failures(self):
        evidence='CBE AUDIT DEPENDENCIES|patches=[["A3_Characters_F",true]]|observerClass=true\nCBE AUDIT ADDON ACTIVATION|patches=[["A3_Characters_F",true]]\nCBE AUDIT OBSERVER ZEUS READY\n'
        prefix=r'Warning Message: You cannot play/edit this mission; it is dependent on downloadable content that has been deleted.\n'
        for addon in ['other_addon','a3_characters_f,other_addon','a3_characters_f other_addon']:
            report=summarize({'server.rpt':evidence+prefix+addon})
            self.assertEqual('FAIL',report['status'])
            self.assertEqual(1,len(report['load_errors']))
            self.assertEqual([],report['known_engine_warnings'])
        report=summarize({'server.rpt':evidence+prefix+'a3_characters_f\nCBE CORTEX QA|case|FAIL|'})
        self.assertEqual('FAIL',report['status'])
        self.assertEqual(1,len(report['known_engine_warnings']))
