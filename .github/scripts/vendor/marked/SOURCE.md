# Marked for release checks

The release tools use the lexer from `marked@18.3.0` to distinguish Markdown headings from code and HTML. The checked-in ESM build keeps the offline release tests usable on a clean checkout with Node 20.

The npm tarball has integrity `sha512-ed8zmPXlBb3UfGXN5iHMQyMhFpdqLgoV5umUXx/Q1R+FW3q8VpqpyoKUwlENL9appo2UMvNLURDVaT3AMOryGA==`. Run `npm pack --ignore-scripts marked@18.3.0` to retrieve it. The files `package/lib/marked.esm.js` and `package/LICENSE` are copied verbatim to `marked.mjs` and `LICENSE`. [Upstream source](https://github.com/markedjs/marked/tree/v18.3.0)
