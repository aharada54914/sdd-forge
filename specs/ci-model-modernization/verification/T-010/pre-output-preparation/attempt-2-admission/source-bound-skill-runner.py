"""Frozen v5 runner with the identical two-source guard relocated to admitted immutable inputs."""
import argparse,hashlib,importlib.util,json,pathlib,sys
HERE=pathlib.Path(__file__).resolve().parent
SOURCE=HERE.parents[5]
PREP=SOURCE/'specs/ci-model-modernization/verification/T-010/pre-output-preparation'
LEGACY_ROOT=pathlib.Path('/workspace/sdd-forge')
def check_sources():
    if SOURCE.name!='inputs' or SOURCE.parent.name!='snapshot':raise ValueError('Run only from the admitted readonly snapshot/inputs source root')
    binding=json.loads((PREP/'skill-comparison-v5/source-binding.json').read_text());proof=[]
    for case in ('cedar','maple'):
        relative=pathlib.Path(binding[case]['source']).relative_to(LEGACY_ROOT)
        source=SOURCE/relative
        if source.is_symlink() or not source.resolve().is_relative_to(SOURCE):raise ValueError('source escape')
        actual=hashlib.sha256(source.read_bytes()).hexdigest()
        fixture=hashlib.sha256((PREP/'skill-comparison-v5/inputs'/case/'procedure.md').read_bytes()).hexdigest()
        if actual!=binding[case]['sha256'] or fixture!=actual:raise ValueError('source or fixture changed; freeze a new version')
        proof.append({'case':case,'original_guard_source':str(binding[case]['source']),'isolated_source':str(source),'expected_sha256':binding[case]['sha256'],'actual_sha256':actual,'fixture_sha256':fixture})
    return proof
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=pathlib.Path);p.add_argument('--output',type=pathlib.Path);p.add_argument('--trial',action='store_true');p.add_argument('--check-source-only',action='store_true');a=p.parse_args()
    proof=check_sources()
    if a.check_source_only:print(json.dumps({'source_guard':'same expected hashes, immutable source relocation only','checks':proof}));sys.exit(0)
    if a.config is None or a.output is None:p.error('--config and --output required')
    config=json.loads(a.config.read_text())
    if config['case'] not in ('cedar','maple') or config['model']!='gpt-6-astra' or config['effort']!='high' or config.get('skill_binding')!='native-skill':p.error('Use frozen v5 skill configs only')
    spec=importlib.util.spec_from_file_location('frozen_v5',PREP/'skill-comparison-v5/runner.py');v5=importlib.util.module_from_spec(spec);spec.loader.exec_module(v5)
    result=v5.v4.v3.run(config,a.output,a.trial)
    sys.exit(1 if result['failures'] else 0)
