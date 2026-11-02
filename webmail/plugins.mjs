// Copies webmail/plugins/* into a checked-out Alps tree and registers each Go package in
// cmd/alps/plugins.go. A plugin's icons.svg holds <symbol>s appended to the icon sprite.
// Usage: node plugins.mjs <alps-dir>
import { cpSync, existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const [alpsDir] = process.argv.slice(2);
if (!alpsDir) {
  console.error("usage: plugins.mjs <alps-dir>");
  process.exit(2);
}

const pluginsDir = join(dirname(fileURLToPath(import.meta.url)), "plugins");
const registry = join(alpsDir, "cmd/alps/plugins.go");
const sprite = join(alpsDir, "frontend/public/assets/icons/sprite.svg");
const anchor = '\t_ "github.com/migadu/alps/plugins/gpg"\n';

let text = readFileSync(registry, "utf8");
let symbols = readFileSync(sprite, "utf8");
if (!text.includes(anchor)) throw new Error(`${registry}: import anchor not found: ${anchor.trim()}`);

for (const name of readdirSync(pluginsDir)) {
  cpSync(join(pluginsDir, name), join(alpsDir, "plugins", name), { recursive: true });
  const icons = join(pluginsDir, name, "icons.svg");
  if (existsSync(icons)) symbols = symbols.replace("</svg>", `${readFileSync(icons, "utf8")}</svg>`);
  text = text.replace(anchor, `\t_ "github.com/migadu/alps/plugins/${name}"\n${anchor}`);
}
writeFileSync(registry, text);
writeFileSync(sprite, symbols);
