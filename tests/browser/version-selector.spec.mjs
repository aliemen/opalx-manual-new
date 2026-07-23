import { expect, test } from "@playwright/test";

const dualPage = "/user-guide/beam-distributions.html";

test.beforeEach(async ({ page }) => {
  await page.goto("/user-guide/input-language.html");
  await page.evaluate(() => localStorage.clear());
});

test("defaults to OPALX and switches among all modes", async ({ page }) => {
  await page.goto(dualPage);

  const opalx = page.locator(".feature-opalx").first();
  const opal = page.locator(".feature-opal").first();
  await expect(page.getByRole("radio", { name: "OPALX", exact: true })).toBeChecked();
  await expect(opalx).toBeVisible();
  await expect(opal).toBeHidden();

  await page.getByRole("radio", { name: "OPAL", exact: true }).check();
  await expect(opalx).toBeHidden();
  await expect(opal).toBeVisible();

  await page.getByRole("radio", { name: "Both", exact: true }).check();
  await expect(opalx).toBeVisible();
  await expect(opal).toBeVisible();
});

test("persists independently of theme and sidebar state", async ({ page }) => {
  await page.goto(dualPage);
  await page.getByRole("radio", { name: "OPAL", exact: true }).check();

  const chapterToggle = page.getByRole("button", {
    name: "Toggle Beam and Distributions sections"
  });
  await chapterToggle.click();
  await expect(chapterToggle).toHaveAttribute("aria-expanded", "true");

  await page.evaluate(() => localStorage.setItem("quarto-color-scheme", "alternate"));
  await page.goto("/user-guide/field-solver/index.html");
  await expect(page.getByRole("radio", { name: "OPAL", exact: true })).toBeChecked();
  await expect.poll(() => page.evaluate(() => localStorage.getItem("quarto-color-scheme")))
    .toBe("alternate");

  await page.goto(dualPage);
  await expect(chapterToggle).toHaveAttribute("aria-expanded", "true");
  const stored = await page.evaluate(() => JSON.parse(localStorage.getItem("opalx-sidebar-state-v1")));
  expect(stored["page-toc:beam-distributions"]).toBe(true);
});

test("omits the selector from a shared page", async ({ page }) => {
  await page.goto("/user-guide/input-language.html");
  await expect(page.locator(".opal-version-selector")).toHaveCount(0);
});

test("makes custom and margin TOCs version-aware", async ({ page }) => {
  await page.goto(dualPage);
  await page.getByRole("button", {
    name: "Toggle Beam and Distributions sections"
  }).click();
  await expect(page.locator('[data-opalx-toc-anchor="opal-distribution-units"]')).toBeHidden();
  await expect(page.locator('[data-opalx-toc-anchor="emissionsource"]')).toBeVisible();

  await page.getByRole("radio", { name: "OPAL", exact: true }).check();
  await expect(page.locator('[data-opalx-toc-anchor="opal-distribution-units"]')).toBeVisible();
  await expect(page.locator('[data-opalx-toc-anchor="emissionsource"]')).toBeHidden();
});

test("reveals a directly linked hidden variant", async ({ page }) => {
  await page.goto(`${dualPage}#opal-distribution-binomial`);
  await expect(page.getByRole("radio", { name: "OPAL", exact: true })).toBeChecked();
  await expect(page.locator("#opal-distribution-binomial")).toBeVisible();
});

test("supports keyboard selection and a narrow viewport", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(dualPage);

  const opalxRadio = page.getByRole("radio", { name: "OPALX", exact: true });
  await opalxRadio.focus();
  await opalxRadio.press("ArrowRight");
  await expect(page.getByRole("radio", { name: "OPAL", exact: true })).toBeChecked();

  const box = await page.locator(".opal-version-selector").boundingBox();
  expect(box).not.toBeNull();
  expect(box.x).toBeGreaterThanOrEqual(0);
  expect(box.x + box.width).toBeLessThanOrEqual(390);
});
