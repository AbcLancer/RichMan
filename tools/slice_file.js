// Print a numbered source excerpt without shell-specific quoting rules.
const fs = require('fs');
const [path, first, last] = process.argv.slice(2);
const lines = fs.readFileSync(path, 'utf8').split(/\r?\n/);
for (let i = Number(first) - 1; i < Math.min(Number(last), lines.length); i++) {
  console.log(`${i + 1}: ${lines[i]}`);
}
