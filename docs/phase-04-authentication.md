# Phase 4 — Authentication

## The funnel

```
Welcome ──▶ Sign up (username, email, password)
              │  createUserWithEmailAndPassword
              │  sendEmailVerification
              │  createProfile()  ← claims the username transactionally
              ▼
         Verify email  ── polls every 4s, plus a manual "I have verified"
              ▼
          Goal setup  ── writes users/{uid}.goalName
              ▼
         Matchmaking
```

Every hop is enforced in one place: `_redirect` in `app/lib/app/router.dart`.
Eight guards, in the order a new user meets them. No screen calls
`Navigator.push` to advance the funnel — they change state and the router
reacts, so deep links and process death land on the right screen for free.

## Username uniqueness

Firestore has no unique index, so `createProfile` claims the name in a
transaction over two documents:

```
usernames/{usernameLower}  ->  { uid, username, claimedAt }
users/{uid}                ->  the profile
```

Two people racing for `alex` both read the same empty `usernames/alex`; the
transaction retries and exactly one wins. The sign-up form additionally probes
`checkUsername` after 450 ms of quiet so nobody fills in a whole form to be told
no at the end — but the probe is a courtesy, the transaction is the guarantee.

## Why verification is mandatory

The matchmaking callable refuses unverified accounts:

```ts
if (request.auth?.token.email_verified !== true) {
  throw new HttpsError("failed-precondition", "Verify your email first.");
}
```

A partner who can vanish and respawn at will is not a partner. Verification is
the cheapest possible cost of entry, and it is the only thing standing between
the pool and an endless supply of throwaway accounts.

Nothing pushes the news back to the app when the user taps the link in their
mail client, so `VerifyEmailScreen` polls `user.reload()` every four seconds
while it is open, and forces a token refresh so `email_verified` reaches the
callable.

## The stranded-account guard

`createUserWithEmailAndPassword` can succeed and `createProfile` can then fail —
one dropped connection between two network calls. That user now owns an Auth
account with no profile, and cannot re-register because their own orphan holds
the email. The router sends them to `ClaimUsernameScreen`, which calls
`createProfile` again; the callable is written to handle an existing Auth user
with no document. It costs ninety lines and removes a class of support ticket
that has no other resolution.

## Error copy

`AuthRepository._readable` maps Firebase codes to sentences a person can act on:

| code | shown |
|---|---|
| `email-already-in-use` | That email already has an account. |
| `invalid-credential` / `wrong-password` / `user-not-found` | Email or password is incorrect. |
| `weak-password` | Pick a stronger password. |
| `too-many-requests` | Too many tries. Wait a minute. |
| `network-request-failed` | No connection. |

Sign-in deliberately collapses "no such user" and "wrong password" into one
message — telling an attacker which emails are registered is an account
enumeration gift with no product upside.

## Password policy

Eight characters, at least one letter and one digit (`Validators.password`).
Deliberately mild: this app holds a photo of someone at the gym, and every extra
rule costs sign-ups. Firebase's own breach-password checks do the heavy lifting.

## Sign-out

`AuthController.signOut` removes this device's FCM token before dropping the
session, so a signed-out phone stops receiving "your partner is waiting"
notifications.

## Test checklist

- [ ] Sign up, kill the app before verifying, reopen → lands on Verify, not Welcome
- [ ] Verify in mail, return to app without touching it → screen advances within 4s
- [ ] Same username in two simulators at once → one succeeds, one sees "taken"
- [ ] Wrong password 6 times → `too-many-requests` copy, no crash
- [ ] Sign out on device A → device A stops getting pushes, device B keeps them
