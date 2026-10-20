// Rewrites a checked-out Alps tree so its colours, font, title and icon come from
// the site's design tokens. Usage: node theme.mjs <alps-dir> <tokens.css> <favicon.svg> <title>
//
// Alps sets its colours as inline styles on <html> from THEME_BUNDLES at runtime,
// which beats any stylesheet, so the bundles are edited rather than overridden.
import { copyFileSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [alpsDir, tokensPath, faviconPath, title] = process.argv.slice(2);
if (!title) {
  console.error("usage: theme.mjs <alps-dir> <tokens.css> <favicon.svg> <title>");
  process.exit(2);
}

const declarations = (block) =>
  Object.fromEntries(
    block
      .split(";")
      .map((d) => d.split(/:(.*)/s))
      .filter(([name]) => name.trim().startsWith("--"))
      .map(([name, value]) => [name.trim().slice(2), value.trim()]),
  );

const block = (text, pattern) => {
  const found = text.match(pattern);
  if (!found) throw new Error(`${tokensPath}: no match for ${pattern}`);
  return found[1];
};

const css = readFileSync(tokensPath, "utf8");
const light = declarations(block(css, /:root\s*\{([^}]*)\}/));
const dark = {
  ...light,
  ...declarations(
    block(css, /@media\s*\(prefers-color-scheme:\s*dark\)\s*\{\s*:root\s*\{([^}]*)\}/),
  ),
};

const mix = (a, pct, b) => `color-mix(in srgb, ${a} ${pct}%, ${b})`;

// Alps colour key -> value computed from one theme's resolved site tokens. The
// success/warning/error keys keep Alps' own values.
const colors = (t, isDark) => ({
  "bg-primary": t["color-canvas"],
  "bg-secondary": t["color-surface"],
  "bg-tertiary": t["color-code-bg"],
  "bg-selected": mix(t["color-link"], 14, t["color-canvas"]),
  "bg-starred": mix(t["color-link"], 6, "transparent"),
  "text-primary": t["color-text-primary"],
  "text-sender-read": t["color-text-muted"],
  "text-secondary": t["color-text-muted"],
  "text-muted": t["color-text-muted"],
  "border-color": mix(t["color-text-muted"], 25, t["color-canvas"]),
  // The dark link colour is too light to carry white button text; blend it toward the
  // header blue until both the text on it and the button on the page clear ~4.4:1.
  "accent-color": isDark ? mix(t["color-link"], 70, t["color-header-bg"]) : t["color-link"],
  "accent-hover": isDark ? t["color-link"] : t["color-link-hover"],
  "accent-light": mix(t["color-link"], 16, t["color-canvas"]),
  "hover-color": mix(t["color-text-primary"], 7, "transparent"),
});

const edit = (relPath, fn) => {
  const path = join(alpsDir, relPath);
  writeFileSync(path, fn(readFileSync(path, "utf8")));
};

const replaceOnce = (text, pattern, replacement) => {
  const count = (text.match(new RegExp(pattern.source, "g")) ?? []).length;
  if (count !== 1) throw new Error(`expected one match for ${pattern}, found ${count}`);
  return text.replace(pattern, replacement);
};

const setBundleColors = (text, id, values) => {
  const start = text.indexOf(`'${id}': {`);
  const end = text.indexOf("\n  },", start);
  if (start < 0 || end < 0) throw new Error(`bundle not found: ${id}`);
  let block = text.slice(start, end);
  for (const [key, value] of Object.entries(values)) {
    block = replaceOnce(block, new RegExp(`('${key}':\\s*)'[^']*'`), `$1'${value}'`);
  }
  return text.slice(0, start) + block + text.slice(end);
};

edit("frontend/src/store/themes.ts", (text) =>
  setBundleColors(setBundleColors(text, "default-light", colors(light, false)), "default-dark", colors(dark, true)),
);

edit("frontend/src/index.css", (text) =>
  replaceOnce(
    replaceOnce(text, /--font-base:[^;]*;/, `--font-base: ${light["font-sans"]};`),
    /--font-heading:[^;]*;/,
    `--font-heading: ${light["font-sans"]};`,
  ),
);

edit("frontend/index.html", (text) => {
  let out = replaceOnce(text, /<title>[^<]*<\/title>/, `<title>${title}</title>`);
  out = out.replace(/\s*<link rel="(?!icon" type="image\/svg)[^>]*>/g, "");
  return replaceOnce(
    out,
    /(<title>[^<]*<\/title>)/,
    `$1\n  <meta name="theme-color" media="(prefers-color-scheme: light)" content="${light["color-header-bg"]}" />` +
      `\n  <meta name="theme-color" media="(prefers-color-scheme: dark)" content="${dark["color-header-bg"]}" />`,
  );
});

edit("frontend/src/pages/login-page.ts", (text) =>
  replaceOnce(text, /title="Alps"/, `title="${title}"`),
);
edit("frontend/src/components/app-header.ts", (text) =>
  replaceOnce(text, /title="Alps"/, `title="${title}"`),
);

// The favicon becomes the "edelweiss" logo symbol. Its ids are prefixed so they
// cannot collide with the sprite's own, and xlink:href becomes href because the
// sprite declares no xlink namespace.
edit("frontend/public/assets/icons/sprite.svg", (text) => {
  const inner = readFileSync(faviconPath, "utf8")
    .replace(/^[\s\S]*?<svg[^>]*>/, "")
    .replace(/<\/svg>\s*$/, "")
    .replace(/<title[^>]*>[\s\S]*?<\/title>/, "")
    .replace(/xlink:href=/g, "href=")
    .replace(/\b(id|href)="(#?)(head|eyebrow|glasses)"/g, '$1="$2kjiwa-$3"');
  return replaceOnce(
    text,
    /<symbol id="edelweiss"[\s\S]*?<\/symbol>/,
    () => `<symbol id="edelweiss" viewBox="0 0 64 64">${inner}</symbol>`,
  );
});

for (const name of [
  "apple-touch-icon.png",
  "favicon-96x96.png",
  "favicon.ico",
  "site.webmanifest",
  "web-app-manifest-192x192.png",
  "web-app-manifest-512x512.png",
]) {
  rmSync(join(alpsDir, "frontend/public", name));
}
copyFileSync(faviconPath, join(alpsDir, "frontend/public/favicon.svg"));
