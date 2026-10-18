from pathlib import Path
import hashlib, json, subprocess, sys
root=Path('/workspace/sdd-forge')
base=Path(sys.argv[1]); revision=sys.argv[2]
def git(path):
 return subprocess.check_output(['git','show',revision+':'+path],cwd=root)
def sha(raw):
 return hashlib.sha256(raw).hexdigest()
catalog_raw=git('tests/verification-catalog.json'); catalog=json.loads(catalog_raw)
records=[]
for profile in ('local-posix','local-powershell'):
 selected=[]
 shard_count=json.loads((base/(profile+'-0.result.json')).read_text())['shard_count']
 assert shard_count in (2,4)
 for index in range(shard_count):
  name=f'{profile}-{index}'
  result=json.loads((base/(name+'.result.json')).read_text())
  raw=(base/(name+'.receipt.json')).read_bytes(); receipt=json.loads(raw)
  assert result['shard_count']==shard_count and result['shard_index']==index
  assert result['revision']==revision and result['exit_code']==0 and result['source_status']=='', result
  assert result['main_ref']==result['main_ref_after']=='fcb8275a42061b8132ea88a36e69b02f4487be71'
  assert result['receipt_sha256']==sha(raw)
  assert receipt['schema']=='verification-receipt/v1' and receipt['profile']==profile
  assert receipt['revision']==receipt['revision_after']==revision
  assert receipt['clean_before'] is True and receipt['clean_after'] is True
  assert receipt['catalog_sha256']==sha(catalog_raw)
  assert [x['suite'] for x in receipt['results']]==receipt['selected']
  for row in receipt['results']:
   assert row['status']=='passed' and row['exit_code']==0, row
   assert row['source_sha256']==sha(git(row['suite'])), row['suite']
  selected+=receipt['selected']
  records.append(dict(profile=profile,shard=index,suites=len(receipt['results']),receipt_sha256=sha(raw),log_sha256=sha((base/(name+'.log')).read_bytes())))
 assert len(selected)==len(set(selected)) and set(selected)==set(catalog['profiles'][profile]), profile
print(json.dumps(dict(revision=revision,status='PASS',scope='Complete current local POSIX and PowerShell profiles; each source pinned, disjoint shards and exact coverage; native Windows/macOS and live cloud acceptance separate.',records=records),indent=2))
