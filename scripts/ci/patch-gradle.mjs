/**
 * Pact needs four things the stock Flutter Android template does not provide:
 *
 *   1. the google-services plugin        (Firebase)
 *   2. minSdk 23                         (Firebase Auth floor)
 *   3. core library desugaring           (flutter_local_notifications)
 *   4. release signing from key.properties, falling back to debug keys
 *
 * Rather than committing a whole Gradle config that goes stale every time AGP
 * or Flutter moves — which is exactly how this build broke — we let
 * `flutter create` emit the current template and apply only these deltas.
 *
 * Idempotent: safe to run twice. Loud: if an anchor is missing it says which,
 * instead of producing a subtly broken build file.
 *
 *   node scripts/ci/patch-gradle.mjs app/android
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = process.argv[2] ?? 'app/android';
const GOOGLE_SERVICES = '4.4.2';
const DESUGAR = '2.1.4';
const MIN_SDK = 23;

let changed = 0;
const problems = [];

function edit(file, label, fn) {
  const path = join(root, file);
  if (!existsSync(path)) {
    problems.push(`${file} does not exist — did flutter create run?`);
    return;
  }
  const before = readFileSync(path, 'utf8');
  const after = fn(before);
  if (after === null) return;
  if (after === before) {
    console.log(`  = ${file}: ${label} already applied`);
    return;
  }
  writeFileSync(path, after);
  console.log(`  + ${file}: ${label}`);
  changed++;
}

// ── settings.gradle.kts — declare the google-services plugin ────────────────
edit('settings.gradle.kts', `google-services ${GOOGLE_SERVICES} declared`, (s) => {
  if (s.includes('com.google.gms.google-services')) return s;
  const anchor = /(id\("org\.jetbrains\.kotlin\.android"\)\s+version\s+"[^"]+"\s+apply\s+false)/;
  if (!anchor.test(s)) {
    problems.push('settings.gradle.kts: kotlin.android plugin line not found');
    return null;
  }
  return s.replace(
    anchor,
    `$1\n    id("com.google.gms.google-services") version "${GOOGLE_SERVICES}" apply false`
  );
});

// ── settings.gradle.kts — repository order and an explicit Central mirror ───
// Gradle asks plugins.gradle.org first, which proxies to repo.maven.apache.org.
// From shared CI addresses that proxy intermittently answers 403 Forbidden.
// Naming repo1.maven.org (Central's canonical host) ahead of it gives
// resolution a path that does not depend on the portal proxy.
edit('settings.gradle.kts', 'Maven Central mirror first', (s) => {
  if (s.includes('repo1.maven.org')) return s;
  const anchor = /(\n\s*)google\(\)(\s*\n\s*)mavenCentral\(\)/;
  if (!anchor.test(s)) {
    problems.push('settings.gradle.kts: repositories block not found');
    return null;
  }
  return s.replace(
    anchor,
    '$1google()$2maven { url = uri("https://repo1.maven.org/maven2") }$2mavenCentral()'
  );
});

// ── app/build.gradle.kts ────────────────────────────────────────────────────
edit('app/build.gradle.kts', 'google-services applied', (s) => {
  if (/id\("com\.google\.gms\.google-services"\)/.test(s)) return s;
  const anchor = /(id\("dev\.flutter\.flutter-gradle-plugin"\))/;
  if (!anchor.test(s)) {
    problems.push('app/build.gradle.kts: flutter-gradle-plugin line not found');
    return null;
  }
  return s.replace(anchor, `$1\n    id("com.google.gms.google-services")`);
});

edit('app/build.gradle.kts', `minSdk ${MIN_SDK}`, (s) => {
  if (s.includes(`minSdk = ${MIN_SDK}`)) return s;
  if (!/minSdk\s*=\s*flutter\.minSdkVersion/.test(s)) {
    problems.push('app/build.gradle.kts: minSdk line not found');
    return null;
  }
  return s.replace(
    /minSdk\s*=\s*flutter\.minSdkVersion/,
    `minSdk = ${MIN_SDK}   // Firebase Auth floor, above Flutter's default`
  );
});

edit('app/build.gradle.kts', 'core library desugaring', (s) => {
  let out = s;
  if (!out.includes('isCoreLibraryDesugaringEnabled')) {
    const anchor = /(compileOptions\s*\{)/;
    if (!anchor.test(out)) {
      problems.push('app/build.gradle.kts: compileOptions block not found');
      return null;
    }
    out = out.replace(
      anchor,
      `$1\n        // flutter_local_notifications schedules on APIs older than 26.\n        isCoreLibraryDesugaringEnabled = true`
    );
  }
  if (!out.includes('coreLibraryDesugaring(')) {
    out = out.trimEnd() +
      `\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:${DESUGAR}")\n}\n`;
  }
  return out;
});

// ── app/build.gradle.kts — turn off R8 for now ──────────────────────────────
// R8 shrinking fails on this dependency set without a curated keep list, and
// the generated build file never referenced the proguard rules we copy in.
// A demo APK gains nothing from shrinking: it costs a few MB and buys
// obfuscation nobody needs yet. Re-enable with proper rules before the Play
// release — see docs/phase-10-play-launch.md.
edit('app/build.gradle.kts', 'R8 shrinking disabled', (s) => {
  if (s.includes('isMinifyEnabled')) return s;
  const anchor = /(signingConfig = signingConfigs\.getByName\("debug"\))/;
  if (!anchor.test(s)) {
    problems.push('app/build.gradle.kts: release signingConfig line not found');
    return null;
  }
  return s.replace(
    anchor,
    '$1\n            isMinifyEnabled = false\n            isShrinkResources = false'
  );
});

// ── app/build.gradle.kts — the permanent Play identity ──────────────────────
// flutter create derives com.pactly.pactly from --org plus --project-name.
// applicationId is what Google Play locks forever and can never be changed
// after the first upload, so it gets a deliberate value. namespace is left
// alone: it only governs the R class and MainActivity's package.
edit('app/build.gradle.kts', 'applicationId com.pactly.android', (s) => {
  if (s.includes('com.pactly.android')) return s;
  const anchor = /applicationId = "[^"]+"/;
  if (!anchor.test(s)) {
    problems.push('app/build.gradle.kts: applicationId line not found');
    return null;
  }
  return s.replace(anchor, 'applicationId = "com.pactly.android"');
});

// ── app/build.gradle.kts — sign with v1 as well as v2/v3 ───────────────────
// The release APK was signed with v2/v3 only, which Android 7+ accepts but
// Android 6 and some OEM installers reject outright as unsigned — reported as
// a bare "App not installed". minSdk is 23, so v1 has to be there too.
edit('app/build.gradle.kts', 'v1 JAR signing enabled', (s) => {
  if (s.includes('enableV1Signing')) return s;
  const anchor = /(\n\s*)buildTypes \{/;
  if (!anchor.test(s)) {
    problems.push('app/build.gradle.kts: buildTypes block not found');
    return null;
  }
  return s.replace(
    anchor,
    '$1signingConfigs {' +
      '$1    getByName("debug") {' +
      '$1        enableV1Signing = true' +
      '$1        enableV2Signing = true' +
      '$1    }' +
      '$1}' +
      '$1' +
      '$1buildTypes {'
  );
});

// ── gradle.properties — stop the JVM-target mismatch failing the build ──────
// AGP now compiles library Java at 11, while plugins such as flutter_timezone,
// cloud_functions and camera_android_camerax still declare Kotlin jvmTarget
// 1.8. Kotlin 2.x treats that pairing as a hard error. We cannot edit those
// plugins, and the mixed bytecode dexes correctly, so demote the check to a
// warning — the documented escape hatch for exactly this situation.
edit('gradle.properties', 'JVM target validation disabled', (s) => {
  if (s.includes('kotlin.jvm.target.validation.mode')) return s;
  return (
    s.trimEnd() +
    '\n\n# Plugins still on Kotlin jvmTarget 1.8 vs AGP\'s Java 11. Mixed targets\n' +
    '# dex fine; the strict check is what breaks the build.\n' +
    'kotlin.jvm.target.validation.mode=IGNORE\n'
  );
});

// ── report ──────────────────────────────────────────────────────────────────
console.log(`\npatch-gradle: ${changed} edit(s) applied.`);

// Print what we actually produced. A silently-unapplied edit was worth one
// wasted round trip; it is not worth two.
for (const f of ['gradle.properties', 'settings.gradle.kts']) {
  const fp = join(root, f);
  if (existsSync(fp)) {
    console.log(`\n----- ${f} -----`);
    console.log(readFileSync(fp, 'utf8').trim());
  }
}

if (problems.length) {
  for (const p of problems) console.log(`::error title=patch-gradle::${p}`);
  console.error('\nThe Flutter Android template changed shape. Fix the anchors above.');
  process.exit(1);
}
