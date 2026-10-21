"""Deterministic local scorer. Execute untrusted implementation only inside an OS boundary."""
import argparse, copy, hashlib, importlib.util, json, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parent

def hashes(path):
    return {str(p.relative_to(path)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(path.rglob('*')) if p.is_file()}

def citations(items, project):
    for item in items:
        path = pathlib.PurePosixPath(item['path'])
        assert not path.is_absolute() and '..' not in path.parts, 'unsafe citation'
        lines = (project/path).read_text().splitlines()
        assert type(item['line']) is int and 1 <= item['line'] <= len(lines), 'nonexistent line'
        assert item['observed'] == lines[item['line']-1].strip(), 'inexact source quote'

def score_text(case, project, answer):
    if case in ('orchard','meadow'):
        items = answer['findings']; citations(items, project)
        expected = {2,4,11} if case == 'orchard' else set()
        assert {x['line'] for x in items} == expected and len(items)==len(expected), 'missing, duplicate or invented finding'
        terms = {2:('stale','fresh','account'),4:('availab','account','access'),11:('actual','configur','identity','telemetry')}
        for item in items:
            assert any(t in item['impact'].lower() for t in terms[item['line']]), 'missing concrete impact'
    elif case == 'willow':
        citations(answer['trace'],project)
        evidence = {(x['path'],x['line']) for x in answer['trace']}
        assert {('selector.py',2),('launcher.py',6),('launcher.py',7),('launcher.py',8),('records.py',2)} <= evidence, 'incomplete trace'
        assert all(x.get('reason','').strip() for x in answer['trace']), 'unexplained trace'
        identity = answer['identity'].lower()
        assert 'configur' in identity and 'actual' in identity and any(t in identity for t in ('cannot','unknown','unverified','absent','omit')), 'identity limitation missing'
    else:
        commands='\n'.join(answer['commands'])
        for token in ('managed-model-entry.py prepare','--role spec-reviewer','--host claude-code','--request policy.json','--registry registry.json','--run-id 00000000-0000-4000-8000-000000000001','--session-id 00000000-0000-4000-8000-000000000001','--attempt 1','--output-dir','--require-actual-id false','validation.json','controls','sha256','launch-impl-review.py','--model-controls','--model-controls-sha256'):
            assert token in commands, 'missing protected command contract: '+token
        assert commands.index('managed-model-entry.py prepare') < commands.index('launch-impl-review.py'), 'wrong order'
        assert '|| exit' in commands or 'set -e' in commands, 'preparation failure can continue'
        assert 'actual' in answer['identity'].lower() and any(t in answer['identity'].lower() for t in ('unverified','cannot','unknown')), 'identity limitation missing'
    return {'status':'deterministic-pass','semantic_review':'required for natural-language consequences/command execution equivalence; no model judge run'}

def implementation(project):
    # This function intentionally executes source; caller must supply independently isolated OS sandbox for native outputs.
    spec=importlib.util.spec_from_file_location('candidate_selector',project/'selector.py')
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    catalog=[{'id':'spruce','tier':1,'roles':['build']},{'id':'elm','tier':2,'roles':['build','review']},{'id':'oak','tier':3,'roles':['review']}]
    req={'role':'build','floor':1}; obs={'fresh':True,'available':['spruce','elm']}
    rows=[('public',{}, {}, None,'spruce'),('unavailable',{'preferred':'spruce'},{'available':['elm']},None,'elm'),('unknown-preference',{'preferred':'ghost'},{},None,'spruce'),('floor',{'floor':2},{},None,'elm'),('pin-valid',{'pinned':'elm'},{},None,'elm'),('pin-unknown',{'pinned':'ghost'},{},None,ValueError),('pin-unavailable',{'pinned':'spruce'},{'available':['elm']},None,ValueError),('pin-below-floor',{'pinned':'spruce','floor':2},{},None,ValueError),('pin-precedence',{'pinned':'elm','preferred':'spruce'},{},None,'elm'),('stale',{}, {'fresh':False},None,ValueError),('role',{'role':'review'},{},None,'elm'),('unknown-only',{}, {'available':['ghost']},None,ValueError)]
    for field,value in [('floor',True),('floor',-1),('floor','2'),('role',''),('preferred',3),('pinned','')]: rows.append(('malformed-'+field,{field:value},{},None,ValueError))
    rows.extend([('malformed-shadowed',{'pinned':'elm','preferred':[]},{},None,ValueError),('malformed-unselected',{}, {}, catalog+[{'id':'bad','tier':True,'roles':['build']}],ValueError),('duplicate',{}, {},catalog+[catalog[0]],ValueError),('malformed-observation',{}, {'fresh':'yes'},None,ValueError),('malformed-available',{}, {'available':['spruce',4]},None,ValueError),('compatible-extra',{'extra':42},{'extra':42},None,'spruce')])
    results=[]
    for name,r,o,c,expected in rows:
        args=(dict(req,**r),copy.deepcopy(c if c is not None else catalog),dict(obs,**o)); original=copy.deepcopy(args)
        try:
            actual=module.select(*args)
        except ValueError:
            assert expected is ValueError, name+': unexpected rejection'
        else:
            assert expected is not ValueError and actual==expected, name+': wrong selection'
        assert args==original,name+': input mutated'
        results.append(name)
    for malformed in [(None,catalog,obs),(req,None,obs),(req,catalog,None),(req,[None],obs)]:
        try: module.select(*malformed)
        except ValueError: pass
        else: raise AssertionError('malformed outer input accepted')
    return {'status':'deterministic-pass','assertions':results,'outer_shape_rejections':4}

def score(case, project, answer=None):
    baseline=hashes(ROOT/'inputs'/case); after=hashes(project)
    allowed={'selector.py'} if case=='harbor' else set()
    assert {k for k in baseline.keys()|after.keys() if baseline.get(k)!=after.get(k)} <= allowed,'unauthorized artifact write'
    return implementation(project) if case=='harbor' else score_text(case, project,json.loads(answer.read_text()))

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('case',choices=['harbor','orchard','meadow','willow','cedar','maple']); parser.add_argument('project',type=pathlib.Path); parser.add_argument('--answer',type=pathlib.Path)
    args=parser.parse_args()
    try: result=score(args.case,args.project,args.answer)
    except (AssertionError,KeyError,ValueError,TypeError,IndexError,FileNotFoundError) as exc: result={'status':'fail','reason':str(exc)}
    print(json.dumps(result,indent=2)); sys.exit(0 if result['status']=='deterministic-pass' else 1)
