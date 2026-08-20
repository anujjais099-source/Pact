# Pact — marketing site

A single static page. No build step, no framework, no dependencies — one
`index.html` with inlined CSS and ~40 lines of JS. Vercel serves it as-is.

## Live at

**https://www.pactly.in** — apex `pactly.in` 308-redirects to it, which is
Vercel's default when www is the primary domain. Flip that in
**Vercel → Settings → Domains** if you would rather the bare domain be primary;
if you do, update the canonical link, `og:url`, `sitemap.xml` and
`robots.txt` to match, or search engines will index one and rank the other.

## Deploy

You get a free `*.vercel.app` address. Two ways in; the first needs nothing but
this folder.

### A · CLI — fastest

```bash
cd site
npx vercel login       # opens a browser, use GitHub/Google/email
npx vercel             # answer the prompts, then it deploys a preview
npx vercel --prod      # promote to your live .vercel.app URL
```

Prompt answers:

| Prompt | Answer |
|---|---|
| Set up and deploy? | **y** |
| Which scope? | your personal account |
| Link to existing project? | **n** |
| Project name? | `pact` (this becomes `pact.vercel.app` if free, else `pact-xyz.vercel.app`) |
| In which directory is your code? | `./` |
| Modify settings? | **n** — it is a static site, defaults are right |

### B · GitHub — redeploys on every push

```bash
cd ..                       # repo root
git init && git add . && git commit -m "Pact MVP"
gh repo create pact --private --source=. --push
```

Then on vercel.com → **Add New… → Project** → import the repo, and set
**Root Directory** to `site`. Leave framework as *Other*. Deploy.

Every `git push` from then on redeploys automatically.

## Before you share the link

Open `index.html`, scroll to the bottom, and fill in the top line that applies:

```js
const PLAY_URL     = "";                       // 3. once you are on Google Play
const APK_URL      = "";                       // 2. direct download for testers
const NOTIFY_EMAIL = "anujjais099@gmail.com";  // 1. fallback: collect emails
```

The button rewrites itself based on which one is filled — there is no other edit
to remember.

| Filled | Button reads | Extra |
|---|---|---|
| neither | **Get the launch link** | opens a pre-filled email to you |
| `APK_URL` | **Download the APK** | shows the "allow install from this source" warning testers need |
| `PLAY_URL` | **Download on Google Play** | the beta note hides itself |

### Handing friends an APK

1. `cd app && flutter build apk --release`
2. Copy `app/build/app/outputs/flutter-apk/app-release.apk` to `site/pact.apk`
3. Set `const APK_URL = "/pact.apk";`
4. Push. The APK is served with the right MIME type so Android treats it as an
   install, not a text file (handled in the root `vercel.json`).

Note the `.gitignore` skips `*.apk` by default — force it in with
`git add -f site/pact.apk` when you are ready to publish a build.

## Analytics

Google Analytics 4 is installed in the `<head>`, property `G-6E27HWMNEH`.
Change that ID in two places in `index.html` if you move properties.

Beyond GA4 pageviews, the page reports two custom events — the only two that
answer whether people find this interesting:

| Event | Fires when |
|---|---|
| `cta_click` | the download button is pressed. The `cta_state` parameter says whether it was in email, apk or play_store mode |
| `demo_break_streak` | someone taps "see what happens when one of you misses" — they engaged with the mechanic rather than just scrolling |

Both are wrapped in a `typeof gtag === "function"` check, so an ad blocker
degrades the page to plain HTML instead of breaking the buttons.

Realtime traffic shows up at analytics.google.com within seconds; the custom
events appear under **Reports → Engagement → Events** after a delay of up to
24 hours the first time.

## Social preview image

`og:image` is deliberately absent — a broken one is worse than none. To add it:
drop a 1200×630 PNG at `site/og.png` and add to `<head>`:

```html
<meta property="og:image" content="https://YOUR-URL.vercel.app/og.png">
```

## Local preview

```bash
npx serve site      # or: python -m http.server 8000 -d site
```
