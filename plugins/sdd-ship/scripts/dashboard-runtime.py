#!/usr/bin/env python3
"""Per-user, per-environment, per-project loopback dashboard supervisor. No hosted secrets."""
import argparse
import hashlib
import http.server
import json
import os
from pathlib import Path
import queue
import secrets
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.request


def state_directory(root):
    # Host identity also separates a shared home directory mounted by multiple isolated environments.
    identity = str(Path(root).resolve()) + '\0' + socket.gethostname()
    key = hashlib.sha256(identity.encode()).hexdigest()[:24]
    base = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))/'sdd-forge/dashboard'
    base.mkdir(parents=True,exist_ok=True,mode=0o700)
    directory=base/key
    directory.mkdir(mode=0o700,exist_ok=True)
    if directory.is_symlink() or (os.name=='posix' and directory.stat().st_mode & 0o077):
        raise ValueError('state-directory-not-private')
    return directory


def save(path, value):
    tmp=path.with_name(path.name+'.'+secrets.token_hex(4)+'.tmp')
    fd=os.open(tmp,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:json.dump(value,f)
    tmp.replace(path)


def connect(directory, stop=False, publication=None):
    path=directory/'runtime.json'
    if not path.exists() or path.is_symlink():return None
    if os.name=='posix' and path.stat().st_mode & 0o077:raise ValueError('runtime-file-not-private')
    record=json.loads(path.read_text())
    port=record.get('port');token=record.get('token')
    if not isinstance(port,int) or not 1<=port<=65535 or not isinstance(token,str):return None
    route='/publisher' if publication else '/stop' if stop else '/status'
    req=urllib.request.Request('http://127.0.0.1:'+str(port)+route,method='POST' if stop or publication else 'GET',data=json.dumps(publication).encode() if publication else None,headers={'X-SDD-Runtime':token})
    try:
        with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(req,timeout=2) as r:value=json.load(r)
        return value if value.get('identity')==directory.name else None
    except (OSError,ValueError):return None


def run(args,directory):
    # Exclusive lock is held for the lifetime of this supervisor, including child restarts.
    lock_path=directory/'supervisor.lock'
    if lock_path.is_symlink():raise ValueError('invalid-lock')
    lock=open(lock_path,'a+b')
    try:
        if os.name=='posix':
            import fcntl
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        else:
            import msvcrt
            lock.seek(0);lock.write(b'0');lock.flush();lock.seek(0)
            msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
    except OSError:return 0
    stop=threading.Event();token=secrets.token_hex(32)
    state={'identity':directory.name,'root':str(Path(args.root).resolve()),'pid':os.getpid(),'workerPid':None,'url':None,'restarts':0,'state':'starting','version':fingerprint(args)}
    publication=[None]
    state.update(publisherState='unconfigured',publisherPid=None,publisherRestarts=0)
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self,*_):pass
        def answer(self):
            if self.headers.get('Origin') or self.headers.get('Host')!='127.0.0.1:'+str(server.server_port) or not secrets.compare_digest(self.headers.get('X-SDD-Runtime',''),token):
                self.send_error(403);return
            if (self.command,self.path) not in [('GET','/status'),('POST','/stop'),('POST','/publisher')]:self.send_error(404);return
            if self.path=='/publisher':
                try:
                    length=int(self.headers.get('Content-Length','0'))
                    if not 0<length<=32768:raise ValueError('invalid-size')
                    config=json.loads(self.rfile.read(length))
                    validate_publication(config)
                except (ValueError,TypeError):self.send_error(400);return
                publication[0]=config
                state['publisherState']='starting'
            body=json.dumps(state).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
            if self.path=='/stop':stop.set()
        do_GET=answer
        do_POST=answer
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
    save(directory/'runtime.json',{'port':server.server_port,'token':token})
    threading.Thread(target=server.serve_forever,daemon=True).start()
    signal.signal(signal.SIGTERM,lambda *_:stop.set())
    publisher_thread=threading.Thread(target=publish_loop,args=(args,publication,state,stop),daemon=True)
    publisher_thread.start()
    child=None
    try:
        while not stop.is_set():
            env=os.environ.copy();env['SDD_DASHBOARD_STATE']=str(directory)
            child=subprocess.Popen(['node',args.entry,'--root',args.root,'--dashboard'],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,env=env)
            state.update(workerPid=child.pid,url=None,state='starting')
            urls=queue.Queue()
            def read(process):
                for raw in iter(process.stderr.readline,b''):
                    line=raw.decode('utf8','replace')
                    prefix='Read-only status view: '
                    if line.startswith(prefix):urls.put(line[len(prefix):].strip())
            threading.Thread(target=read,args=(child,),daemon=True).start()
            started=time.monotonic();last_probe=0;misses=0
            while not stop.wait(1) and child.poll() is None:
                try:state['url']=urls.get_nowait();state['state']='running'
                except queue.Empty:pass
                if not state['url'] and time.monotonic()-started>60:break
                if state['url'] and time.monotonic()-last_probe>5:
                    last_probe=time.monotonic()
                    try:
                        request=urllib.request.Request(state['url']+'api/runtime-state')
                        with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(request,timeout=10) as response:
                            body=response.read(16*1024*1024+1)
                        if len(body)>16*1024*1024:raise ValueError('state-too-large')
                        observation=json.loads(body)
                        if observation.get('schema')!='sdd-dashboard/v1' or '_observations' not in observation:raise ValueError('invalid-state')
                        save(directory/'observations.json',observation)
                        misses=0
                    except OSError:misses+=1
                    if misses>=2:break
            if child.poll() is None:
                child.terminate()
                try:child.wait(timeout=5)
                except subprocess.TimeoutExpired:child.kill();child.wait()
            child.stderr.close();child=None
            if stop.is_set():break
            state.update(state='restarting',url=None,restarts=state['restarts']+1)
            stop.wait(min(30,2**min(state['restarts'],5)))
    finally:
        if child and child.poll() is None:
            child.terminate()
            try:child.wait(timeout=5)
            except subprocess.TimeoutExpired:child.kill();child.wait()
        stop.set();publisher_thread.join(timeout=10)
        server.shutdown();server.server_close()
        (directory/'runtime.json').unlink(missing_ok=True)
        lock.close()
    return 0


def validate_publication(config):
    if not isinstance(config,dict):raise ValueError('invalid-publication')
    url=urllib.parse.urlparse(config.get('url',''))
    if url.scheme!='https' or not url.netloc or url.username or url.password or url.query or url.fragment or url.path not in ('','/'):raise ValueError('invalid-origin')
    credentials=config.get('credentials')
    if not isinstance(credentials,dict) or set(credentials)!= {'serviceToken','publisherToken'} or not all(isinstance(v,str) and 0<len(v)<=8192 and '\n' not in v and '\r' not in v for v in credentials.values()):raise ValueError('invalid-credentials')


def publish_loop(args,publication,state,stop):
    # Hosted credentials live only in this process and its pipe-fed child, never on disk.
    while not stop.wait(.5):
        config=publication[0]
        if config is None:continue
        process=None
        try:
            process=subprocess.Popen([sys.executable,str(Path(__file__).with_name('publish-dashboard.py')),'--entry',args.entry,'--root',args.root,'--url',config['url'],'--quiet'],stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            process.stdin.write((json.dumps(config['credentials'])+'\n').encode());process.stdin.close()
            state.update(publisherPid=process.pid,publisherState='running')
            while not stop.wait(.5) and publication[0] is config and process.poll() is None:pass
            if process.poll() is not None and publication[0] is config:
                if process.returncode==78:
                    publication[0]=None;state['publisherState']='configuration-required'
                else:
                    state['publisherRestarts']+=1;state['publisherState']='restarting'
        except OSError:
            state['publisherRestarts']+=1;state['publisherState']='restarting'
        finally:
            if process and process.poll() is None:
                process.terminate()
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:process.kill();process.wait()
            state['publisherPid']=None
        if publication[0] is config:stop.wait(min(30,2**min(state['publisherRestarts'],5)))


def fingerprint(args):
    return hashlib.sha256(Path(args.entry).read_bytes()+Path(__file__).read_bytes()+Path(__file__).with_name('publish-dashboard.py').read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['start','run','status','stop','publish'])
    parser.add_argument('--root',required=True)
    parser.add_argument('--url',help='Existing private Site HTTPS origin; publish command only')
    parser.add_argument('--entry',default=str(Path(__file__).resolve().parents[3]/'mcp/sdd-forge-mcp/dist/index.js'))
    args=parser.parse_args();args.root=str(Path(args.root).resolve());args.entry=str(Path(args.entry).resolve())
    if args.command in ('start','run') and (not Path(args.entry).is_file() or not Path(args.root).is_dir()):raise ValueError('missing-runtime-or-project')
    directory=state_directory(args.root)
    if args.command=='run':return run(args,directory)
    if args.command=='publish':
        import importlib.util
        spec=importlib.util.spec_from_file_location('dashboard_publisher',Path(__file__).with_name('publish-dashboard.py'))
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        config={'url':args.url,'credentials':module.credentials_from_stdin()}
        validate_publication(config)
        current=connect(directory,publication=config)
    else:current=connect(directory,args.command=='stop')
    if args.command=='start' and current and current.get('version') != fingerprint(args):
        connect(directory,True)
        for _ in range(30):
            if not connect(directory):break
            time.sleep(.5)
        current=connect(directory)
        if current:raise ValueError('old-runtime-did-not-stop')
    if args.command=='start' and not current:
        flags={'start_new_session':True} if os.name=='posix' else {'creationflags':subprocess.DETACHED_PROCESS|subprocess.CREATE_NEW_PROCESS_GROUP}
        subprocess.Popen([sys.executable,str(Path(__file__).resolve()),'run','--root',args.root,'--entry',args.entry],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,close_fds=True,**flags)
    if args.command=='start':
        for _ in range(90):
            current=connect(directory)
            if current and current.get('url'):break
            time.sleep(.5)
    result=current or {'state':'stopped','identity':directory.name}
    print(json.dumps(result,ensure_ascii=False))
    return 0 if current and (args.command != 'start' or current.get('url')) else 1

if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError):
        print(json.dumps({'error':'runtime-setup-failed'}),file=sys.stderr);sys.exit(1)
