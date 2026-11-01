"""Local quota guard: no model calls, no worker termination, no main/index changes."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STATE = ROOT / 'coordination' / '.runtime' / 'quota'
KIRO = Path(os.environ['LOCALAPPDATA']) / 'Kiro-Cli/run/chat-cli-2.35.1.exe'
ROLES = {
    '01-director': ('docs/design/', 'data/'),
    '02-engine': ('src/core/', 'src/gameplay/', 'scenes/gameplay/', 'docs/contracts/', 'docs/architecture/'),
    '03-art': ('assets/', 'tools/art/', 'docs/art/'),
    '04-client': ('src/ui/', 'scenes/ui/', 'tools/build/', 'tests/', 'docs/qa/', 'docs/mobile/'),
    '05-audio': ('assets/audio/', 'src/audio/', 'tools/audio/', 'docs/audio/'),
    '06-services': ('src/services/', 'docs/services/', 'tests/services/'),
    '07-qa': ('tests/acceptance/', 'tools/qa/', 'docs/verification/'),
    '08-performance': ('tools/perf/', 'tests/performance/', 'docs/performance/'),
    '09-research-product': ('docs/research/product/',),
    '10-research-systems': ('docs/research/systems/',),
    '06-art-ui': ('tools/art/ui.py', 'tools/art/ui_contrast.py', 'tools/art/ui_sheet_compare.py', 'tools/art/branding.py', 'tools/art/branding_check.py', 'tools/art/launcher_icons.py', 'tools/art/adaptive_icon.py', 'tools/art/ui_art/', 'assets/atlases/ui_main.', 'assets/atlases/ui_title_', 'assets/branding/', 'tools/art/layout_lock/ui_main.json', 'tools/art/layout_lock/ui_title_ko.json', 'tools/art/layout_lock/ui_title_en.json', 'docs/art/previews/atlas_ui_', 'docs/art/ui/', 'docs/art/evidence/ui_art/', 'docs/art/branding/', 'docs/art/evidence/branding/'),
    '09-art-world': ('tools/art/biome.py', 'tools/art/biome_check.py', 'tools/art/bases.py', 'tools/art/nest_check.py', 'tools/art/fx.py', 'tools/art/world/', 'assets/atlases/biome_meadow.', 'assets/atlases/bases.', 'assets/atlases/fx_combat.', 'tools/art/layout_lock/biome_meadow.json', 'tools/art/layout_lock/bases.json', 'tools/art/layout_lock/fx_combat.json', 'docs/art/previews/atlas_biome_meadow.png', 'docs/art/previews/atlas_bases.png', 'docs/art/previews/atlas_fx_combat.png', 'docs/art/world/'),
}
ROOT_ENGINE = {'project.godot', 'export_presets.cfg', '.gitignore', 'icon.svg', 'icon.svg.import', 'README.md'}
ROLES['11-code-review'] = ('docs/review/code/',)
ROLES['12-text-review'] = ('docs/review/text/',)


def git(*args, env=None, check=True):
    return subprocess.run(['git', *args], cwd=ROOT, env=env, capture_output=True,
                          text=True, encoding='utf-8', errors='replace', check=check, timeout=90)


def atomic_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')
    tmp.replace(path)


def parse_usage(text):
    m = re.search(r'Credits\s*\(([\d,.]+)\s+of\s+([\d,.]+)', text, re.I)
    if not m:
        raise ValueError('Usage unavailable: no account credit values; no percentage guessed.')
    used, cap = (float(v.replace(',', '')) for v in m.groups())
    if cap <= 0:
        raise ValueError('Invalid plan capacity')
    return {'used': used, 'cap': cap, 'percent': used / cap * 100}


def owner(path):
    if path in ROOT_ENGINE:
        return '02-engine'
    # Narrow overrides precede broad grants.
    for role in ('06-art-ui', '09-art-world', '05-audio', '06-services', '07-qa', '08-performance'):
        if path.startswith(ROLES[role]):
            return role
    for role, prefixes in ROLES.items():
        if path.startswith(prefixes):
            return role
        if path in (f'coordination/status/{role}.md', f'coordination/handoffs/{role}.md'):
            return role
        if path.startswith(f'coordination/requests/{role}-to-'):
            return role
    if path == 'coordination/requests/USER_QUESTION.md':
        return '01-director'
    if path.startswith('coordination/') and not path.startswith(('coordination/logs/', 'coordination/.runtime/', 'coordination/launchers/')):
        return '00-coordination'
    return None


def source_files():
    result = git('ls-files', '-z', '--cached', '--others', '--exclude-standard').stdout
    files = sorted(set(result.split('\0')) - {''})
    return [f for f in files if owner(f) and not re.search(
        r'(^|/)(\.env($|\.)|[^/]+\.(keystore|jks|p12|pfx|apk|aab|exe|zip|tpz)$)', f, re.I)]


def checkpoint(usage, dry_run=False):
    stamp = dt.datetime.now().strftime('%Y%m%d-%H%M%S')
    base = git('rev-parse', 'HEAD').stdout.strip()
    groups = {r: [] for r in ('00-coordination', *ROLES)}
    for file in source_files():
        groups[owner(file)].append(file)
    if dry_run:
        return {'dry_run': True, 'base': base, 'usage': usage,
                'roles': {r: len(files) for r, files in groups.items()},
                'main_and_shared_index_untouched': True}
    report = {'time': stamp, 'base': base, 'usage': usage, 'status': 'CHECKPOINTING',
              'warning': 'WIP snapshots of files on disk, not atomic live-session or release-quality guarantees.', 'roles': {}}
    atomic_json(STATE / 'checkpoint.json', report)
    try:
        sessions = subprocess.run([str(KIRO), 'chat', '--list-sessions', '--format', 'json'],
            cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=45)
        (STATE / 'sessions.json').write_text(sessions.stdout, encoding='utf-8')
        report['session_inventory_exit'] = sessions.returncode
    except (subprocess.SubprocessError, OSError) as error:
        report['session_inventory_error'] = str(error)
    request = ROOT / 'coordination/requests/QUOTA_CHECKPOINT.md'
    request.write_text(
        f'# Quota checkpoint: {usage["percent"]:.2f}%\n'
        'STOP assigning new tasks/model calls. Finish only current atomic file writes; '
        'persist exact status/session ID and wait for user account login. '
        'Do not terminate terminal hosts or workers. WIP backups go to separate checkpoint branches.\n', encoding='utf-8')
    for role in ROLES:
        with (ROOT / f'coordination/requests/coordinator-to-{role}.md').open('a', encoding='utf-8') as out:
            out.write(f'\n## QUOTA CHECKPOINT\nStop current work at a safe boundary. Write coordination/handoffs/{role}.md with completed work, unfinished work, exact next steps, validation, errors, session ID and commit/push status; commit/push owned work where possible. Await account login.\n')
        handoff = ROOT / f'coordination/handoffs/{role}.md'
        handoff.parent.mkdir(parents=True, exist_ok=True)
        status = ROOT / f'coordination/status/{role}.md'
        previous = handoff.read_text(encoding='utf-8-sig', errors='replace') if handoff.exists() else ''
        status_text = status.read_text(encoding='utf-8-sig', errors='replace') if status.exists() else 'No status available.'
        if not previous:
            handoff.write_text(f'# {role} quota handoff\n\nCoordinator snapshot: worker has not confirmed this handoff.\n\n{status_text}\n', encoding='utf-8')
        report['roles'][role] = {'handoff': str(handoff.relative_to(ROOT)), 'worker_acknowledged': False}
    # Include freshly created handoffs and quota instructions in the snapshot.
    groups = {r: [] for r in ('00-coordination', *ROLES)}
    for file in source_files():
        groups[owner(file)].append(file)
    # Each role gets an isolated Git index and ref. Never checkout or stage in the shared index.
    for role, files in groups.items():
        if not files:
            report['roles'][role] = {'status': 'NO_FILES'}
            continue
        ref = f'refs/heads/checkpoint/quota-{stamp}/{role}'
        with tempfile.TemporaryDirectory(prefix='kiro-quota-') as temp:
            env = dict(os.environ, GIT_INDEX_FILE=str(Path(temp) / 'index'))
            try:
                git('read-tree', base, env=env)
                for start in range(0, len(files), 60):
                    git('add', '--', *files[start:start+60], env=env)
                tree = git('write-tree', env=env).stdout.strip()
                msg = f'[Chore] {role} 사용량 97% 작업 체크포인트 (미검증 WIP)'
                sha = git('commit-tree', tree, '-p', base, '-m', msg, env=env).stdout.strip()
                git('update-ref', ref, sha, '0' * 40)
                result = git('push', 'origin', f'{sha}:{ref}', check=False)
                report['roles'][role] = {'sha': sha, 'ref': ref, 'files': len(files),
                    'status': 'PUSHED' if result.returncode == 0 else 'PUSH_PENDING',
                    'error': result.stderr[-1500:] if result.returncode else None}
            except (subprocess.SubprocessError, OSError) as error:
                report['roles'][role] = {'status': 'FAILED', 'error': str(error)}
        atomic_json(STATE / 'checkpoint.json', report)
    report['status'] = 'SAVED' if all(v['status'] in ('PUSHED', 'NO_FILES') for v in report['roles'].values()) else 'NEEDS_ATTENTION'
    atomic_json(STATE / 'checkpoint.json', report)
    return report


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--once', action='store_true')
    p.add_argument('--dry-run', action='store_true')
    p.add_argument('--fixture')
    args = p.parse_args()
    STATE.mkdir(parents=True, exist_ok=True)
    lock = (STATE / 'guard.lock').open('a+b')
    if not args.dry_run:
        import msvcrt
        lock.seek(0)
        try:
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            raise SystemExit('Quota guard already running')
    triggered = (STATE / 'triggered.json').exists()
    while True:
        started = time.monotonic()
        try:
            text = args.fixture
            if text is None:
                result = subprocess.run([str(KIRO), 'chat', '--v2', '--no-interactive', '/usage'],
                    cwd=tempfile.gettempdir(), capture_output=True, text=True,
                    encoding='utf-8', errors='replace', timeout=45)
                if result.returncode:
                    raise RuntimeError(f'Usage query exit {result.returncode}: {result.stderr[-500:]}')
                text = result.stdout
            usage = parse_usage(text)
            usage['observed_at'] = dt.datetime.now().astimezone().isoformat()
            if not args.dry_run:
                atomic_json(STATE / 'usage.json', usage)
            if usage['percent'] >= 97 and not triggered:
                if not args.dry_run:
                    atomic_json(STATE / 'triggered.json', usage)
                    triggered = True
                report = checkpoint(usage, args.dry_run)
                print(json.dumps(report, ensure_ascii=False), flush=True)
                # A real threshold run parks after saving: no re-query or account auto-reset.
                if not args.dry_run:
                    return
            if args.once or args.fixture:
                return
        except Exception as error:
            if args.dry_run:
                raise
            atomic_json(STATE / 'error.json', {'time': dt.datetime.now().astimezone().isoformat(), 'error': str(error)})
        time.sleep(max(1, 30 - (time.monotonic() - started)))


if __name__ == '__main__':
    main()

