import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "tests/browser",
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? "github" : "line",
  use: {
    baseURL: "http://127.0.0.1:4173",
    browserName: "chromium",
    channel: "chrome",
    trace: "retain-on-failure"
  },
  webServer: {
    command: "python3 -m http.server 4173 --directory _site",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: !process.env.CI
  }
});
