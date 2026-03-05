import { defineConfig, devices } from "@playwright/test";
import path from "node:path";
import { fileURLToPath } from "node:url";

const isCI = Boolean(process.env.CI);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "../../..");

export default defineConfig({
  testDir: "./tests",
  timeout: 45_000,
  expect: {
    timeout: 15_000
  },
  fullyParallel: false,
  forbidOnly: isCI,
  retries: isCI ? 2 : 0,
  workers: isCI ? 1 : undefined,
  reporter: [["list"], ["html", { open: "never", outputFolder: "./reports/html" }]],
  use: {
    baseURL: "http://127.0.0.1:4100",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "off"
  },
  projects: [
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"]
      }
    }
  ],
  webServer: {
    command: "MIX_ENV=dev mix server",
    cwd: path.join(repoRoot, "examples/counter"),
    url: "http://127.0.0.1:4100/counter",
    timeout: 120_000,
    reuseExistingServer: !isCI
  }
});
