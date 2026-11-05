import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

spec = importlib.util.spec_from_file_location('publisher', Path(__file__).resolve().parents[1] / 'plugins/sdd-ship/scripts/publish-dashboard.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class PublisherTests(unittest.TestCase):
    def test_unsupported_terminal_never_prompts_for_visible_secrets(self):
        with patch.object(p.os, 'name', 'nt'), patch.object(p.sys.stdin, 'isatty', return_value=True):
            with self.assertRaises(ValueError):
                p.credentials_from_stdin()

    def test_failure_classification_and_bounded_backoff(self):
        for code, expected in [(401,'auth-failed'),(403,'auth-failed'),(400,'data-rejected'),(413,'data-rejected'),(409,'conflict'),(503,'http-failed')]:
            self.assertEqual(p.classify(urllib.error.HTTPError('https://example.test',code,'secret',{},None)),expected)
        self.assertEqual(p.classify(urllib.error.URLError('secret')),'transport-failed')
        self.assertEqual([p.backoff(n,lambda:1) for n in [1,2,3,4,20]],[5,10,20,40,60])

    def test_actual_collector_kill_timeout_and_bounded_latest_queue(self):
        with tempfile.TemporaryDirectory() as d:
            entry=Path(d)/'fake.cjs'
            entry.write_text('let i=0;setInterval(()=>console.log(JSON.stringify({i:++i})),20);')
            c=p.Collector(str(entry),d)
            try:
                self.assertGreater(c.sample(2)['i'],0)
                p.time.sleep(.15)
                self.assertGreater(c.sample(2)['i'],2)
                c.process.kill();c.process.wait()
                while not c.items.empty():c.items.get_nowait()
                with self.assertRaises(RuntimeError):c.sample(1)
            finally:c.close()
            entry.write_text('setInterval(()=>{},1000)')
            c=p.Collector(str(entry),d)
            try:
                with self.assertRaises(TimeoutError):c.sample(.1)
            finally:c.close()

    def test_supervision_recovers_collection_and_network_failure_without_leaking_secrets(self):
        from types import SimpleNamespace
        args=SimpleNamespace(entry=__file__,root='.',url='https://example.test',quiet=False,once=False)
        calls=[]
        class Fake:
            version='a'*12
            def __init__(self,*_):self.count=0
            def sample(self):
                self.count+=1
                return {'schema':'sdd-dashboard/v1','lastSuccessAt':p.now(),'error':None,'_collectionMs':20}
            def close(self):pass
        failures=iter([RuntimeError('secret'),None,None,None])
        def sample(self):
            e=next(failures,None)
            if e:raise e
            return {'schema':'sdd-dashboard/v1','lastSuccessAt':p.now(),'error':None,'_collectionMs':20}
        Fake.sample=sample
        def post(opener,origin,path,payload,credentials):
            calls.append((path,dict(payload)))
            if path=='/api/snapshot' and len([x for x in calls if x[0]==path])==1:raise urllib.error.URLError('secret')
            if path=='/api/health' and payload['state']=='running':raise KeyboardInterrupt()
            return {'ok':True}
        out=io.StringIO()
        with patch.object(p,'Collector',Fake),patch.object(p,'post',post),patch.object(p.time,'sleep'),patch('sys.stdout',out):
            with self.assertRaises(KeyboardInterrupt):p.supervise(args,{'serviceToken':'secret','publisherToken':'secret'})
        health=[h for path,h in calls if path=='/api/health']
        self.assertEqual([h['state'] for h in health],['collection-failed','transport-failed','running'])
        self.assertEqual(health[-1]['consecutiveFailures'],0)
        self.assertEqual(health[-1]['collectorRestarts'],1)
        self.assertIsNotNone(health[-1]['lastPublishAt'])
        self.assertNotIn('secret',out.getvalue())

    def test_auth_failure_stops_for_operator_correction(self):
        from types import SimpleNamespace
        args=SimpleNamespace(entry=__file__,root='.',url='https://example.test',quiet=True,once=False)
        class Fake:
            version='a'*12
            def __init__(self,*_):pass
            def sample(self):return {'schema':'sdd-dashboard/v1','error':None}
            def close(self):pass
        error=urllib.error.HTTPError(args.url,401,'do-not-log',{},None)
        with patch.object(p,'Collector',Fake),patch.object(p,'post',side_effect=error),patch('sys.stdout',io.StringIO()) as out:
            self.assertEqual(p.supervise(args,{}),78)
        self.assertNotIn('do-not-log',out.getvalue())

    def test_no_redirect_for_credentials(self):
        self.assertIsNone(p.NoRedirect().redirect_request(None,None,302,'',{},'https://other.test'))

if __name__=='__main__':unittest.main()
