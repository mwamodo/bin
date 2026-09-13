#!/usr/bin/env python3
"""Behavioral regression checks; all Git repositories and gh responses are fixtures."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ENTRY = Path(__file__).with_name('collect-evidence.sh')


class CollectorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='laravel-review-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.env = os.environ.copy()
        self.env.update(GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1',
                        GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
                        GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid', LC_ALL='C')
        self.git('init', '-q', '-b', 'main')

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.repo, env=self.env,
                              capture_output=True, check=True).stdout.decode().strip()

    def put(self, name, value):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value if isinstance(value, bytes) else value.encode())

    def baseline(self, files=None):
        for name, value in (files or {'app/Example.php': '<?php\n'}).items():
            self.put(name, value)
        self.git('add', '--all')
        self.git('commit', '-qm', 'baseline')
        return self.git('rev-parse', 'HEAD')

    def invoke(self, *args, success=True):
        result = subprocess.run(['/bin/bash', str(ENTRY), *args], cwd=self.repo,
                                env=self.env, capture_output=True, text=True)
        if not success:
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('ERROR:', result.stderr)
            self.assertEqual(result.stdout, '')
            return result.stderr
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout) if result.stdout else None

    def kinds(self, result):
        return {flag['kind'] for flag in result['flags']}

    def test_ordinary_added_and_removed_signals(self):
        self.baseline({'app/Example.php': "<?php\n$this->authorize('view', $record);\n"})
        self.put('app/Example.php', '<?php\nDB::raw($input);\nHttp::withoutVerifying();\n')
        result = self.invoke('uncommitted')
        self.assertTrue({'AUTHZ_REMOVED', 'RAW_SQL', 'TLS_VERIFICATION_DISABLED'} <= self.kinds(result))
        removed = next(f for f in result['flags'] if f['kind'] == 'AUTHZ_REMOVED')
        self.assertEqual((removed['side'], removed['line'], removed['layer']), ('old', 2, 'unstaged'))

    def test_empty_repository_scope(self):
        self.baseline()
        self.assertTrue(self.invoke('uncommitted')['empty'])

    def test_invalid_range_fails(self):
        self.baseline()
        self.invoke('range', 'missing-ref', 'HEAD', success=False)

    def test_invalid_commit_fails(self):
        self.baseline()
        self.invoke('commit', 'missing-ref', success=False)

    def test_unborn_staged_files_are_reviewed(self):
        self.put('app/New.php', '<?php\nHttp::withoutVerifying();\n')
        self.git('add', '--all')
        result = self.invoke('uncommitted')
        self.assertFalse(result['empty'])
        self.assertTrue(result['scope']['unborn'])
        self.assertIn('TLS_VERIFICATION_DISABLED', self.kinds(result))

    def test_partial_staging_does_not_cancel(self):
        original = "<?php\n$this->authorize('view', $record);\n"
        self.baseline({'app/Example.php': original})
        self.put('app/Example.php', '<?php\n')
        self.git('add', '--all')
        self.put('app/Example.php', original)
        result = self.invoke('uncommitted')
        self.assertEqual({r['layer'] for r in result['changes']}, {'staged', 'unstaged'})
        self.assertIn('AUTHZ_REMOVED', self.kinds(result))
        self.assertEqual({r['layer'] for r in self.invoke('staged')['changes']}, {'staged'})
        self.assertEqual({r['layer'] for r in self.invoke('unstaged')['changes']}, {'unstaged'})

    def test_sensitive_whitespace_is_preserved_without_verdict(self):
        self.baseline({'app/Example.php': "<?php\n$permission = 'manage users';\n"})
        self.put('app/Example.php', "<?php\n$permission = 'manageusers';\n")
        result = self.invoke('uncommitted')
        self.assertIn('manageusers', result['changes'][0]['patch'])
        self.assertNotIn('whitespace_only', result)
        self.assertNotIn('risk', result)

    def test_documentation_and_language_runtime_changes_are_preserved(self):
        self.baseline({'docs/deploy.sh': 'echo deploy\n', 'lang/en/messages.php': '<?php\n'})
        self.put('docs/deploy.sh', 'php artisan migrate:fresh --force\n')
        self.put('lang/en/messages.php', '<?php\nHttp::withoutVerifying();\n')
        result = self.invoke('uncommitted')
        self.assertEqual(result['path_count'], 2)
        self.assertIn('TLS_VERIFICATION_DISABLED', self.kinds(result))
        self.assertNotIn('docs_or_lang_only', result)

    def test_long_untracked_file_is_not_cut_off(self):
        self.baseline()
        self.put('app/New.php', '<?php\n' + '// padding\n' * 4000 + 'Http::withoutVerifying();\n')
        result = self.invoke('uncommitted')
        flag = next(f for f in result['flags'] if f['kind'] == 'TLS_VERIFICATION_DISABLED')
        self.assertEqual(flag['line'], 4002)

    def test_all_matching_lines_are_returned(self):
        self.baseline()
        self.put('app/Example.php', '<?php\n' + 'Http::withoutVerifying();\n' * 30)
        result = self.invoke('uncommitted')
        self.assertEqual(sum(f['kind'] == 'TLS_VERIFICATION_DISABLED' for f in result['flags']), 30)
        self.assertFalse(result['completeness']['flags_truncated'])

    def test_all_paths_are_returned(self):
        self.baseline()
        for i in range(205):
            self.put(f'app/New{i}.php', '<?php\n')
        self.assertEqual(self.invoke('uncommitted')['path_count'], 205)

    def test_untracked_binary_and_non_utf8_are_visible_gaps(self):
        self.baseline()
        self.put('public/new.bin', b'\0\1\xff')
        self.put('app/legacy.php', b'<?php\n// \xff\n')
        result = self.invoke('uncommitted')
        self.assertEqual({g['path'] for g in result['completeness']['content_gaps']},
                         {'public/new.bin', 'app/legacy.php'})

    def test_tracked_binary_is_visible_gap(self):
        self.baseline({'public/data.bin': b'\0before'})
        self.put('public/data.bin', b'\0after')
        self.assertEqual(self.invoke('uncommitted')['completeness']['content_gaps'][0]['path'], 'public/data.bin')

    def test_filenames_and_tab_indentation_round_trip(self):
        names = ['app/has space.php', 'app/has\ttab.php', 'app/has\nnewline.php', 'app/caf\u00e9.php']
        self.baseline({name: '<?php\n' for name in names})
        for name in names:
            self.put(name, '<?php\n\tHttp::withoutVerifying();\n')
        result = self.invoke('uncommitted')
        flags = [f for f in result['flags'] if f['kind'] == 'TLS_VERIFICATION_DISABLED']
        self.assertEqual({f['path'] for f in flags}, set(names))
        self.assertTrue(all(f['line'] == 2 and f['content'] == '\tHttp::withoutVerifying();' for f in flags))

    def test_untracked_quoted_path_round_trip(self):
        self.baseline()
        name = 'app/has\ttab\nnewline.php'
        self.put(name, '<?php\nHttp::withoutVerifying();\n')
        result = self.invoke('uncommitted')
        self.assertEqual(next(f for f in result['flags'] if f['kind'] == 'TLS_VERIFICATION_DISABLED')['path'], name)

    def test_root_commit(self):
        head = self.baseline({'app/Example.php': '<?php\nHttp::withoutVerifying();\n'})
        result = self.invoke('commit', head)
        self.assertEqual(result['scope']['parent_count'], 0)
        self.assertIn('TLS_VERIFICATION_DISABLED', self.kinds(result))

    def test_single_commit_ignores_newer_and_dirty_work(self):
        base = self.baseline()
        self.put('app/Example.php', '<?php\nHttp::withoutVerifying();\n')
        self.git('add', '--all'); self.git('commit', '-qm', 'review target')
        target = self.git('rev-parse', 'HEAD')
        self.put('app/Example.php', '<?php\n')
        self.git('add', '--all'); self.git('commit', '-qm', 'later change')
        self.put('app/New.php', '<?php\nDB::raw($unrelated);\n')
        result = self.invoke('commit', target)
        self.assertEqual((result['scope']['base'], result['scope']['head']), (base, target))
        self.assertIn('TLS_VERIFICATION_DISABLED', self.kinds(result))
        self.assertNotIn('RAW_SQL', self.kinds(result))

    def branches(self):
        base = self.baseline()
        self.git('checkout', '-qb', 'feature')
        self.put('app/Example.php', '<?php\nHttp::withoutVerifying();\n')
        self.git('add', '--all'); self.git('commit', '-qm', 'feature')
        head = self.git('rev-parse', 'HEAD')
        self.git('checkout', '-q', 'main')
        self.put('app/BaseOnly.php', '<?php\nDB::raw($unrelated);\n')
        self.git('add', '--all'); self.git('commit', '-qm', 'base drift')
        return base, head

    def test_branch_uses_merge_base(self):
        base, head = self.branches()
        self.git('checkout', '-q', 'feature')
        result = self.invoke('branch', 'main')
        self.assertEqual((result['scope']['base'], result['scope']['head']), (base, head))
        self.assertNotIn('RAW_SQL', self.kinds(result))

    def test_since_and_explicit_range(self):
        base = self.baseline()
        for name in ['app/One.php', 'app/Two.php']:
            self.put(name, '<?php\n')
            self.git('add', '--all'); self.git('commit', '-qm', name)
        head = self.git('rev-parse', 'HEAD')
        self.assertEqual(self.invoke('since', base)['path_count'], 2)
        self.assertEqual(self.invoke('commit', head)['path_count'], 1)
        self.assertEqual(self.invoke('range', base, head)['path_count'], 2)

    def mock_pr(self, head):
        metadata = {'number': 42, 'url': 'https://github.com/fixture/repo/pull/42',
                    'baseRefName': 'main', 'baseRefOid': self.git('rev-parse', 'main'),
                    'headRefName': 'feature', 'headRefOid': head}
        self.metadata = self.root / 'pr.json'
        self.metadata.write_text(json.dumps(metadata))
        api = self.root / 'pr-api.json'
        api.write_text(json.dumps({'number': 42, 'html_url': metadata['url'],
                                   'base': {'ref': 'main', 'sha': metadata['baseRefOid']},
                                   'head': {'ref': 'feature', 'sha': head}}))
        self.api_metadata = api
        bin_dir = self.root / 'bin'; bin_dir.mkdir()
        gh = bin_dir / 'gh'
        gh.write_text('''#!/bin/sh
if [ "$1" = api ]; then
    cat "$FIXTURE_PR_API"
else
    case "$*" in *baseRefOid*) echo 'unsupported pr view field' >&2; exit 1 ;; esac
    cat "$FIXTURE_PR_METADATA"
fi
''')
        gh.chmod(0o755)
        self.env['PATH'] = str(bin_dir) + os.pathsep + self.env['PATH']
        self.env['FIXTURE_PR_METADATA'] = str(self.metadata)
        self.env['FIXTURE_PR_API'] = str(api)

    def test_pr_uses_actual_head_on_unrelated_checkout(self):
        base, head = self.branches()
        self.mock_pr(head)
        result = self.invoke('pr', '42')
        self.assertEqual((result['scope']['base'], result['scope']['head']), (base, head))
        self.assertIn('TLS_VERIFICATION_DISABLED', self.kinds(result))
        self.assertNotIn('RAW_SQL', self.kinds(result))
        self.assertEqual(self.git('branch', '--show-current'), 'main')

    def test_missing_pr_objects_fail_without_fallback(self):
        self.baseline()
        self.mock_pr('f' * 40)
        self.assertIn('Do not substitute', self.invoke('pr', '42', success=False))

    def test_snapshot_verification_detects_working_change(self):
        self.baseline()
        self.put('app/Example.php', '<?php\n// first\n')
        evidence = str(self.root / 'evidence.json')
        self.invoke('uncommitted', '--output', evidence)
        self.assertTrue(self.invoke('verify', evidence)['verified'])
        self.put('app/Example.php', '<?php\n// second\n')
        self.assertIn('snapshot changed', self.invoke('verify', evidence, success=False))

    def test_snapshot_verification_detects_pr_change(self):
        _, head = self.branches(); self.mock_pr(head)
        evidence = str(self.root / 'evidence.json')
        self.invoke('pr', '42', '--output', evidence)
        meta = json.loads(self.api_metadata.read_text()); meta['head']['sha'] = meta['base']['sha']
        self.api_metadata.write_text(json.dumps(meta))
        self.assertIn('snapshot changed', self.invoke('verify', evidence, success=False))

    def test_output_cannot_change_reviewed_repository(self):
        self.baseline()
        self.invoke('uncommitted', '--output', str(self.repo / 'evidence.json'), success=False)
        self.assertFalse((self.repo / 'evidence.json').exists())

    def test_lockfile_is_reviewable_dependency_evidence(self):
        self.baseline({'composer.lock': '{"packages": []}\n'})
        self.put('composer.lock', '{"packages": [{"name":"fixture/package","version":"1.0"}]}\n')
        result = self.invoke('uncommitted')
        self.assertTrue(result['changes'][0]['dependency_lockfile'])
        self.assertFalse(result['changes'][0]['requires_content_inspection'])
        self.assertIn('DEPENDENCIES_CHANGED', self.kinds(result))

    def test_empty_untracked_file_is_in_inventory(self):
        self.baseline(); self.put('app/Empty.php', '')
        self.assertEqual(self.invoke('uncommitted')['path_count'], 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
