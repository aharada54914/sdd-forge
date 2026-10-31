const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const base = __dirname;
const request = JSON.parse(fs.readFileSync(path.join(base, '../shared-review-launch-repair-T-005-attempt-5/turn-start.json')));
const session = JSON.parse(fs.readFileSync(path.join(base, 'native-thread-start-result.json'))).result.thread.id;
const digest = crypto.createHash('sha256').update(fs.readFileSync(path.join(base, 'manifest.json'))).digest('hex');
if (session !== '01a11dad-e8e2-7e30-b591-b1d3909325e4' || digest !== '7679d7aab07fe28595f547688ed71688845eddab7d01cbd815b07234ddf9ac6a') throw Error('unexpected identity or manifest');
request.params.threadId = session;
request.params.input[0].text = request.params.input[0].text
  .replaceAll('01a11d91-960e-7ac1-b455-e32576ea3fc3', session)
  .replaceAll('attempt-5', 'attempt-6')
  .replaceAll('Task Attempt Count: 5', 'Task Attempt Count: 6')
  .replaceAll('04d8878472be7ef18ad2e9470807c754734602371cbb330a17dd9d9d585a8af4', digest)
  .replaceAll('611 source path+sha256+mode entries', '620 source path+sha256+mode entries')
  + '\nAttempt 6 supplies the missing role/validator inputs and a hash-bound self-contained Git history fixture. The preparation helper reconstructs history only under output/git-history.git. For the review-agent-isolation suite set T005_SOURCE_GIT_ROOT to that absolute path; never read the owner .git. Previous failed results remain historical and must not be promoted. Individual snapshot and batch manifest validation both returned TASK_INPUT_OK in this attempt. Run the required commands yourself and record their actual results.';
fs.writeFileSync(path.join(base, 'turn-start.json'), JSON.stringify(request, null, 2) + '\n', { flag: 'wx' });
