# Phase 6 — Camera Check-In

## The constraint is the product

There is no gallery picker anywhere in this app, and there is no code path that
could add one: the `camera` plugin is the only image source, and `image_picker`
is not a dependency. A check-in is a live frame or it does not exist.

## Flow

```
CameraScreen
  availableCameras() → back lens first → CameraController(ResolutionPreset.high)
  shutter → takePicture() → local File → preview with Retake / Submit
  submit  → compress to 1080px JPEG q82
          → putData → checkins/{pactId}/{dayKey}/{uid}.jpg
          → getDownloadURL
          → submitCheckIn(pactId, photoUrl, photoPath)   ← server rules on it
          → CheckInSuccessScreen
```

The temp frame is deleted in a `finally` regardless of outcome.

## Compression

A 12 MP frame is 3–4 MB. Proof only has to be recognisable, so
`CheckInRepository._compress` resizes the long edge to 1080 and encodes JPEG at
quality 82 — roughly 180 KB. On a bad connection that is the difference between
a check-in and a broken streak, which makes it a retention feature, not an
optimisation.

## Permissions

`AndroidManifest.xml` declares `CAMERA` as `required="true"` — a device without
a camera cannot use Pact, and Play should not offer it. The plugin triggers the
runtime prompt on first `initialize()`. A denial surfaces as
`CameraAccessDenied`, which the screen turns into: *"Pact needs the camera.
Enable it in Settings to check in."*

Android also tears the camera away when the app backgrounds, so `CameraScreen`
observes the lifecycle and rebinds on resume. Without that, answering a phone
call mid-check-in returns you to a black rectangle.

## Server-side validation

`submitCheckIn` is not a formality. It verifies:

1. the caller is a member of that pact,
2. the pact is still `active`,
3. `photoPath` starts with `checkins/{pactId}/{todayKey}/{uid}` — a photo cannot
   be filed under yesterday, or under a partner,
4. this member is not already green today (idempotent double-taps).

Then, in one transaction, it writes the day status, the immutable proof record,
the user's counters, and — only if both members are now green — the streak
increment and the level.

## Storage rules, and the retry hole they had to close

Proof is immutable once the day is green. But the naive rule ("create only,
never update") deadlocks a real user: the upload succeeds, the callable times
out in a tunnel, the retry hits an object that already exists, and the day is
lost through no fault of theirs. So the rule allows writes while the day is
still open and freezes the object the instant the server marks it green:

```
allow write: if isPactMember(pactId)
  && fileName == request.auth.uid + '.jpg'
  && isImage() && underSizeLimit()
  && dayIsOpen();     // day doc missing, or not resolved and this uid not green
```

## Test checklist

- [ ] Deny the camera permission → readable message, Settings is the obvious fix
- [ ] Background the app on the camera screen, return → preview is alive
- [ ] Airplane mode on Submit → error, Retry works, no duplicate check-in
- [ ] Submit twice fast → one check-in, streak moves once
- [ ] Try to overwrite your own proof after both went green → Storage denies it
- [ ] Partner's Home shows your photo and submission time within a second
