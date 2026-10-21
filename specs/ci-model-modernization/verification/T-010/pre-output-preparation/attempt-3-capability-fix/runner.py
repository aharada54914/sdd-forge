"""Same frozen executor; restore only the installed default code_mode_host tool gateway."""
import argparse,importlib.util,json,pathlib,sys
HERE=pathlib.Path(__file__).resolve().parent

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value

def load_executor(source,skill=False):
    source=pathlib.Path(source).resolve()
    if source.name!='inputs' or source.parent.name!='snapshot':raise ValueError('admitted snapshot/inputs required')
    prep=source/'specs/ci-model-modernization/verification/T-010/pre-output-preparation'
    if skill:
        guard=module('attempt2_source_guard',prep/'attempt-2-admission/source-bound-skill-runner.py');guard.check_sources()
        frozen=module('frozen_skill_v5',prep/'skill-comparison-v5/runner.py');executor=frozen.v4.v3
    else:executor=module('frozen_model_v4',prep/'executor-preparation-v4/runner.py').v3
    original=list(executor.DISABLE)
    if original.count('code_mode_host')!=1:raise ValueError('unexpected frozen host feature controls')
    executor.DISABLE=[name for name in original if name!='code_mode_host']
    if set(original)-set(executor.DISABLE)!={'code_mode_host'}:raise ValueError('unexpected capability diff')
    return executor

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',required=True,type=pathlib.Path);p.add_argument('--output',required=True,type=pathlib.Path);p.add_argument('--trial',action='store_true');a=p.parse_args();source=HERE.parents[5];config=json.loads(a.config.read_text());skill=config['case'] in ('cedar','maple')
    if skill and (config['model']!='gpt-6-astra' or config['effort']!='high' or config.get('skill_binding')!='native-skill'):p.error('frozen v5 skill configs required')
    result=load_executor(source,skill).run(config,a.output,a.trial);sys.exit(1 if result['failures'] else 0)
