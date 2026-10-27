#!/usr/bin/env python3
"""Publish an immutable owned-source image through the existing Docker Hub route.

All bulk state remains on the declared task-owned F-backed filesystem. Never
modifies production, shared builders, credentials or the default Docker config.
"""
import argparse
import base64
import shutil
import urllib.request
import urllib.error
import urllib.parse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import signal
import stat
import subprocess
import tarfile
import time
import uuid

GIB = 1024 ** 3
RESERVE, BUILD_BUDGET, OUTPUT_LIMIT = 15 * GIB, 2 * GIB, 0
SERVICES = ('qbit-monitor',)
BASE = Path('/home/brajam/.local/share/branconet-migration/local-image-build-offload-20261025')
STORAGE = {'kind': 'dedicated-f-drive-ext4-loop', 'filesystem_uuid': '3c792469-ea0e-4a2c-98e8-1185b141607b', 'backing_file': r'F:\branconet-build-storage\native-build-20261025.ext4', 'backing_file_bytes': 152 * GIB, 'docker_root_filesystem_uuid': 'de6eee3d-80cf-41dc-bf4c-91ee606d02da', 'docker_mutable_budget_bytes': 64 * 1024 ** 2, 'docker_physical_reserve_bytes': 15 * GIB}
ROOT_UUID = '3c792469-ea0e-4a2c-98e8-1185b141607b'
BUILDX_PATH = Path('/usr/libexec/docker/cli-plugins/docker-buildx')
BUILDX_SHA = '84554b12c90d21f3627d7f6a99aeabf69dc3aab8c2de41ed6f85097ed7cfd2c0'
BUILDER_IMAGE = 'docker.io/moby/buildkit:v0.34.1@sha256:99368f3e46177c6405b9740e4461d91cee004128daeecca78d4ceac50ec1da5c'
LOCK_SHA = '9665b245267e7c864210bdf85f1098c0891f30946c64b3781f44077fff0b7811'
POWERSHELL = '/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
CONFIG = '''root = "/var/lib/buildkit"
[grpc]
  address = ["unix:///run/buildkit/local.sock"]
  gid = 1000
[worker.oci]
  enabled = true
  gc = true
  max-parallelism = 2
  reservedSpace = "256MiB"
  maxUsedSpace = "1GiB"
  minFreeSpace = "15GiB"
[worker.containerd]
  enabled = false
'''
WINDOWS = r'''$ErrorActionPreference='Stop'; [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$f=Get-Item -LiteralPath 'F:\branconet-build-storage\native-build-20261025.ext4'; $d=[IO.DriveInfo]::new('F:\'); $c=[IO.DriveInfo]::new('C:\'); $m=Get-CimInstance Win32_OperatingSystem
[pscustomobject]@{distribution='Ubuntu';backing_file_path=$f.FullName;backing_file_bytes=$f.Length;backing_drive=$d.Name;backing_total_bytes=$d.TotalSize;backing_available_bytes=$d.AvailableFreeSpace;docker_backing_available_bytes=$c.AvailableFreeSpace;physical_available_bytes=([int64]$m.FreePhysicalMemory*1024)} | ConvertTo-Json -Compress
'''


class Refused(Exception):
    pass


def need(value, code):
    if not value: raise Refused(code)


def compact(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 ** 2), b''): h.update(block)
    return h.hexdigest()


def write_new(path, value):
    data = json.dumps(value, sort_keys=True, indent=2).encode() + b'\n'
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(data); stream.flush(); os.fsync(stream.fileno())


def run(argv, env, limit=4 * 1024 ** 2, timeout=30):
    # Callers use fixed metadata commands; raw stderr is never returned.
    p = subprocess.run(argv, env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=timeout, pass_fds=(200,))
    operation = (argv[3] if argv[1:2] == ['--host'] else argv[1]) if Path(argv[0]).name == 'docker' and len(argv) > 1 else 'read'
    diagnostic = ':missing_file' if b'No such file or directory' in p.stderr else ':permission' if b'Permission denied' in p.stderr else ''
    need(p.returncode == 0 and len(p.stdout) <= limit, 'metadata_command_refused:' + Path(argv[0]).name + ':' + operation + ':' + str(p.returncode) + diagnostic)
    return p.stdout


def safe_env(home):
    env = {'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
           'HOME': str(home), 'DOCKER_CONFIG': str(home / '.docker'), 'LANG': 'C.UTF-8',
           'PYTHONDONTWRITEBYTECODE': '1', 'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_SYSTEM': '/dev/null'}
    interop = os.environ.get('WSL_INTEROP', '')
    if re.fullmatch(r'/run/WSL/[0-9]+_interop', interop): env['WSL_INTEROP'] = interop
    return env


def filesystem(env, root):
    item = json.loads(run(['findmnt', '--json', '--target', str(root), '--output', 'UUID,SOURCE,FSTYPE'], env))['filesystems']
    need(len(item) == 1 and item[0]['uuid'] == ROOT_UUID and item[0]['fstype'] == 'ext4' and item[0]['source'].startswith('/dev/loop'), 'dedicated_ext4_filesystem_changed')
    need(BASE.is_mount() and root.resolve() == root and root.stat().st_dev == BASE.stat().st_dev and root.stat().st_dev != os.stat('/').st_dev, 'dedicated_native_mount_required')
    loop = Path(item[0]['source']).name
    need((Path('/sys/class/block')/loop/'loop/backing_file').read_text().strip() == '/mnt/f/branconet-build-storage/native-build-20261025.ext4', 'loop_backing_file_changed')
    v = os.statvfs(root)
    need(root.stat().st_uid == 1000 and v.f_files > 0, 'owned_native_root')
    return {'uuid': item[0]['uuid'], 'source': item[0]['source'], 'filesystem': 'ext4', 'device': root.stat().st_dev, 'total_bytes': v.f_blocks * v.f_frsize, 'available_bytes': v.f_bavail * v.f_frsize, 'free_inode_fraction': v.f_favail / v.f_files}


def windows(env):
    w = json.loads(run([POWERSHELL, '-NoLogo', '-NonInteractive', '-NoProfile', '-Command', WINDOWS], env, timeout=20).decode('utf-8-sig'))
    need(w['distribution'] == 'Ubuntu' and w['backing_drive'] == 'F:\\' and w['backing_file_path'] == STORAGE['backing_file'] and w['backing_file_bytes'] == STORAGE['backing_file_bytes'], 'dedicated_physical_backing_changed')
    return w

def manifest(context):
    rows = {}
    for p in sorted(context.rglob('*')):
        s = p.lstat()
        need(not stat.S_ISLNK(s.st_mode), 'context_symlink')
        if stat.S_ISDIR(s.st_mode): continue
        need(stat.S_ISREG(s.st_mode) and s.st_nlink == 1, 'context_special_file')
        rows[str(p.relative_to(context))] = {'sha256': sha(p), 'bytes': s.st_size, 'mode': stat.S_IMODE(s.st_mode)}
    return rows


def export_commit(repo, commit, service, context, env):
    need(repo.resolve() == repo and repo.name == service and service == 'qbit-monitor', 'owned_repository_required')
    git = ['git', '-c', 'safe.directory='+str(repo), '-c', 'core.autocrlf=true', '-C', str(repo)]
    need(run(git+['remote','get-url','origin'],env).decode().strip().removesuffix('.git') == 'https://github.com/jtmb/qbit-monitor', 'owned_origin_changed')
    need(run(git+['rev-parse',commit+'^{commit}'],env).decode().strip()==commit, 'immutable_source_missing')
    need(not run(git+['status','--porcelain','--untracked-files=all'],env), 'source_must_be_committed')
    rows=[]; total=0
    listing=run(git+['ls-tree','-rlz',commit,'--','dockerfile','.dockerignore','main.sh','modules'],env)
    for entry in listing.rstrip(b'\0').split(b'\0'):
        header,name=entry.split(b'\t',1);mode,kind,oid,size=header.split();relative=PurePosixPath(name.decode())
        need(mode in [b'100644',b'100755'] and kind==b'blob' and not relative.is_absolute() and all(x not in ['.','..','.git'] for x in relative.parts), 'regular_source_required')
        total+=int(size);need(int(size)<=1024**2 and total<=4*1024**2 and len(rows)<64,'source_bound')
        data=run(git+['cat-file','blob',oid.decode()],env)
        need(len(data)==int(size) and hashlib.sha1(b'blob '+size+b'\0'+data).hexdigest()==oid.decode(),'source_blob_binding')
        dest=context.joinpath(*relative.parts);dest.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
        with dest.open('xb') as stream:stream.write(data)
        dest.chmod(0o755 if mode==b'100755' else 0o644)
        rows.append({'path':str(relative),'git_blob':oid.decode(),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'git_mode':mode.decode()})
    need(rows and ' AS runtime' in (context/'dockerfile').read_text(),'runtime_recipe_missing')
    return {'commit':commit,'repository':'https://github.com/jtmb/qbit-monitor','files':rows,'source_bytes':total,'source_only':True}


def registry_document(reference, env, root, allow_missing=False):
    # Credential-helper stdout is consumed in memory only; never saved or logged.
    result=subprocess.run([str(root/'client/bin/docker-credential-branconet-windows'),'get'],input=b'https://index.docker.io/v1/\n',capture_output=True,env=env,timeout=30,pass_fds=(200,))
    need(result.returncode==0 and len(result.stdout)<=8192,'existing_credential_unavailable')
    credential=json.loads(result.stdout);need(credential['Username']=='jtmb92','existing_account_changed')
    basic=base64.b64encode((credential['Username']+':'+credential['Secret']).encode()).decode()
    request=urllib.request.Request('https://auth.docker.io/token?service=registry.docker.io&scope=repository:jtmb92/qbit-monitor:pull,push',headers={'Authorization':'Basic '+basic})
    with urllib.request.urlopen(request,timeout=30) as response: token=json.loads(response.read(65537))['token']
    access=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'==='))['access']
    need(any(x['name']=='jtmb92/qbit-monitor' and {'pull','push'}<=set(x['actions']) for x in access),'existing_repository_grant_missing')
    url='https://registry-1.docker.io/v2/jtmb92/qbit-monitor/'+reference
    request=urllib.request.Request(url,headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'})
    try:
        with urllib.request.urlopen(request,timeout=30) as response:
            data=response.read(4*1024**2+1);need(len(data)<=4*1024**2,'registry_metadata_bound');digest='sha256:'+hashlib.sha256(data).hexdigest();reported=response.headers.get('Docker-Content-Digest')
            need(not reported or reported==digest,'registry_response_digest');return {'document':json.loads(data),'digest':digest,'bytes':len(data)}
    except urllib.error.HTTPError as error:
        if allow_missing and error.code==404:return None
        raise Refused('registry_metadata_http_'+str(error.code))



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--service', required=True, choices=SERVICES)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    need(args.apply and os.name == 'posix' and os.getuid() == os.getgid() == 1000 and re.fullmatch(r'[0-9a-f]{40}', args.commit), 'explicit_native_operator_scope')
    need('microsoft' in Path('/proc/sys/kernel/osrelease').read_text().lower(), 'wsl_only')
    os.umask(0o077); whole_started = time.monotonic()
    need(BASE.resolve() == BASE and not any((p / '.git').exists() for p in [BASE, *BASE.parents]), 'output_inside_git_or_link')
    BASE.mkdir(mode=0o700, exist_ok=True); s = BASE.lstat(); need(s.st_uid == 1000 and stat.S_IMODE(s.st_mode) == 0o700, 'private_base_identity')
    lock = os.open(BASE/'owned-publisher.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    run_id = uuid.uuid4().hex; root = BASE / (args.service + '-' + args.commit[:12] + '-' + run_id[:12]); root.mkdir(mode=0o700)
    runtime = root
    # A descriptor aliases the SAME owned F directory to satisfy AF_UNIX's path bound.
    socket_dir = root / 'socket'
    socket_dir.mkdir(mode=0o700)
    socket_fd = os.open(socket_dir, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    os.dup2(socket_fd, 200, inheritable=True)
    os.close(socket_fd)
    artifacts = root / 'artifacts'; artifacts.mkdir(mode=0o700)
    for name in ['context', 'state', 'client']: (root / name).mkdir(mode=0o700)
    (root / 'client/.docker').mkdir(mode=0o700); env = safe_env(root / 'client')
    docker = ['docker', '--host', 'unix:///var/run/docker.sock']
    name = 'branconet-owned-publish-' + run_id
    container = None; child = None; capacity_samples = []; cgroup_samples = []
    started = time.monotonic(); receipt = {'schema_version': 1, 'source_kind': 'local-operator', 'state': 'started',
        'run_id': run_id, 'service': args.service, 'source_commit': args.commit, 'started_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'helper_sha256': sha(Path(__file__).resolve()), 'github_actions_or_workflow_identity_claimed': False,
        'deployed': False, 'publication_route': 'existing-dockerhub-jtmb92', 'existing_daemon_builder_or_strata_changed': False,
        'new_builder_stopped': False, 'storage_contract': STORAGE}
    write_new(artifacts / 'started.json', receipt)
    initial_fs = initial_windows = None; seal = None

    def d(*argv, timeout=30): return run(docker + list(argv), env, timeout=timeout)
    def owned():
        need(container is not None, 'owned_container_absent')
        info = json.loads(d('inspect', container))[0]
        labels = info['Config']['Labels']; need(info['Id'] == container and info['Name'] == '/' + name and labels.get('branconet.local-run') == run_id and labels.get('branconet.source-kind') == 'local-operator' and labels.get('branconet.source-commit') == args.commit, 'builder_ownership_changed')
        return info

    def capacity(starting=False):
        fs = filesystem(env, root); w = windows(env)
        docker_fs = json.loads(run(['findmnt', '--json', '--target', '/var/lib/docker', '--output', 'UUID,SOURCE,FSTYPE'], env))['filesystems']
        need(len(docker_fs) == 1 and docker_fs[0]['uuid'] == STORAGE['docker_root_filesystem_uuid'] and docker_fs[0]['fstype'] == 'ext4', 'docker_bootstrap_filesystem_identity')
        need(w['docker_backing_available_bytes'] >= STORAGE['docker_physical_reserve_bytes'] + (STORAGE['docker_mutable_budget_bytes'] if starting else 0), 'docker_bootstrap_physical_reserve')
        docker_bytes = 0
        if container:
            size = json.loads(d('inspect', '--size', container))[0]
            docker_bytes = size['SizeRw']
            need(0 <= docker_bytes <= STORAGE['docker_mutable_budget_bytes'], 'docker_bootstrap_writable_layer_budget')
        fs.update(docker_root_filesystem_uuid=STORAGE['docker_root_filesystem_uuid'], docker_mutable_bytes=docker_bytes)
        if initial_fs:
            need(all(fs[k] == initial_fs[k] for k in ['uuid', 'source', 'device', 'total_bytes']), 'logical_filesystem_changed')
            need(all(w[k] == initial_windows[k] for k in ['backing_file_path', 'backing_drive', 'backing_total_bytes']), 'backing_volume_changed')
        required = RESERVE + (BUILD_BUDGET + OUTPUT_LIMIT if starting else 0)
        need(fs['available_bytes'] >= required and w['backing_available_bytes'] >= required and fs['free_inode_fraction'] >= .10, 'logical_or_physical_capacity_floor')
        need(w['physical_available_bytes'] >= ((3 * GIB + 512 * 1024 ** 2) if starting else 512 * 1024 ** 2), 'windows_physical_memory_floor')
        need(time.monotonic() - whole_started <= 120 * 60 and time.monotonic() - started <= 105 * 60, 'build_deadline')
        if container and owned()['State']['Running']:
            # This counts only this fresh builder's state, not shared Docker data.
            # BuildKit concurrently removes temporary files. Retry this read-only
            # walk on a transient failure; accept only a complete successful walk.
            for allocation_attempt in range(3):
                try:
                    used = d('exec', container, 'sh', '-ec', 'du -skx /var/lib/buildkit', timeout=20).decode().split()
                    break
                except Refused as error:
                    if not str(error).startswith('metadata_command_refused:docker:exec:1') or allocation_attempt == 2:
                        raise
                    time.sleep(.25)
            need(len(used) == 2 and used[0].isdigit(), 'builder_allocation_unavailable')
            allocated = int(used[0]) * 1024
            for folder, dirs, files in os.walk(root):
                if Path(folder) == root:
                    dirs.remove('state')
                    dirs.remove('socket')  # Exact private control socket, never an OCI/source artifact.
                for file in files:
                    p = Path(folder) / file; st = p.lstat(); need(stat.S_ISREG(st.st_mode) and st.st_nlink == 1, 'owned_output_special_file'); allocated += st.st_blocks * 512
            need(allocated <= BUILD_BUDGET, 'fresh_build_allocation_budget')
            fs['fresh_build_allocated_bytes'] = allocated
        for p in [root / 'runtime.oci.partial', artifacts / (args.service + '.oci.tar')]:
            if p.exists(): need(p.is_file() and not p.is_symlink() and p.stat().st_size <= OUTPUT_LIMIT, 'oci_output_bound')
        for p in artifacts.glob('*.log'): need(p.stat().st_size <= 64 * 1024 ** 2, 'log_bound')
        sample = {'elapsed_seconds': round(time.monotonic()-started, 3), 'logical': fs, 'physical': w}
        need(len(capacity_samples) < 4000, 'capacity_sample_bound'); capacity_samples.append(sample)
        return fs, w

    def limits():
        info = owned(); host = info['HostConfig']
        expected = {'Memory': 3 * GIB, 'MemorySwap': 3 * GIB, 'CpuPeriod': 100000,
                    'CpuQuota': 150000, 'CpusetCpus': '0-1', 'PidsLimit': 512, 'CgroupnsMode': 'private', 'Privileged': True}
        need(all(host.get(k) == v for k, v in expected.items()), 'builder_host_limits_changed')
        need(info['Config']['Image'] == BUILDER_IMAGE and not host.get('Binds') and host['RestartPolicy']['Name'] == 'no', 'builder_image_or_restart_changed')
        mounts = {(m['Source'], m['Destination'], m['RW']) for m in info['Mounts']}
        need(mounts == {(str(root/'state'), '/var/lib/buildkit', True), (str(socket_dir), '/run/buildkit', True), (str(root/'buildkitd.toml'), '/etc/buildkit/buildkitd.toml', False)}, 'builder_mount_scope_changed')
        need(info['State']['Running'], 'builder_not_running')
        measured = d('exec', container, 'sh', '-ec', 'cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory.swap.max /sys/fs/cgroup/cpu.max /sys/fs/cgroup/cpuset.cpus.effective /sys/fs/cgroup/pids.max').decode().splitlines()
        need(measured == [str(3*GIB), '0', '150000 100000', '0-1', '512'], 'effective_cgroup_limits_changed')
        path = Path('/proc') / str(info['State']['Pid']) / 'cgroup'
        init_group = path.read_text().strip().split('::', 1)[1]
        parent = '/system.slice/docker-' + container + '.scope'
        need(init_group in [parent, parent + '/init'], 'builder_host_cgroup_identity')
        host_group = Path('/sys/fs/cgroup') / parent.lstrip('/')
        host_limits = [(host_group / key).read_text().strip() for key in
                       ['memory.max', 'memory.swap.max', 'cpu.max', 'cpuset.cpus.effective', 'pids.max']]
        need(host_limits == measured, 'bounded_host_ancestor_limits_changed')
        processes = d('top', container, '-eo', 'pid').decode().splitlines()[1:]; need(0 < len(processes) <= 512, 'builder_process_count')
        observed = 0
        for pid in processes:
            need(pid.strip().isdigit(), 'builder_process_metadata')
            try: cg = (Path('/proc') / pid.strip() / 'cgroup').read_text().strip().split('::', 1)[1]
            except FileNotFoundError: continue
            need(cg == parent or cg.startswith(parent + '/'), 'executor_outside_bounded_ancestor'); observed += 1
        need(observed > 0, 'builder_process_observation_empty')
        sample = {'elapsed_seconds': round(time.monotonic()-started, 3), 'expected': expected,
                  'effective_cgroup_v2': measured, 'host_ancestor_cgroup_v2': host_limits,
                  'ancestor': parent, 'init_cgroup': init_group, 'observed_process_count': observed,
                  'container_id': container, 'image_id': info['Image']}
        need(len(cgroup_samples) < 4000, 'cgroup_sample_bound'); cgroup_samples.append(sample)
        return info

    def stop_owned():
        if container:
            info = owned()
            if info['State']['Running']: d('stop', '--time=10', container, timeout=30)
            need(owned()['State']['Running'] is False, 'own_builder_stop_failed')
            receipt['new_builder_stopped'] = True

    def interrupted(signum, frame): raise Refused('cancelled_or_whole_deadline')
    signal.signal(signal.SIGINT, interrupted); signal.signal(signal.SIGTERM, interrupted); signal.signal(signal.SIGALRM, interrupted); signal.alarm(120 * 60)
    try:
        need(BUILDX_PATH.is_file() and not BUILDX_PATH.is_symlink() and sha(BUILDX_PATH) == BUILDX_SHA, 'installed_buildx_changed')
        version = d('buildx', 'version').decode().strip(); need(' v0.35.0 ' in version, 'installed_buildx_version_changed')
        info = json.loads(d('info', '--format', '{"root":{{json .DockerRootDir}},"version":{{json .ServerVersion}},"driver":{{json .Driver}},"cgroup_version":{{json .CgroupVersion}}}'))
        need(info == {'root': '/var/lib/docker', 'version': '29.6.2', 'driver': 'overlayfs', 'cgroup_version': '2'}, 'audited_docker_runtime_changed')
        need(Path('/var/lib/docker').stat().st_dev == os.stat('/').st_dev and root.stat().st_dev != os.stat('/').st_dev, 'separate_measured_docker_bootstrap_storage')
        initial_fs, initial_windows = capacity(True)
        source = export_commit(args.repo, args.commit, args.service, root/'context', env); seal = manifest(root/'context')
        (root/'client/bin').mkdir(mode=0o700)
        helper_source=Path(__file__).resolve().with_name('windows-docker-credential.py')
        need(helper_source.is_file() and not helper_source.is_symlink(), 'credential_source_missing')
        windows_source=run(['wslpath','-w',str(helper_source)],env).decode().strip()
        launcher=root/'client/bin/docker-credential-branconet-windows'
        launcher.write_text('#!/usr/bin/python3\nimport subprocess,sys\np=subprocess.run('+repr(['/mnt/c/Users/james/AppData/Local/Programs/Python/Python312/python.exe','-I','-B',windows_source])+"+sys.argv[1:],input=sys.stdin.buffer.read(4097),stdout=sys.stdout.buffer,stderr=subprocess.DEVNULL)\nraise SystemExit(p.returncode)\n")
        launcher.chmod(0o700)
        env.update(PATH=str(root/'client/bin')+':'+env['PATH'],TEMP=str(root/'client'),TMP=str(root/'client'),TMPDIR=str(root/'client'),XDG_CACHE_HOME=str(root/'client/cache'),XDG_CONFIG_HOME=str(root/'client/config'))
        write_new(root/'client/.docker/config.json', {'credHelpers':{'https://index.docker.io/v1/':'branconet-windows','registry-1.docker.io':'branconet-windows','docker.io':'branconet-windows'}})
        tag='git-'+args.commit
        need(registry_document('manifests/'+tag,env,root,allow_missing=True) is None,'immutable_tag_already_exists')
        helper = Path(__file__).resolve().read_bytes()
        need(hashlib.sha256(helper).hexdigest() == receipt['helper_sha256'], 'builder_source_changed_before_export')
        with (artifacts/'publish.py').open('xb') as stream: stream.write(helper)
        write_new(artifacts/'source-export.json', source); write_new(artifacts/'recipe-sha256.json', seal)
        with tarfile.open(artifacts/'recipe.tar', 'x') as bundle: bundle.add(root/'context', arcname=args.service)
        (root/'buildkitd.toml').write_text(CONFIG); os.chmod(root/'buildkitd.toml', 0o600)
        # Never implicitly pull via the shared Docker daemon. The reviewed pinned
        # builder image must already be available; root owns bounded provisioning.
        image = json.loads(d('image', 'inspect', BUILDER_IMAGE))[0]
        need(any(x.endswith('@sha256:99368f3e46177c6405b9740e4461d91cee004128daeecca78d4ceac50ec1da5c') for x in image.get('RepoDigests', [])), 'pinned_builder_image_not_cached')
        receipt.update(source=source, buildx_version=version, buildx_sha256=BUILDX_SHA, docker_runtime=info,
                       builder_image_config_digest=image['Id'], buildkit_config_sha256=sha(root/'buildkitd.toml'),
                       resource_contract={'memory_bytes':3*GIB,'swap_bytes':0,'cpu_quota':150000,'cpu_period':100000,'cpuset':'0-1','pids':512,'max_parallelism':2,'cache_bytes':GIB,'build_budget_bytes':BUILD_BUDGET,'reserve_bytes':RESERVE,'max_oci_bytes':OUTPUT_LIMIT,'observation_seconds':105*60,'whole_seconds':120*60})
        argv = ['create', '--pull=never', '--name', name, '--label', 'branconet.local-run='+run_id,
            '--label', 'branconet.source-kind=local-operator', '--label', 'branconet.source-commit='+args.commit,
            '--privileged', '--cgroupns=private', '--memory='+str(3*GIB), '--memory-swap='+str(3*GIB),
            '--cpu-period=100000', '--cpu-quota=150000', '--cpuset-cpus=0-1', '--pids-limit=512', '--restart=no',
            '--network=bridge', '--log-driver=local', '--log-opt=max-size=16m', '--log-opt=max-file=2',
            '--mount', 'type=bind,src='+str(root/'state')+',dst=/var/lib/buildkit',
            '--mount', 'type=bind,src='+str(socket_dir)+',dst=/run/buildkit',
            '--mount', 'type=bind,src='+str(root/'buildkitd.toml')+',dst=/etc/buildkit/buildkitd.toml,readonly',
            '--entrypoint=buildkitd', BUILDER_IMAGE, '--config=/etc/buildkit/buildkitd.toml', '--cdi-disabled']
        container = d(*argv).decode().strip(); need(re.fullmatch(r'[0-9a-f]{64}', container), 'created_builder_id')
        write_new(artifacts/'owned-builder.json', {'id':container,'name':name,'run_id':run_id,'source_kind':'local-operator'})
        d('start', container)
        for attempt in range(90):
            capacity(); limits()
            socket = socket_dir/'local.sock'
            if socket.exists(): need(stat.S_ISSOCK(socket.stat().st_mode), 'control_socket_type'); break
            time.sleep(2)
        else: raise Refused('builder_socket_deadline')
        endpoint = 'unix:///proc/self/fd/200/local.sock'
        d('buildx', 'create', '--name', name, '--driver', 'remote', '--driver-opt', 'default-load=false', endpoint)
        # This instance is in our empty DOCKER_CONFIG; no default builder changes.
        workers = d('exec', container, 'buildctl', '--addr', 'unix:///run/buildkit/local.sock', 'debug', 'workers', '--verbose').decode()
        need('linux/amd64' in workers and
             len(re.findall(r'(?m)^\s*org\.mobyproject\.buildkit\.worker\.executor:\s+oci\s*$', workers)) == 1 and
             re.search(r'(?m)^BuildKit:\s+github\.com/moby/buildkit v0\.34\.1 ', workers),
             'actual_oci_worker_unproven')
        write_new(artifacts/'builder-worker.json', {'stdout':workers,'sha256':hashlib.sha256(workers.encode()).hexdigest()})
        log = artifacts/'build.log'
        image_reference='docker.io/jtmb92/qbit-monitor:'+tag
        argv=docker+['buildx','build','--builder',name,'--platform','linux/amd64','--target','runtime','--file',str(root/'context/dockerfile'),
            '--build-arg','SOURCE_REVISION='+args.commit,'--provenance=false','--sbom=false','--progress=plain',
            '--metadata-file',str(artifacts/'runtime-metadata.json'),'--output','type=image,name='+image_reference+',push=true',str(root/'context')]
        with log.open('xb') as stream:
            child=subprocess.Popen(argv,env=env,stdin=subprocess.DEVNULL,stdout=stream,stderr=subprocess.STDOUT,pass_fds=(200,))
            while child.poll() is None:
                capacity();limits();need(sha(root/'buildkitd.toml')==receipt['buildkit_config_sha256'],'builder_config_changed');time.sleep(2)
            need(child.returncode==0,'owned_build_or_publication_failed');child=None
        capacity();limits();need(manifest(root/'context')==seal,'sealed_source_changed')
        metadata=json.loads((artifacts/'runtime-metadata.json').read_bytes());digest=metadata['containerimage.digest']
        need(re.fullmatch(r'sha256:[0-9a-f]{64}',digest),'published_digest_missing')
        proof=registry_document('manifests/'+tag,env,root)
        need(proof['digest']==digest,'published_tag_digest_changed')
        config=registry_document('blobs/'+proof['document']['config']['digest'],env,root)
        need(config['digest']==proof['document']['config']['digest'],'remote_config_digest')
        labels=config['document']['config'].get('Labels',{})
        need(config['document']['os']=='linux' and config['document']['architecture']=='amd64' and labels.get('org.opencontainers.image.revision')==args.commit and labels.get('org.opencontainers.image.source')=='https://github.com/jtmb/qbit-monitor','published_source_provenance')
        write_new(artifacts/'registry-proof.json',{'manifest':proof,'config':config,'reference':image_reference+'@'+digest,'immutable_tag':tag})
        receipt.update(state='published-not-qualified-not-deployed',published_reference=image_reference+'@'+digest,root_descriptor=metadata.get('containerimage.descriptor'),registry_digest=digest,source_manifest_unchanged=True,builder_config_unchanged=True,credentials_saved_to_disk=False)
        stop_owned()
    except BaseException as error:
        receipt.update(state='failed-no-adoption', error_code=str(error) if isinstance(error, Refused) else type(error).__name__)
        if child is not None and child.poll() is None:
            child.terminate()
            try: child.wait(timeout=15)
            except subprocess.TimeoutExpired: child.kill(); child.wait(timeout=10)
        try: stop_owned()
        except BaseException as stop_error: receipt['own_builder_stop_error_type'] = type(stop_error).__name__
    finally:
        signal.alarm(0)
        receipt.update(completed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(), capacity_samples=capacity_samples, cgroup_samples=cgroup_samples,
                       helper_unchanged=sha(Path(__file__).resolve())==receipt['helper_sha256'])
        if container:
            try:
                # Fixed local log rotation bounds this read; retain failures too.
                captured = subprocess.run(docker + ['logs', '--tail', '100000', container], env=env,
                                          stdin=subprocess.DEVNULL, capture_output=True, timeout=20)
                need(captured.returncode == 0, 'daemon_log_capture_failed')
                logs = captured.stdout + captured.stderr
                need(len(logs) <= 32*1024**2, 'daemon_log_bound')
                with (artifacts/'builder.log').open('xb') as stream: stream.write(logs)
            except Exception as error: receipt['builder_log_capture_error_type'] = type(error).__name__
        if container and receipt.get('new_builder_stopped'):
            try:
                info=owned()
                need(info['State']['Running'] is False and info['State']['Pid']==0,'own_builder_still_active')
                d('rm',container)
                receipt['new_builder_removed']=True
            except BaseException as remove_error:receipt['own_builder_remove_error_type']=type(remove_error).__name__
        need(len(compact(receipt)) <= 16*1024**2, 'local_provenance_bound')
        write_new(artifacts/'local-operator-provenance.json', receipt)
        os.close(lock)
    print(json.dumps({'source_kind':'local-operator','state':receipt['state'],'receipt':str(artifacts/'local-operator-provenance.json')}))
    return 0 if receipt['state']=='published-not-qualified-not-deployed' and receipt['new_builder_stopped'] and receipt['helper_unchanged'] else 1


if __name__ == '__main__':
    try: raise SystemExit(main())
    except Exception as error: raise SystemExit('Local build refused; raw diagnostics withheld ('+type(error).__name__+')')
