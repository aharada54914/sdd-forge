import concurrent.futures, hashlib, json, os, pathlib, sys, tempfile
repo=pathlib.Path('/workspace/sdd-a9-recovery')
mode=sys.argv[1]
source=(repo/'tests/spec-review-interrupted-recovery.tests.sh').read_text()
code=source[source.index('import copy,'):source.rindex('\nPY')]
original_argv=sys.argv[:]
sys.argv=['harness',str(repo),'powershell']
namespace={'__name__':'isolation_check'}
exec(compile(code,'embedded-harness','exec'),namespace)
sys.argv=original_argv
before=dict(os.environ)
with tempfile.TemporaryDirectory(prefix='regression-',dir=pathlib.Path(__file__).parent) as temporary:
 root=pathlib.Path(temporary)
 driver=root/'probe.ps1'
 driver.write_text('''[ordered]@{cache=[System.Management.Automation.Platform]::SelectProductNameForDirectory([System.Management.Automation.Platform+XDG_Type]::CACHE);home=$env:HOME;config=$env:XDG_CONFIG_HOME;data=$env:XDG_DATA_HOME} | ConvertTo-Json -Compress\n''')
 roots=[root/'fixture-a',root/'fixture-b']
 for fixture in roots:fixture.mkdir()
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  results=list(pool.map(lambda fixture:namespace['run_driver'](fixture,'probe',(None,driver)),roots))
 values=[json.loads(result.stdout) for result in results]
 caches=[pathlib.Path(value['cache']) for value in values]
 observation={'mode':mode,'harness_sha256':hashlib.sha256(source.encode()).hexdigest(),'child_exits':[r.returncode for r in results], 'cache_paths':[str(p) for p in caches], 'cache_paths_distinct':caches[0]!=caches[1], 'outside_fixture':all(not cache.is_relative_to(fixture) for cache in caches for fixture in roots),'removed_after_exit':all(not p.exists() for p in caches),'parent_environment_unchanged':dict(os.environ)==before,'HOME_config_data_preserved':all(value.get(key)==before.get(envkey) for value in values for key,envkey in [('home','HOME'),('config','XDG_CONFIG_HOME'),('data','XDG_DATA_HOME')])}
 if mode=='after':
  driver.write_text('exit 7\n')
  rejected=namespace['run_driver'](roots[0],'probe',(None,driver))
  observation['nonzero_exit_preserved']=rejected.returncode==7
 observation['isolation_contract_pass']=all([observation['cache_paths_distinct'],observation['removed_after_exit'],observation['parent_environment_unchanged'],observation['HOME_config_data_preserved'],observation['outside_fixture'],all(r.returncode==0 for r in results),observation.get('nonzero_exit_preserved',True)])
 print(json.dumps(observation,indent=2))
 pathlib.Path(__file__).with_name(mode+'-isolation.json').write_text(json.dumps(observation,indent=2)+'\n')
 sys.exit(0 if observation['isolation_contract_pass'] else 1)
