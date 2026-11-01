
"""User-ordered stop checkpoint (2026-11-01 09:3x KST). Reuses quota_guard's isolated-index commit-tree logic
without the 97% gate and without writing request/handoff files. Never touches main or the shared index."""
import sys, os, json, tempfile, datetime as dt, subprocess
import importlib.util
spec = importlib.util.spec_from_file_location('qg', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'quota_guard.py'))
qg = importlib.util.module_from_spec(spec); spec.loader.exec_module(qg)
stamp = dt.datetime.now().strftime('%Y%m%d-%H%M%S')
qg.git('fetch', 'origin', 'main', '-q', check=False)
base = qg.git('rev-parse', 'origin/main').stdout.strip()
groups = {r: [] for r in ('00-coordination', *qg.ROLES)}
for f in qg.source_files():
    groups[qg.owner(f)].append(f)
report = {'time': stamp, 'kind': 'user-stop', 'base': base, 'roles': {}}
for role, files in groups.items():
    if not files:
        report['roles'][role] = {'status': 'NO_FILES'}; continue
    ref = f'refs/heads/checkpoint/stop-{stamp}/{role}'
    with tempfile.TemporaryDirectory(prefix='kiro-stop-') as temp:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(temp, 'index'))
        try:
            qg.git('read-tree', base, env=env)
            for s in range(0, len(files), 60):
                qg.git('add', '--', *files[s:s+60], env=env)
            tree = qg.git('write-tree', env=env).stdout.strip()
            base_tree = qg.git('rev-parse', base + '^{tree}').stdout.strip()
            if tree == base_tree:
                report['roles'][role] = {'status': 'SAME_AS_MAIN', 'files': len(files)}; continue
            diff = qg.git('diff', '--name-only', base, tree).stdout.split()
            msg = f'[Chore] {role} 사용자 중단 지시 작업트리 체크포인트 (미검증 WIP, main 아님)'
            sha = qg.git('commit-tree', tree, '-p', base, '-m', msg, env=env).stdout.strip()
            qg.git('update-ref', ref, sha, '0' * 40)
            res = qg.git('push', 'origin', f'{sha}:{ref}', check=False)
            report['roles'][role] = {'sha': sha, 'ref': ref, 'changed': diff,
                'status': 'PUSHED' if res.returncode == 0 else 'PUSH_FAILED', 'error': res.stderr[-800:] if res.returncode else None}
        except Exception as e:
            report['roles'][role] = {'status': 'FAILED', 'error': str(e)}
out = os.path.join(os.path.dirname(__file__), '.runtime', f'stop-checkpoint-{stamp}.json')
open(out, 'w', encoding='utf-8').write(json.dumps(report, ensure_ascii=False, indent=2))
for r, v in report['roles'].items():
    print(r, v.get('status'), v.get('sha','')[:10], len(v.get('changed', [])), (v.get('changed') or [])[:12], v.get('error') or '')
print('REPORT', out)

