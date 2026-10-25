"use strict";

// Renders the configured limits in the admin page.
function renderLimits(limits) {
  return Object.entries(limits)
    .map(([name, value]) => `${name}: ${value}`)
    .join("\n");
}

module.exports = { renderLimits };
