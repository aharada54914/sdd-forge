// One conditional R2 write commits the snapshot and its derived observation history together.
const RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
const EVENT_LIMIT = 200;
function publicSnapshot(value) {
  if (!value) return value;
  const {_observations, ...snapshot} = value;
  return snapshot;
}
export function observe(old, next) {
  const previous = old?._observations;
  const at = next.attemptedAt;
  const cutoff = Date.parse(at) - RETENTION_MS;
  const events = (previous?.events || []).filter(e => Date.parse(e.observedAt) >= cutoff).slice(-EVENT_LIMIT);
  const tracking = Object.create(null);
  function emit(kind, task, field, before, after, notify = false) {
    events.push({id:at + ':' + kind + ':' + (task?.key || '') + ':' + field,
      observedAt:at, kind, key:task?.key || null, feature:task?.feature || null,
      title:task ? task.title.slice(0,300) : '', field, before, after, notify});
    if (events.length > EVENT_LIMIT) events.shift();
  }
  if (Boolean(old?.error) !== Boolean(next.error)) emit(next.error?'source-failed':'source-recovered',null,'source',old?.error?'failed':'ok',next.error?'failed':'ok',true);
  if (next.error || !next.data) return {events,tracking:previous?.tracking || {},startedAt:previous?.startedAt || at};
  const oldTasks = new Map((old?.data?.tasks || []).map(t => [t.key,t]));
  const gap = !!old?.checkedAt && (Date.parse(next.checkedAt)-Date.parse(old.checkedAt)>60000 || !!old.error);
  if (gap) emit('observation-gap',null,'continuity','unknown','resumed',true);
  for (const task of next.data.tasks) {
    const prior = oldTasks.get(task.key);
    const remembered = previous?.tracking?.[task.key];
    const changed = !prior || prior.status !== task.status;
    tracking[task.key] = {since:!gap && !changed && remembered ? remembered.since : next.checkedAt,
      lastObservedAt:next.checkedAt, reason:gap?'gap':changed&&prior?'status-change':remembered?.reason || 'first-observation'};
    if (!prior) {
      emit(old?.data?'added':'first-observed',task,'status',null,task.status,task.status==='Blocked'||task.approval==='Draft'||task.status==='Implementation Complete'||task.failures.length>0);
    } else {
      for (const field of ['status','approval','risk','release']) {
        if (prior[field] !== task[field]) emit('changed',task,field,prior[field],task[field],field==='status'||field==='approval');
      }
      if (JSON.stringify(prior.failures) !== JSON.stringify(task.failures)) emit('changed',task,'validation',prior.failures.length,task.failures.length,true);
    }
    oldTasks.delete(task.key);
  }
  for (const task of oldTasks.values()) emit('removed',task,'status',task.status,null,true);
  return {events,tracking,startedAt:previous?.startedAt || at};
}
export function observationView(stored, now=Date.now()) {
  const state=stored?._observations;
  const events=(state?.events || []).filter(e => Date.parse(e.observedAt)>=now-RETENTION_MS);
  return {schema:'sdd-observations/v1',snapshotRevision:stored?.revision || '',observedAt:stored?.attemptedAt || null,
    startedAt:state?.startedAt || null,retentionDays:30,eventLimit:EVENT_LIMIT,events,
    tracking:state?.tracking || {},sourceStale:!stored?.checkedAt || now-Date.parse(stored.checkedAt)>60000,
    sourceError:!!stored?.error};
}
