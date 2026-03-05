import { expect, test } from "@playwright/test";

const COUNTER_VALUE_SELECTOR = '[aria-atomic="true"]';
const CONNECTION_STATUS_SELECTOR = ".webui-status";

const incrementButton = page => page.getByRole("button", { name: "Increment counter" });
const decrementButton = page => page.getByRole("button", { name: "Decrement counter" });
const resetButton = page => page.getByRole("button", { name: "Reset counter" });

async function prepareCounterPage(page, { reset = true } = {}) {
  await page.addInitScript(() => {
    window.__WEBUI_E2E__ = true;
  });

  await page.goto("/counter");
  await waitForConnected(page);

  if (reset) {
    await resetCounter(page);
  }

  await waitForValidCount(page);
}

async function waitForConnected(page) {
  const connectionStatus = page.locator(CONNECTION_STATUS_SELECTOR);
  await expect(connectionStatus).toContainText("Connected", { timeout: 20_000 });
  await expect(incrementButton(page)).toBeEnabled();
}

async function waitForValidCount(page) {
  await expect
    .poll(async () => {
      const value = await readCount(page);
      return Number.isNaN(value) ? null : value;
    })
    .not.toBeNull();
}

async function readCount(page) {
  const raw = await page.locator(COUNTER_VALUE_SELECTOR).innerText();
  return Number.parseInt(raw.trim(), 10);
}

async function waitForCount(page, expected) {
  await expect.poll(async () => readCount(page)).toBe(expected);
}

async function resetCounter(page) {
  await resetButton(page).click();
  await waitForCount(page, 0);
}

test.describe("Counter E2E", () => {
  test.describe.configure({ mode: "serial" });

  test.beforeEach(async ({ page }) => {
    await prepareCounterPage(page);
  });

  test("load/connect/command round-trip/reset", async ({ page }) => {
    await waitForCount(page, 0);

    await incrementButton(page).click();
    await waitForCount(page, 1);

    await decrementButton(page).click();
    await waitForCount(page, 0);

    await incrementButton(page).click();
    await incrementButton(page).click();
    await waitForCount(page, 2);

    await resetButton(page).click();
    await waitForCount(page, 0);
  });

  test("reconnect recovers and resumes sync", async ({ page }) => {
    await incrementButton(page).click();
    await waitForCount(page, 1);

    const closed = await page.evaluate(() => window.__webuiTest.forceCloseSocket());
    expect(closed).toBe(true);

    const connectionStatus = page.locator(CONNECTION_STATUS_SELECTOR);
    await expect(connectionStatus).toContainText(/Disconnected|Reconnecting|Connecting|Error/, {
      timeout: 10_000
    });

    await waitForConnected(page);
    await waitForCount(page, 1);

    await incrementButton(page).click();
    await waitForCount(page, 2);
  });

  test("multi-client synchronization across tabs", async ({ page, context }) => {
    const secondPage = await context.newPage();

    try {
      await prepareCounterPage(secondPage, { reset: false });
      await waitForCount(secondPage, 0);

      await incrementButton(page).click();
      await waitForCount(page, 1);
      await waitForCount(secondPage, 1);

      await decrementButton(secondPage).click();
      await waitForCount(secondPage, 0);
      await waitForCount(page, 0);
    } finally {
      await secondPage.close();
    }
  });

  test("malformed channel payload reports error but UI remains functional", async ({ page }) => {
    const sent = await page.evaluate(() => window.__webuiTest.sendMalformedCloudEvent({ foo: "bar" }));
    expect(sent).toBe(true);

    const alert = page.getByRole("alert");
    await expect(alert).toContainText(/invalid|missing|required|error/i);
    await expect(incrementButton(page)).toBeEnabled();

    await incrementButton(page).click();
    await waitForCount(page, 1);
  });

  test("rapid counter command bursts converge deterministically", async ({ page }) => {
    const burstSize = 30;

    const sent = await page.evaluate(size => {
      for (let i = 0; i < size; i += 1) {
        window.__webuiTest.sendCounterCommand("com.webui.counter.increment");
      }

      return true;
    }, burstSize);

    expect(sent).toBe(true);
    await waitForCount(page, burstSize);
  });
});
