// Shared by the collector, browser and hosted validator; data never contains HTML.
export function validDecisions(rows) {
  const text = v => typeof v === 'string' && v.trim().length > 0 && v.length <= 2000;
  const keys = (v, names) => v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).length === names.length && Object.keys(v).every(k => names.includes(k));
  const id = v => typeof v === 'string' && /^[A-Z][A-Z0-9-]{0,39}$/.test(v);
  const unique = values => new Set(values).size === values.length;
  return Array.isArray(rows) && rows.length <= 100 && rows.every(d =>
    keys(d, ['id','title','problem','status','basis','options','recommended','reason','selected','resolution']) && id(d.id) && text(d.title) && text(d.problem) &&
    ['pending','decided','deferred'].includes(d.status) &&
    Array.isArray(d.basis) && d.basis.length > 0 && d.basis.length <= 10 &&
    d.basis.every(b => keys(b, ['path','sha256']) && typeof b.path === 'string' && /^(requirements|design|ux-spec|frontend-spec|infra-spec|security-spec)\.md$/.test(b.path) && typeof b.sha256 === 'string' && /^[a-f0-9]{64}$/.test(b.sha256)) && unique(d.basis.map(b => b.path)) &&
    Array.isArray(d.options) && d.options.length >= 2 && d.options.length <= 3 &&
    d.options.every(o => keys(o, ['id','title','benefit','drawback','impact','diagram']) && id(o.id) && text(o.title) && text(o.benefit) && text(o.drawback) && text(o.impact) &&
      keys(o.diagram, ['kind','steps']) && ['flow','screen','states'].includes(o.diagram.kind) && Array.isArray(o.diagram.steps) && o.diagram.steps.length > 0 && o.diagram.steps.length <= 8 && o.diagram.steps.every(text)) && unique(d.options.map(o => o.id)) &&
    d.options.some(o => o.id === d.recommended) && text(d.reason) &&
    (d.selected === null || d.options.some(o => o.id === d.selected)) &&
    (d.status === 'decided' ? d.selected !== null && text(d.resolution) : d.selected === null && d.resolution === null)
  ) && unique(rows.map(d => d.id));
}
