// This project uses the existing Playwright browser library via tests/ui.mjs.
export default { use: { baseURL: 'http://127.0.0.1:4173', launchOptions: { executablePath: '/usr/bin/chromium' } } };
