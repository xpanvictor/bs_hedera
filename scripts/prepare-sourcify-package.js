#!/usr/bin/env node
/*
 Helper: prepare a zipped verification package for Sourcify from a Forge/Foundry `out/.../Contract.json` artifact.
 Usage:
   node scripts/prepare-sourcify-package.js out/Bitsave.sol/Bitsave.json ./sourcify-bitsave.zip

 This will create a zip containing:
 - metadata.json (the artifact.metadata)
 - all source files referenced in metadata.sources with their relative paths

 Note: This uses the system `zip` command to create the zip archive (available on macOS/Linux).
*/

const fs = require('fs');
const path = require('path');
const child = require('child_process');

async function main() {
  const [,, artifactPath, outZip] = process.argv;
  if (!artifactPath || !outZip) {
    console.error('Usage: node scripts/prepare-sourcify-package.js <artifact.json> <out.zip>');
    process.exit(2);
  }

  if (!fs.existsSync(artifactPath)) {
    console.error('Artifact not found:', artifactPath);
    process.exit(3);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  const metadata = artifact.metadata || artifact.json || artifact;
  if (!metadata || !metadata.sources) {
    console.error('Artifact does not appear to contain `metadata.sources`. Is this a Forge artifact?');
    process.exit(4);
  }

  const tmpDir = path.join(process.cwd(), 'sourcify-package-tmp');
  if (fs.existsSync(tmpDir)) child.execSync(`rm -rf ${tmpDir}`);
  fs.mkdirSync(tmpDir, { recursive: true });

  // write metadata.json
  const metaOutPath = path.join(tmpDir, 'metadata.json');
  fs.writeFileSync(metaOutPath, JSON.stringify(metadata, null, 2), 'utf8');

  // copy every source file referenced in metadata.sources
  const sources = Object.keys(metadata.sources);
  for (const srcPath of sources) {
    const localPath = path.resolve(process.cwd(), srcPath);
    if (!fs.existsSync(localPath)) {
      console.warn('Source file not found locally, trying to resolve by stripping leading /:', srcPath);
      const alt = srcPath.replace(/^\//, '');
      if (fs.existsSync(alt)) {
        await copyFile(alt, path.join(tmpDir, srcPath));
        continue;
      }
      console.warn('Missing source:', srcPath, ' — Sourcify may reject this package.');
      continue;
    }
    await copyFile(localPath, path.join(tmpDir, srcPath));
  }

  // create zip using system zip
  try {
    const cwd = process.cwd();
    const zipCmd = `cd ${tmpDir} && zip -r ${path.resolve(cwd, outZip)} .`;
    console.log('Running:', zipCmd);
    child.execSync(zipCmd, { stdio: 'inherit', shell: true });
    console.log('Created', outZip);
  } catch (err) {
    console.error('Failed to create zip:', err.message || err);
    process.exit(5);
  }

  // cleanup temp dir
  // child.execSync(`rm -rf ${tmpDir}`);
}

function copyFile(src, dest) {
  const destDir = path.dirname(dest);
  fs.mkdirSync(destDir, { recursive: true });
  fs.copyFileSync(src, dest);
  return Promise.resolve();
}

main().catch((e)=>{console.error(e); process.exit(1);});
