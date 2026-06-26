import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const astroScript = join(root, "scripts", "astro.mjs");

async function run(args) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [astroScript, ...args], {
      cwd: root,
      stdio: "inherit",
      shell: false,
    });

    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`Astro ${args.join(" ")} failed with code ${code}`));
    });
  });
}

await run(["build"]);

await new Promise((resolve, reject) => {
  const pagefindBin = join(root, "node_modules", "pagefind", "lib", "runner", "bin.cjs");
  const child = spawn(process.execPath, [pagefindBin, "--site", "dist"], {
    cwd: root,
    stdio: "inherit",
    shell: false,
  });

  child.on("exit", (code) => {
    if (code === 0) {
      resolve();
      return;
    }

    reject(new Error(`Pagefind index failed with code ${code}`));
  });
});
