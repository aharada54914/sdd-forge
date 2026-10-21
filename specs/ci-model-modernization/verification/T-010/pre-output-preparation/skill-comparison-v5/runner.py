"""Skill-only input binding extension; unchanged frozen v4 transport/public-tool executor."""
import argparse,hashlib,importlib.util,json,pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parent
BASE=ROOT.parent
spec=importlib.util.spec_from_file_location('executor_v4',BASE/'executor-preparation-v4/runner.py')
v4=importlib.util.module_from_spec(spec);spec.loader.exec_module(v4)

def load_input(case):
    if case not in ('cedar','maple'):raise ValueError('v5 is skill-only; model arms remain v4')
    project=ROOT/'inputs'/case
    files={str(p.relative_to(project)):p.read_text() for p in project.rglob('*') if p.is_file() and not p.is_symlink()}
    return files,(BASE/'requests/skill.txt').read_text()

v4.v3.load_input=load_input
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',required=True,type=pathlib.Path);p.add_argument('--output',required=True,type=pathlib.Path);p.add_argument('--trial',action='store_true',help='Await Root authorization after T-008 Done.');a=p.parse_args()
    config=json.loads(a.config.read_text())
    if config['case'] not in ('cedar','maple') or config['model']!='gpt-6-astra' or config['effort']!='high' or config.get('skill_binding')!='native-skill':p.error('Use the frozen v5 skill configs only.')
    binding=json.loads((ROOT/'source-binding.json').read_text())
    for case in ('cedar','maple'):
        source=pathlib.Path(binding[case]['source'])
        if hashlib.sha256(source.read_bytes()).hexdigest()!=binding[case]['sha256']:p.error('Root source changed since v5 snapshot; freeze a new version before outputs.')
    result=v4.v3.run(config,a.output,a.trial)
    sys.exit(1 if result['failures'] else 0)
