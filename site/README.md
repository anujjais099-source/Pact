# Pact — marketing site

A single static page. No build step, no framework, no dependencies — one
`index.html` with inlined CSS and ~40 lines of JS. Vercel serves it as-is.

## Deploy (free, no domain purchase)

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

Open `index.html` and edit the two constants at the bottom:

```js
const PLAY_URL     = "";                  // paste your Play Store link here
const NOTIFY_EMAIL = "you@example.com";   // where launch-day emails land
```

- **`PLAY_URL` empty** → the button reads *"Get the launch link"* and opens a
  pre-filled email. Correct for a pre-launch page.
- **`PLAY_URL` set** → the button turns into a real *"Download on Google Play"*
  link and the "launching soon" note hides itself. No other edits needed.

Then swap `https://pact.vercel.app/` for your real URL in three places:
`<link rel="canonical">`, the two `og:url` / sitemap entries, and `robots.txt`.

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
