#!/usr/bin/env python3
"""Read-only Git evidence collector. JSON facts, never risk scores or verdicts."""

import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlparse


class CollectionError(Exception):
    pass


def run(argv, cwd=None, data=None):
    try:
        result = subprocess.run(argv, cwd=cwd, input=data, capture_output=True)
    except OSError as exc:
        raise CollectionError(str(exc)) from exc
    if result.returncode:
        detail = result.stderr.decode('utf-8', 'replace').strip()
        raise CollectionError(f'{argv[0]} failed ({result.returncode}): {detail}')
    return result.stdout


def git(repo, *args, data=None):
    return run(['git', '--no-pager', '-c', 'core.quotePath=true', *args], repo, data)


def decode(value):
    return value.decode('utf-8', 'surrogateescape')


def digest(value):
    return hashlib.sha256(value).hexdigest()


def json_bytes(value):
    return json.dumps(value, ensure_ascii=True, sort_keys=True).encode('utf-8')


def commit(repo, ref):
    return decode(git(repo, 'rev-parse', '--verify', '--end-of-options', ref + '^{commit}')).strip()


def head_or_empty(repo):
    result = subprocess.run(['git', 'rev-parse', '--verify', '--quiet', 'HEAD'], cwd=repo, capture_output=True)
    if result.returncode == 0:
        return decode(result.stdout).strip(), False
    if result.returncode != 1:
        raise CollectionError('Cannot resolve HEAD: ' + decode(result.stderr))
    symbolic = decode(git(repo, 'symbolic-ref', '-q', 'HEAD')).strip()
    if not symbolic.startswith('refs/heads/'):
        raise CollectionError('Cannot establish an unborn branch')
    return decode(git(repo, 'hash-object', '-t', 'tree', '--stdin', data=b'')).strip(), True


def raw_changes(repo, diff_args):
    raw = git(repo, 'diff', '--raw', '-z', '--no-abbrev', '--no-renames', '--no-relative',
              '--no-ext-diff', '--no-textconv', *diff_args, '--')
    parts = raw.split(b'\0')
    records = []
    for i in range(0, len(parts) - 1, 2):
        fields = parts[i].split()
        if len(fields) != 5 or not fields[0].startswith(b':'):
            raise CollectionError('Unexpected Git raw diff record')
        if fields[4].startswith(b'U'):
            raise CollectionError('Unmerged files prevent a complete review snapshot')
        records.append({'path': decode(parts[i + 1]), 'status': decode(fields[4]),
                        'old_mode': decode(fields[0][1:]), 'new_mode': decode(fields[1]),
                        'old_blob': decode(fields[2]), 'new_blob': decode(fields[3])})
    return records


def untracked_paths(repo):
    return [decode(p) for p in git(repo, 'ls-files', '--others', '--exclude-standard', '-z').split(b'\0') if p]


def file_identity(path):
    if path.is_symlink():
        return {'symlink': os.readlink(path)}
    if not path.exists():
        return {'missing': True}
    if not path.is_file():
        raise CollectionError(f'Cannot read non-regular working file: {path}')
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return {'sha256': h.hexdigest(), 'mode': path.stat().st_mode & 0o777}


def working_identity(repo, mode):
    if git(repo, 'ls-files', '--unmerged', '-z'):
        raise CollectionError('Resolve the merge conflicts before collecting review evidence')
    base, unborn = head_or_empty(repo)
    index = git(repo, 'ls-files', '--stage', '-z')
    paths = set()
    if mode != 'staged':
        paths.update(r['path'] for r in raw_changes(repo, []))
    if mode == 'uncommitted':
        paths.update(untracked_paths(repo))
    return {'head': None if unborn else base, 'empty_tree': base if unborn else None,
            'index_sha256': digest(index),
            'working_files': {p: file_identity(repo / p) for p in sorted(paths)}}


def resolve_scope(repo, mode, refs, pr_repo):
    scope = {'mode': mode, 'requested_refs': refs, 'pr_repo': pr_repo}
    if mode in ('uncommitted', 'staged', 'unstaged'):
        if refs:
            raise CollectionError(f'{mode} does not accept refs')
        base, unborn = head_or_empty(repo)
        scope.update(base=base, head=None if unborn else base, unborn=unborn,
                     context='index and working tree, according to each change layer')
        return scope
    required = 2 if mode == 'range' else 1
    if len(refs) != required:
        raise CollectionError(f'{mode} requires {required} target(s)')
    if mode == 'pr':
        # Older gh versions do not expose baseRefOid in `pr view --json`.
        # Resolve the requested PR first, then obtain both SHAs from the REST API.
        argv = ['gh', 'pr', 'view', refs[0], '--json', 'number,url']
        if pr_repo:
            argv.extend(['--repo', pr_repo])
        try:
            selected = json.loads(run(argv, repo))
            url = urlparse(selected['url'])
            parts = url.path.strip('/').split('/')
            if url.scheme != 'https' or not url.hostname or len(parts) != 4 or parts[2] != 'pull' or not parts[3].isdigit():
                raise ValueError('Invalid canonical PR URL')
            if int(parts[3]) != selected['number']:
                raise ValueError('PR URL and number disagree')
            data = json.loads(run(['gh', 'api', '--hostname', url.hostname,
                                   f'repos/{parts[0]}/{parts[1]}/pulls/{parts[3]}'], repo))
            if data['number'] != selected['number'] or data['html_url'] != selected['url']:
                raise ValueError('Resolved PR identity changed')
            pr = {'number': data['number'], 'url': data['html_url'],
                  'baseRefName': data['base']['ref'], 'baseRefOid': data['base']['sha'],
                  'headRefName': data['head']['ref'], 'headRefOid': data['head']['sha']}
            for key in ('baseRefOid', 'headRefOid'):
                if not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', pr[key]):
                    raise ValueError(f'Invalid {key}')
            for key in ('number', 'url', 'baseRefName', 'headRefName'):
                if key not in pr:
                    raise ValueError(f'Missing {key}')
        except (ValueError, KeyError, TypeError) as exc:
            raise CollectionError(f'Incomplete PR metadata: {exc}') from exc
        try:
            target, head = commit(repo, pr['baseRefOid']), commit(repo, pr['headRefOid'])
        except CollectionError as exc:
            raise CollectionError('The requested PR objects are not available locally. Fetch its exact '
                                  'base/head from the PR repository (or use an isolated checkout), then rerun. '
                                  'Do not substitute the current branch. ' + str(exc)) from exc
        scope['pr'] = pr
        base = decode(git(repo, 'merge-base', target, head)).strip()
        scope['target_base'] = target
    elif mode == 'commit':
        head = commit(repo, refs[0])
        parents = decode(git(repo, 'rev-list', '--parents', '-n', '1', head)).strip().split()[1:]
        base = parents[0] if parents else decode(git(repo, 'hash-object', '-t', 'tree', '--stdin', data=b'')).strip()
        scope.update(parent_count=len(parents), comparison='first parent' if parents else 'empty tree')
    elif mode in ('branch', 'since'):
        target, head = commit(repo, refs[0]), commit(repo, 'HEAD')
        if mode == 'branch':
            base = decode(git(repo, 'merge-base', target, head)).strip()
            scope['target_base'] = target
        else:
            git(repo, 'merge-base', '--is-ancestor', target, head)
            base = target
    else:
        base, head = commit(repo, refs[0]), commit(repo, refs[1])
    scope.update(base=base, head=head, context=f'read surrounding source at {head}, not the current checkout')
    return scope


# Attention signals only. Emit complete matches; never determine risk here.
RULES = [
    ('UNESCAPED_BLADE_OUTPUT', 'ADD', r'\{!!', ''),
    ('RAW_SQL', 'ADD', r'DB::raw|whereRaw\(|selectRaw\(|orderByRaw\(|havingRaw\(|DB::unprepared|DB::statement', ''),
    ('MASS_ASSIGNMENT_OPENED', 'ADD', r'\$guarded\s*=\s*\[\]|::unguard\(|->forceFill\(', ''),
    ('SAFEGUARD_BYPASS', 'ADD', r'withoutMiddleware|withoutEvents|saveQuietly|withoutObservers|withoutGlobalScope', ''),
    ('TLS_VERIFICATION_DISABLED', 'ADD', r'''withoutVerifying|['"]verify['"]\s*=>\s*false|SSL_VERIFYPEER''', ''),
    ('DANGEROUS_PHP', 'ADD', r'\beval\(|\bexec\(|shell_exec|\bsystem\(|passthru|proc_open|\bpopen\(|\bunserialize\(', ''),
    ('DESTRUCTIVE_MIGRATION_VERB', 'ADD', r'dropColumn|dropIfExists|Schema::drop\(|->drop\(|renameColumn|->change\(|->truncate\(|->delete\(', r'^database/migrations/'),
    ('QUEUE_SEMANTICS', 'ADD', r'ShouldQueue|ShouldBeUnique|->onQueue\(|\$tries|backoff|retryUntil|afterCommit|WithoutOverlapping', ''),
    ('CONCURRENCY_PRIMITIVES', 'ADD', r'Cache::lock|lockForUpdate\(|sharedLock\(|->increment\(|->decrement\(', ''),
    ('FILE_UPLOAD_HANDLING', 'ADD', r'->file\(|->store\(|->storeAs\(|Storage::put|move_uploaded_file', ''),
    ('ENV_CALL', 'ADD', r'\benv\(', ''),
    ('DEBUG_LEFTOVER', 'ADD', r'\bdd\(|\bdump\(|\bvar_dump\(|\bray\(', ''),
    ('TEST_SKIPPED_ADDED', 'ADD', r'markTestSkipped|markTestIncomplete|->skip\(', r'^tests/'),
    ('AUTHZ_REMOVED', 'DEL', r'''authorize\(|Gate::|->can\(|->cannot\(|middleware\(['"]auth|->middleware\(|Auth::check|->policy\(''', ''),
    ('TRANSACTION_OR_LOCK_REMOVED', 'DEL', r'DB::transaction|beginTransaction|lockForUpdate|Cache::lock', ''),
    ('VALIDATION_RULES_REMOVED', 'DEL', r"'required|'unique:|'exists:|'confirmed|'min:|'max:|Rule::", r'^app/Http/Requests/'),
    ('ASSERTIONS_REMOVED', 'DEL', r'assert', r'^tests/'),
    ('EVENT_WIRING_REMOVED', 'DEL', r'::observe\(|Event::listen|->listen\(|\$listen|ShouldQueue', ''),
]
RULES = [(name, side, re.compile(pattern), re.compile(path)) for name, side, pattern, path in RULES]
HUNK = re.compile(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@')


def changed_lines(patch):
    old = new = old_left = new_left = 0
    for line in patch.split('\n'):
        match = HUNK.match(line)
        if match:
            old, new = int(match[1]), int(match[3])
            old_left, new_left = int(match[2] or 1), int(match[4] or 1)
        elif line.startswith('\\ No newline'):
            continue
        elif old_left or new_left:
            if line.startswith('+') and new_left:
                yield 'ADD', new, line[1:]
                new += 1
                new_left -= 1
            elif line.startswith('-') and old_left:
                yield 'DEL', old, line[1:]
                old += 1
                old_left -= 1
            elif line.startswith(' '):
                old += 1
                new += 1
                old_left -= 1
                new_left -= 1
            else:
                raise CollectionError('Unexpected patch content inside a hunk')


def scan(record):
    flags = []
    rows = list(changed_lines(record['patch'])) if record.get('patch') else []
    record['added_lines'] = sum(side == 'ADD' for side, _, _ in rows)
    record['deleted_lines'] = sum(side == 'DEL' for side, _, _ in rows)
    for side, line, content in rows:
        for name, wanted, pattern, path in RULES:
            if side == wanted and path.search(record['path']) and pattern.search(content):
                flags.append({'kind': name, 'layer': record['layer'], 'path': record['path'],
                              'side': 'new' if side == 'ADD' else 'old', 'line': line, 'content': content})
                if name == 'RAW_SQL' and re.search(r'\$[A-Za-z_]', content):
                    flags.append({**flags[-1], 'kind': 'RAW_SQL_WITH_VARIABLE'})
    return flags


def patch_record(repo, raw, layer, diff_args):
    record = {**raw, 'layer': layer}
    patch = git(repo, 'diff', '--no-ext-diff', '--no-textconv', '--no-color', '--no-renames',
                '--no-relative', '--src-prefix=a/', '--dst-prefix=b/', '-U0',
                *diff_args, '--', ':(literal)' + raw['path'])
    try:
        text = patch.decode('utf-8')
        binary = any(line.startswith(('Binary files ', 'GIT binary patch')) for line in text.splitlines())
        record.update(patch=text, binary=binary, requires_content_inspection=binary)
    except UnicodeDecodeError:
        record.update(patch=None, binary=False, requires_content_inspection=True,
                      content_gap='Patch is not UTF-8; inspect with the appropriate encoding')
    if '160000' in (raw['old_mode'], raw['new_mode']):
        record.update(requires_content_inspection=True, content_gap='Inspect the referenced submodule commits')
    return record


def untracked_record(repo, path):
    p = repo / path
    content = os.fsencode(os.readlink(p)) if p.is_symlink() else p.read_bytes()
    record = {'layer': 'untracked', 'path': path, 'status': 'A', 'sha256': digest(content),
              'symlink': p.is_symlink(), 'binary': b'\0' in content,
              'requires_content_inspection': b'\0' in content}
    try:
        text = content.decode('utf-8') if not record['binary'] else None
    except UnicodeDecodeError:
        text = None
        record.update(requires_content_inspection=True, content_gap='Non-UTF-8 file; inspect its encoding or format')
    if text is None:
        record['patch'] = None
    else:
        lines = [line + '\n' for line in text.split('\n')]
        if text.endswith('\n') or not text:
            lines.pop()
        record['patch'] = ''.join(difflib.unified_diff([], lines, fromfile='/dev/null',
                                                    tofile=json.dumps(path, ensure_ascii=True), n=0))
    return record


def collect(repo, mode, refs, pr_repo=None):
    scope = resolve_scope(repo, mode, refs, pr_repo)
    working = mode in ('uncommitted', 'staged', 'unstaged')
    identity = working_identity(repo, mode) if working else scope
    if working and identity.get('head') != scope['head']:
        raise CollectionError('HEAD changed while resolving the review scope; rerun')
    records = []
    layers = []
    if working:
        if mode != 'unstaged':
            layers.append(('staged', ['--cached', scope['base']]))
        if mode != 'staged':
            layers.append(('unstaged', []))
    else:
        layers.append(('committed', [scope['base'], scope['head']]))
    for layer, args in layers:
        for raw in raw_changes(repo, args):
            records.append(patch_record(repo, raw, layer, args))
    if mode == 'uncommitted':
        records.extend(untracked_record(repo, p) for p in untracked_paths(repo))
    if working and identity != working_identity(repo, mode):
        raise CollectionError('Working/index snapshot changed during collection; rerun')
    if not working and scope != resolve_scope(repo, mode, refs, pr_repo):
        raise CollectionError('Requested refs or PR changed during collection; rerun')
    flags = []
    pattern = os.environ.get('REVIEW_SENSITIVE_PATTERN', os.environ.get('REVIEW_SENSITIVE_GLOBS',
        'billing|payment|subscription|invoice|webhook|wallet|payout|refund|charge|checkout|stripe|paypal|mpesa|paystack|flutterwave|auth|tenan'))
    try:
        sensitive = re.compile(pattern, re.I)
    except re.error as exc:
        raise CollectionError(f'Invalid sensitive-path pattern: {exc}') from exc
    for record in records:
        flags.extend(scan(record))
        record['sensitive_path_hint'] = bool(sensitive.search(record['path']))
        record['generated_candidate'] = bool(re.search(r'^(vendor/|node_modules/|public/build/|_ide_helper)|\.min\.(js|css)$', record['path']))
        record['dependency_lockfile'] = Path(record['path']).name in ('composer.lock', 'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock')
        if record['status'] == 'D' and record['path'].startswith('tests/'):
            flags.append({'kind': 'TEST_FILES_DELETED', 'path': record['path'], 'layer': record['layer']})
    paths = sorted({r['path'] for r in records})
    if any(re.match(r'^(app|routes|database|config|bootstrap)/', p) for p in paths) and not any(p.startswith('tests/') for p in paths):
        flags.append({'kind': 'APP_CHANGED_NO_TEST_CHANGES'})
    for p in paths:
        if p == 'composer.json' or Path(p).name in ('composer.lock', 'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock'):
            flags.append({'kind': 'DEPENDENCIES_CHANGED', 'path': p})
    for index, flag in enumerate(flags, 1):
        flag['id'] = f'F{index:04d}'
    snapshot = digest(json_bytes({'repository': str(repo), 'scope': scope, 'identity': identity}))
    return {'schema_version': 1, 'repository': str(repo), 'scope': scope,
            'snapshot': {'id': snapshot, 'identity': identity}, 'empty': not records,
            'completeness': {'inventory': 'complete', 'patches_truncated': False,
                             'flags_truncated': False,
                             'content_gaps': [{'layer': r['layer'], 'path': r['path'],
                                              'reason': r.get('content_gap', 'Binary content requires an appropriate viewer')}
                                             for r in records if r['requires_content_inspection']]},
            'path_count': len(paths), 'change_count': len(records), 'changes': records, 'flags': flags,
            'notes': ['Flags and path categories are attention hints, never automatic risk classifications.',
                      'Review staged and working outcomes separately when their changes cancel.',
                      'JSON escapes preserve unusual filenames and tabs. No matches or files are sampled.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', nargs='?', default='uncommitted',
                        choices=['uncommitted', 'staged', 'unstaged', 'commit', 'since', 'branch', 'range', 'pr', 'verify'])
    parser.add_argument('refs', nargs='*')
    parser.add_argument('--repo', default='.', help='Local repository path')
    parser.add_argument('--pr-repo', help='Explicit gh repository (HOST/OWNER/REPO or OWNER/REPO)')
    parser.add_argument('--output', help='Save complete JSON outside the reviewed repository')
    args = parser.parse_args()
    try:
        repo = Path(decode(git(Path(args.repo).resolve(), 'rev-parse', '--show-toplevel')).strip()).resolve()
        if args.mode == 'verify':
            if len(args.refs) != 1:
                raise CollectionError('verify requires the previously saved evidence JSON path')
            expected = json.loads(Path(args.refs[0]).read_text())
            if expected.get('schema_version') != 1 or expected['repository'] != str(repo):
                raise CollectionError('Evidence schema or repository does not match')
            scope = expected['scope']
            result = collect(repo, scope['mode'], scope['requested_refs'], scope.get('pr_repo'))
            if result['snapshot']['id'] != expected['snapshot']['id']:
                raise CollectionError('Reviewed snapshot changed; collect new evidence and re-review the affected scope')
            result = {'verified': True, 'repository': str(repo), 'snapshot_id': result['snapshot']['id']}
        else:
            result = collect(repo, args.mode, args.refs, args.pr_repo)
        rendered = json.dumps(result, indent=2, ensure_ascii=True) + '\n'
        if args.output:
            output = Path(args.output).resolve()
            if output == repo or repo in output.parents:
                raise CollectionError('Save evidence outside the reviewed repository to avoid changing the review scope')
            output.write_text(rendered)
        else:
            sys.stdout.write(rendered)
    except (CollectionError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
