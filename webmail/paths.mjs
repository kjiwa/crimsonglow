// Re-encodes the path segments a checked-out Alps tree builds for mailbox names and
// DAV object paths. Usage: node paths.mjs <alps-dir>
//
// Alps encodes such a segment twice so a "/" survives Go's ServeMux decoding. API
// Gateway decodes the path once more before the Lambda sees it, so a third layer is
// needed or "[Gmail]/All Mail" splits into two segments and 404s.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [alpsDir] = process.argv.slice(2);
if (!alpsDir) {
  console.error("usage: paths.mjs <alps-dir>");
  process.exit(2);
}

const doubleEncoded = /return encodeURIComponent\(encodeURIComponent\((\w+)\)\);/g;

for (const relPath of ["frontend/src/utils/folders.ts", "frontend/src/utils/fetch-utils.ts"]) {
  const path = join(alpsDir, relPath);
  const text = readFileSync(path, "utf8");
  const count = (text.match(doubleEncoded) ?? []).length;
  if (count !== 1) throw new Error(`${relPath}: expected one double-encoding, found ${count}`);
  writeFileSync(
    path,
    text.replace(doubleEncoded, "return encodeURIComponent(encodeURIComponent(encodeURIComponent($1)));"),
  );
}
