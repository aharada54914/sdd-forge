const fs=require('fs'),path=require('path'),crypto=require('crypto');
const base=__dirname,previous=JSON.parse(fs.readFileSync(path.join(base,'../shared-review-launch-repair-T-005-attempt-4/turn-start.json')));
const session=JSON.parse(fs.readFileSync(path.join(base,'native-thread-start-result.json'))).result.thread.id;
const digest=crypto.createHash('sha256').update(fs.readFileSync(path.join(base,'manifest.json'))).digest('hex');
if(session!=='01a11d91-960e-7ac1-b455-e32576ea3fc3'||digest!=='04d8878472be7ef18ad2e9470807c754734602371cbb330a17dd9d9d585a8af4')throw Error('unexpected identity or manifest');
previous.params.threadId=session;
previous.params.input[0].text=previous.params.input[0].text
 .replaceAll('01a11d13-ddd9-7783-9e74-924b17c3b341',session)
 .replaceAll('attempt-4','attempt-5').replace('Task Attempt Count: 4','Task Attempt Count: 5')
 .replaceAll('3587faa97e05ea6a361a115d57735bc940411abebc2c4dedfe1c3d3c88db978d',digest)
 .replace('607 source path+sha256+mode entries','611 source path+sha256+mode entries')
 +'\nAttempt5 revalidates the approved supplemental delivery repair without changing historical attempt4 evidence. Also run tests/supplemental-delivery-declaration.tests.py and relevant admitted isolation regressions. IMPORTANT: the implementation report Scratch Root field must be the canonical absolute realpath of '+path.join(base,'output')+', not a repository-relative path. This is the actual sandbox output root, not a fabricated path. Keep task status unchanged. Record only executed tests; no claim of formal review or CI.';
fs.writeFileSync(path.join(base,'turn-start.json'),JSON.stringify(previous,null,2)+'\n',{flag:'wx'});
