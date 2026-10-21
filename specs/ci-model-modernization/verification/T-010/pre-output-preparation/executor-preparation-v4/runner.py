"""v3 protocol runner with only its public-test executor replaced by installed bubblewrap."""
import argparse,importlib.util,json,pathlib,sys,tempfile
ROOT=pathlib.Path(__file__).resolve().parent
BASE=ROOT.parent
sys.path.insert(0,str(ROOT))
from isolation import command,execute
spec=importlib.util.spec_from_file_location('executor_v3',BASE/'executor-preparation-v3/runner.py')
v3=importlib.util.module_from_spec(spec);spec.loader.exec_module(v3)

def public_checks(files,remaining):
    if set(files)!={'README.md','selector.py','test_selector.py'} or files['test_selector.py']!=(BASE/'inputs/harbor/test_selector.py').read_text():
        return {'success':False,'output':'Public test inputs differ from supplied fixture.'}
    with tempfile.TemporaryDirectory(prefix='harbor-',dir='/workspace/.task-scratch') as temp:
        for name,text in files.items():(pathlib.Path(temp)/name).write_text(text)
        argv=command(temp,['-c','import runpy,sys; sys.path.insert(0,"/project"); runpy.run_path("/project/test_selector.py",run_name="__main__")'])
        return execute(argv,remaining,environment={'PATH':'/usr/bin:/bin','LANG':'C.UTF-8'})

v3.public_checks=public_checks
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',required=True,type=pathlib.Path);p.add_argument('--output',required=True,type=pathlib.Path);p.add_argument('--trial',action='store_true',help='Actual model turn; await Root followup after T-008 Done.');a=p.parse_args()
    result=v3.run(json.loads(a.config.read_text()),a.output,a.trial)
    sys.exit(1 if result['failures'] else 0)
