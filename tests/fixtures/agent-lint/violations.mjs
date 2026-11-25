export function riskySample(input) {
  try {
    return JSON.parse(input);
  } catch (err) {}
}

export function evalSample(expr) {
  return eval(expr);
}

export function shellSample(spawnFn) {
  return spawnFn('echo', ['hi'], { shell: true });
}

export function logSample(msg) {
  console.log(msg);
}
