// Screenshots every key page at phone and desktop widths in light and dark,
// enforcing the production CSP so script/style regressions surface as console errors.
//
// usage: PLAYWRIGHT_MODULE=/path/to/playwright/index.mjs \
//        node scripts/screenshots.mjs <built-site-dir> <out-dir>
import { mkdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";

const [siteDir, outDir] = process.argv.slice(2);
if (!siteDir || !outDir) {
  console.error("usage: screenshots.mjs <built-site-dir> <out-dir>");
  process.exit(2);
}

const PAGES = {
  home: "/~kjiwa/",
  dos: "/~kjiwa/2010/09/dos-boot-sector.html",
  james: "/~kjiwa/2016/06/exploiting-apache-james-2.3.2.html",
  slides: "/~kjiwa/2016/11/software-job-search.html",
  notfound: "/~kjiwa/404.html",
};
const VIEWPORTS = { phone: { width: 393, height: 852 }, desktop: { width: 1440, height: 900 } };
const SCHEMES = ["light", "dark"];
const MIME = {
  ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript",
  ".png": "image/png", ".webp": "image/webp", ".svg": "image/svg+xml", ".woff2": "font/woff2",
  ".xml": "application/xml", ".txt": "text/plain",
};

const csp = readFileSync(new URL("../terraform/cloudfront.tf", import.meta.url), "utf8")
  .match(/content_security_policy\s*=\s*"([^"]+)"/)[1];

function resolveFile(urlPath) {
  const clean = normalize(decodeURIComponent(urlPath.split("?")[0])).replace(/^(\.\.[/\\])+/, "");
  let file = join(siteDir, clean);
  if (existsSync(file) && statSync(file).isDirectory()) file = join(file, "index.html");
  return existsSync(file) ? file : null;
}

const base = "https://crimsonglow.test";

// Serves siteDir through request interception, so no local port is needed.
async function serveSite(context) {
  await context.route(`${base}/**`, (route) => {
    const file = resolveFile(new URL(route.request().url()).pathname);
    const target = file ?? join(siteDir, "~kjiwa/404.html");
    route.fulfill({
      status: file ? 200 : 404,
      body: readFileSync(target),
      headers: {
        "content-type": MIME[extname(target)] ?? "application/octet-stream",
        "content-security-policy": csp,
      },
    });
  });
}

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || "playwright");
const browser = await chromium.launch();
mkdirSync(outDir, { recursive: true });

let problems = 0;
for (const [name, path] of Object.entries(PAGES)) {
  if (name !== "notfound" && !resolveFile(path)) continue;
  for (const [vpName, viewport] of Object.entries(VIEWPORTS)) {
    for (const scheme of SCHEMES) {
      const context = await browser.newContext({ viewport, colorScheme: scheme });
      await serveSite(context);
      const page = await context.newPage();
      const messages = [];
      page.on("console", (m) => m.type() === "error" && messages.push(m.text()));
      page.on("pageerror", (e) => messages.push(String(e)));
      await page.goto(base + path, { waitUntil: "load" });
      await page.evaluate(() => document.fonts.ready);
      await page.evaluate(async () => {
        for (let y = 0; y < document.body.scrollHeight; y += innerHeight) {
          scrollTo({ top: y, behavior: "instant" });
          await new Promise((r) => setTimeout(r, 60));
        }
        scrollTo({ top: 0, behavior: "instant" });
        await Promise.race([
          Promise.all([...document.images].map((i) => i.decode().catch(() => {}))),
          new Promise((r) => setTimeout(r, 3000)),
        ]);
      });
      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth - document.documentElement.clientWidth
      );
      const misaligned = await page.evaluate(() => {
        const lines = new Map();
        for (const el of document.querySelectorAll(".path li > *")) {
          const r = el.getBoundingClientRect();
          const key = Math.round(el.closest("li").getBoundingClientRect().top);
          const centers = lines.get(key) ?? [];
          centers.push(r.top + r.height / 2);
          lines.set(key, centers);
        }
        return [...lines.values()].filter((c) => Math.max(...c) - Math.min(...c) > 1).length;
      });
      if (misaligned) messages.push(`breadcrumb misaligned on ${misaligned} line(s)`);
      await page.screenshot({ path: join(outDir, `${name}-${vpName}-${scheme}.png`), fullPage: true });
      if (messages.length || overflow > 0) {
        problems += 1;
        console.error(`${name} ${vpName} ${scheme}: overflow=${overflow}px`, messages);
      }
      await context.close();
    }
  }
}
await browser.close();
console.log(problems ? `${problems} page(s) with problems` : "no console errors or horizontal overflow");
process.exit(problems ? 1 : 0);
