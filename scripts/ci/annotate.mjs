/**
 * Turns `flutter analyze` / `flutter test` output into GitHub workflow
 * annotations, so every Dart error shows up in the run's Annotations box with
 * its file and line — instead of a lone "Process completed with exit code 1".
 *
 *   node scripts/ci/annotate.mjs analyze analyze.txt
 *   node scripts/ci/annotate.mjs test    test.txt
 */
import { readFileSync } from 'node:fs';

const [, , mode, file] = process.argv;
if (!mode || !file) {
  console.error('usage: annotate.mjs <analyze|test> <file>');
  process.exit(2);
}

let text = '';
try {
  text = readFileSync(file, 'utf8');
} catch {
  console.log(`::notice::${file} not produced — nothing to annotate.`);
  process.exit(0);
}

/** GitHub only renders ~10 annotations of each level per step. */
const CAP = 10;

function esc(s) {
  return s.replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
}

function annotateAnalyze(out) {
  // "  error • message • lib/foo.dart:12:34 • rule_name"
  const line = /^\s*(error|warning|info)\s+•\s+(.+?)\s+•\s+(\S+?):(\d+):(\d+)\s+•\s+(\S+)\s*$/;
  const found = { error: [], warning: [], info: [] };

  for (const raw of out.split('\n')) {
    const m = raw.match(line);
    if (m) found[m[1]].push({ msg: m[2], file: m[3], line: m[4], col: m[5], rule: m[6] });
  }

  for (const level of ['error', 'warning']) {
    for (const i of found[level].slice(0, CAP)) {
      const path = i.file.startsWith('app/') ? i.file : `app/${i.file}`;
      console.log(
        `::${level} file=${path},line=${i.line},col=${i.col},title=${esc(i.rule)}::${esc(i.msg)}`
      );
    }
    const extra = found[level].length - CAP;
    if (extra > 0) console.log(`::notice::${extra} more ${level}s — see the job summary.`);
  }

  const counts = `${found.error.length} errors, ${found.warning.length} warnings, ${found.info.length} infos`;
  console.log(`::notice title=flutter analyze::${counts}`);
  return found.error.length;
}

function annotateTest(out) {
  // Expanded reporter marks a failure, then prints Expected/Actual beneath it.
  const lines = out.split('\n');
  let shown = 0;

  for (let i = 0; i < lines.length && shown < CAP; i++) {
    if (!/\[E\]|^\s*FAILED|Test failed\./.test(lines[i])) continue;
    const detail = lines
      .slice(i, i + 8)
      .filter((l) => l.trim())
      .join('\n');
    console.log(`::error title=test failure::${esc(detail)}`);
    shown++;
  }

  const summary = lines.filter((l) => /\d+ tests? passed|failed/.test(l)).pop();
  if (summary) console.log(`::notice title=flutter test::${esc(summary.trim())}`);
  return shown;
}

const failures = mode === 'analyze' ? annotateAnalyze(text) : annotateTest(text);
console.log(`annotate: ${mode} produced ${failures} error annotation(s)`);
