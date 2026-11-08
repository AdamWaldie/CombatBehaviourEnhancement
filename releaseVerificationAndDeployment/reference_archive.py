"""Create or verify private, dated CBE reference snapshots without executing mods."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
STORES = Path('C:/Users/AdamW/Documents/AI-Reference-Archives')
WORKSHOP = Path('E:/SteamLibrary/steamapps/workshop/content/107410')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def verify(root):
    root = root.resolve()
    expected = (root/'manifest.sha256').read_text(encoding='ascii').split()[0]
    if digest(root/'manifest.json') != expected:
        raise ValueError('Manifest fingerprint mismatch')
    manifest = json.loads((root/'manifest.json').read_text(encoding='utf-8'))
    declared = set()
    for row in manifest['files']:
        rel = Path(row['path']); path = root/rel
        if rel.is_absolute() or '..' in rel.parts or not path.resolve().is_relative_to(root):
            raise ValueError('Unsafe manifest path')
        if row['path'] in declared:
            raise ValueError('Duplicate manifest path')
        declared.add(row['path'])
        if not path.is_file() or path.stat().st_size != row['bytes'] or digest(path) != row['sha256']:
            raise ValueError('Missing or changed archived file: '+row['path'])
    actual = {p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()}
    if actual != declared | {'manifest.json', 'manifest.sha256'}:
        raise ValueError('Unrecorded or missing archive files')
    print(f'VERIFIED {root}: {len(declared)} files; manifest {expected}', flush=True)
    return manifest


def create(args):
    registry = json.loads(args.registry.read_text(encoding='utf-8'))
    map_path = REPO/'reference/sourceReviews/source-review-map.json'
    source_map = json.loads(map_path.read_text(encoding='utf-8'))
    refs = {str(x['workshopId']): dict(x) for x in source_map['references']}
    for key, value in registry['entries'].items():
        refs.setdefault(str(key), {}).update(value)
    refs.pop('3829519860', None)  # Explicitly withdrawn, never restore its active scope.
    stamp = args.label or datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
    if not stamp or any(c not in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_' for c in stamp):
        raise ValueError('Label must be a simple new directory name')
    primary = (args.archive_root/stamp).resolve(); mirror = (args.mirror_root/stamp).resolve()
    for target in (primary, mirror):
        if target.exists() or target.is_relative_to(REPO.resolve()) or target.is_relative_to(Path(tempfile.gettempdir()).resolve()):
            raise ValueError('Refuse existing, repository or temporary archive target: '+str(target))
    if primary == mirror or primary.is_relative_to(mirror) or mirror.is_relative_to(primary):
        raise ValueError('Archive and mirror must be separate')
    pinned_root = args.stores/'PinnedDown/20261013-013708'
    pinned_manifest = json.loads((pinned_root/'manifest.json').read_text(encoding='utf-8'))
    for row in pinned_manifest['files']:
        if digest(pinned_root/row['path']) != row['sha256']:
            raise ValueError('Protected Pinned Down snapshot fails its original manifest')
    pinned = {str(x['workshop_id']): x for x in pinned_manifest['mods']}
    plan = []; index = []
    for key, ref in sorted(refs.items()):
        if not key.isdigit():
            raise ValueError('Invalid Workshop id')
        sources = []; observed = set()
        for root in args.workshop_root or [WORKSHOP]:
            source = root/key
            if source.is_dir() and source.resolve() not in observed:
                observed.add(source.resolve()); dest = f'mods/{key}/installed-{len(sources)+1:02d}'
                plan.append((source, dest))
                sources.append({'kind': 'installed-originals', 'source': str(source), 'archive': dest})
        if key in pinned:
            sources.append({'kind': 'preserved-extracted-only', 'archive': 'preserved/PinnedDown/20261013-013708/'+key,
                            'note': 'Extracted snapshots; original signed packages were not preserved.'})
        state = 'ARCHIVED_INSTALLED' if any(x['kind']=='installed-originals' for x in sources) else ('ARCHIVED_EXTRACTED_ONLY' if sources else 'SOURCE_UNAVAILABLE')
        index.append({'workshopId': key, 'name': ref.get('name') or 'Identity unresolved', 'status': state,
                      'sources': sources, 'implementationStatus': ref.get('status', ref.get('recordedImplementationStatus', 'UNKNOWN'))})
    for name in ['FPVSCARE', 'LAMBS', 'PinnedDown', 'Protocol']:
        source = args.stores/name
        if source.is_dir():
            plan.append((source, 'preserved/'+name))
    plan += [(map_path, 'catalog/source-review-map.json'),
             (args.registry, 'catalog/implementation-register-additions.json'),
             (REPO/'reference/sourceReviews', 'catalog/sourceReviews'),
             (REPO/'releaseVerificationAndDeployment/referenceReviews', 'catalog/referenceReviews'),
             (REPO/'AGENT-HANDOVER.md', 'catalog/AGENT-HANDOVER.md'),
             (REPO/'AGENT-CONTINUATION-PROMPT.md', 'catalog/AGENT-CONTINUATION-PROMPT.md'),
             (Path(__file__), 'catalog/reference_archive.py')]
    files = []; destinations = set()
    for source, relative in plan:
        if not source.exists():
            raise FileNotFoundError(source)
        for path in sorted(source.rglob('*')) if source.is_dir() else [source]:
            if not path.is_file():
                continue
            if not path.resolve().is_relative_to(source.resolve() if source.is_dir() else source.parent.resolve()):
                raise ValueError('Reference link escapes selected source')
            if path.suffix.lower()=='.biprivatekey':
                raise ValueError('Refuse private signing material')
            rel = (Path(relative)/path.relative_to(source)).as_posix() if source.is_dir() else relative
            if rel in destinations:
                raise ValueError('Duplicate copy destination')
            destinations.add(rel); files.append((path, rel, path.stat()))
    total = sum(row[2].st_size for row in files)
    for target in (primary, mirror):
        target.parent.mkdir(parents=True, exist_ok=True)
        if shutil.disk_usage(target.parent).free < total+512*1024*1024:
            raise ValueError('Insufficient free space')
    primary.mkdir(exist_ok=False); rows = []
    print(f'COPY {len(files)} files, {total} bytes; {len(index)} references -> {primary}', flush=True)
    for number, (source, rel, before) in enumerate(files, 1):
        target = primary/rel; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        source_hash = digest(source); target_hash = digest(target); after = source.stat()
        if before.st_size != after.st_size or before.st_mtime_ns != after.st_mtime_ns or source_hash != target_hash:
            raise ValueError('Source changed during copy: '+str(source))
        rows.append({'path': rel, 'bytes': before.st_size, 'sha256': target_hash, 'source': str(source), 'sourceMtimeNs': before.st_mtime_ns})
        if number % 200 == 0:
            print(f'Copied and compared {number}/{len(files)} files', flush=True)
    created = datetime.now(timezone.utc).isoformat()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip()
    unavailable = [x for x in index if x['status']=='SOURCE_UNAVAILABLE']
    dump(primary/'reference-index.json', {'createdUtc': created, 'sourceCommit': commit, 'references': index,
         'unavailable': unavailable, 'scope': 'Private preservation only; no implementation/behaviour proof.', 'audits': 'PAUSED'})
    readme = ('# Private CBE reference archive\n\n'
              'Installed original packages, signatures and metadata are preserved alongside separately identified older/extracted snapshots. '
              'Raw reference content is private research input; never add it to Git or product packages. Reuse rights and functionality require separate review.\n\n'
              'reference-index.json records per-mod availability and relative source paths. SOURCE_UNAVAILABLE means no source copy was found. '
              'Pinned Down extracted snapshots are not original signed package backups.\n\n'
              'Verify using catalog/reference_archive.py verify <archive-path>. manifest.json covers every data/catalog file; manifest.sha256 covers the manifest. '
              'Keep the snapshot immutable and save new versions into a new dated directory. Hash verification is integrity evidence, not authenticity or behaviour proof.\n\n'
              'Restore research copies to a separate working directory. General implementation and audits remain paused.\n')
    (primary/'README.md').write_text(readme, encoding='utf-8')
    for name in ['reference-index.json', 'README.md']:
        f = primary/name; rows.append({'path': name, 'bytes': f.stat().st_size, 'sha256': digest(f), 'source': 'generated-catalog'})
    manifest = {'schemaVersion': 1, 'createdUtc': created, 'sourceCommit': commit, 'fileCount': len(rows),
                'registeredReferences': len(index), 'installedReferences': sum(x['status']=='ARCHIVED_INSTALLED' for x in index),
                'extractedOnlyReferences': sum(x['status']=='ARCHIVED_EXTRACTED_ONLY' for x in index),
                'unavailableReferences': len(unavailable), 'files': rows}
    dump(primary/'manifest.json', manifest); fingerprint = digest(primary/'manifest.json')
    (primary/'manifest.sha256').write_text(fingerprint+'  manifest.json\n', encoding='ascii')
    verify(primary); shutil.copytree(primary, mirror); verify(mirror)
    result = {'primary': str(primary), 'mirror': str(mirror), 'manifestSHA256': fingerprint, 'fileCount': len(rows),
              'sourceBytes': total, 'installed': manifest['installedReferences'], 'extractedOnly': manifest['extractedOnlyReferences'],
              'unavailable': [{'workshopId': x['workshopId'], 'name': x['name']} for x in unavailable]}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True); dump(args.report, result)
    print(json.dumps(result, indent=2), flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__); sub = p.add_subparsers(dest='command', required=True)
    c = sub.add_parser('create')
    c.add_argument('--registry', type=Path, default=REPO/'.qa/implementation-register-additions.json')
    c.add_argument('--stores', type=Path, default=STORES)
    c.add_argument('--workshop-root', type=Path, action='append')
    c.add_argument('--archive-root', type=Path, default=STORES/'CBE-Reference-Library')
    c.add_argument('--mirror-root', type=Path, default=Path('E:/AI-Reference-Archives/CBE-Reference-Library'))
    c.add_argument('--label'); c.add_argument('--report', type=Path)
    v = sub.add_parser('verify'); v.add_argument('archive', type=Path)
    args = p.parse_args()
    try:
        create(args) if args.command=='create' else verify(args.archive)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as e:
        print('ARCHIVE FAILED: '+str(e), file=sys.stderr); return 1
    return 0


if __name__=='__main__':
    raise SystemExit(main())
