"""Task-local use of installed bubblewrap; no provider, language filter or new sandbox framework."""
import os,pathlib,signal,subprocess,threading
BWRAP='/usr/bin/bwrap'
PRLIMIT='/usr/bin/prlimit'
RUNTIME='/opt/codex/runtimes/codex-primary-runtime/dependencies/python'
PYTHON=RUNTIME+'/bin/python3'

def command(project,python_args,*,checker=None):
    argv=([PRLIMIT,'--as=2147483648','--cpu=300','--nofile=256','--'] if pathlib.Path(PRLIMIT).is_file() else [])
    argv += [BWRAP,'--unshare-user','--unshare-pid','--unshare-net','--unshare-ipc','--unshare-uts','--die-with-parent','--ro-bind','/usr','/usr','--ro-bind','/lib','/lib','--ro-bind','/lib64','/lib64','--ro-bind',RUNTIME,RUNTIME,'--ro-bind',str(pathlib.Path(project).resolve()),'/project','--proc','/proc','--dev','/dev','--tmpfs','/tmp','--clearenv','--setenv','PATH','/usr/bin:/bin','--setenv','LANG','C.UTF-8','--chdir','/project']
    if checker is not None:
        argv += ['--ro-bind',str(pathlib.Path(checker['scorer']).resolve()),'/checker/score.py','--ro-bind',str(pathlib.Path(checker['fixtures']).resolve()),'/checker/inputs']
        if checker.get('answer'):argv+=['--ro-bind',str(pathlib.Path(checker['answer']).resolve()),'/answer.txt']
    return argv+[PYTHON,'-I','-B']+python_args

def execute(argv,remaining,*,environment=None):
    process=subprocess.Popen(argv,env=environment,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
    output=[];overflow=threading.Event()
    def stop():
        try:os.killpg(process.pid,signal.SIGKILL)
        except ProcessLookupError:pass
        process.wait(timeout=2)
    def read():
        data=process.stdout.read(16385);output.append(data[:16384])
        if len(data)>16384:
            overflow.set()
            try:os.killpg(process.pid,signal.SIGKILL)
            except ProcessLookupError:pass
    reader=threading.Thread(target=read,daemon=True);reader.start()
    try:code=process.wait(timeout=max(.01,min(300,remaining)))
    except subprocess.TimeoutExpired:
        stop();return {'success':False,'output':'Public test timeout.'}
    finally:stop();reader.join(timeout=1)
    if overflow.is_set():return {'success':False,'output':'Public test output limit exceeded.'}
    text=b''.join(output).decode(errors='replace')
    return {'success':code==0,'output':text or ('Public test passed.' if code==0 else 'Public test failed.')}
