# QA scripts

Manual checks for every requirement in the MVP spec. Automated coverage is named where a test exists. Native, store and live-backend checks are blocked on the human tasks in /docs/human-tasks.md.

## Feature 1

### FR1.1

Flow: welcome (max 3 skippable screens) -> sign in (Apple, Google or email) -> adult confirmation (I am 18 or older) -> household name and timezone -> parental consent screen -> add first kid -> choose a routine template -> set parent PIN -> Parent Home with a Start Kid Mode prompt.

### FR1.2

Consent text must state what is collected about the child and link to the privacy policy. The kid profile cannot be created before consent is recorded (timestamp and policy version stored).

### FR1.3

Onboarding progress is saved so it resumes where the parent left off.

### FR1.4

Sign in with Google uses a native module (@react-native-google-signin/google-signin) in the development build. The returned ID token is exchanged with Supabase (signInWithIdToken) using a fresh nonce. Request only the openid and email scopes; never request Gmail, Calendar, Drive or any other Google API scope. Ignore the Google profile name and photo and, where Supabase allows, keep them out of stored user metadata. Google is used only to prove identity; the Supabase session is independent of Goo

### FR1.5

The sign-in screen shows Sign in with Apple, Continue with Google and email options as equally prominent buttons, following each provider's current button guidelines.

### FR1.6

Only a verified Google email is accepted; an unverified email is rejected.

### FR1.7

Settings has a Sign-in methods screen where a signed-in user can link or unlink Apple, Google and email and password, with at least one method always remaining. Linking happens only inside an authenticated session or after matching a verified email. Two existing accounts or households are never merged automatically.

### FR1.8

After the Google SDK returns a token and Supabase confirms the session, the SDK's own session is signed out so the Google account chooser appears next time (shared family devices).

### EC1.1

Parent quits mid-onboarding: resume from the last completed step on any device.

### EC1.2

Apple Hide My Email relay address: treated as a normal email; transactional email must work through the relay.

### EC1.3

Same verified email used with Apple, Google or a password: after the user re-authenticates with the existing method, prompt to link identities rather than create a duplicate account. Never auto-link on an unverified email, which would allow account takeover.

### EC1.4

No connectivity during onboarding: show a clear blocking message with retry (onboarding requires network).

### EC1.5

Device timezone differs from the household timezone later: show a banner asking the parent to confirm a change; never switch silently.

### EC1.6

Adult confirmation declined: no data is stored and a neutral message is shown.

### EC1.7

Apple credential revoked or user signs out elsewhere: detect on launch, sign out, show a message. If Kid Mode was active, sign-out requires the parent gate first.

### EC1.8

New phone: signing in restores everything; the PIN is per device and must be set again.

### EC1.9

Parent cancels the Google sheet: return silently to the sign-in screen with no error message.

### EC1.10

Google unavailable (offline), account restricted by a Google Workspace admin, or account blocked by Google (for example a supervised child account): show a neutral failure message and keep the other sign-in options visible.

### EC1.11

Apple Hide My Email addresses and Gmail addresses never match, so one person can end up with two accounts. A parent who signs up with Google and sees an empty household is shown a hint: already have an account with another method? Sign in with that first, then link Google in Settings.

### EC1.12

Google identity already linked to a different account: refuse the link with a clear explanation, never merge, and offer to sign in to that account instead.

### EC1.13

Parent revokes the app in their Google account or deletes the Google account: the existing Supabase session keeps working until it expires; a later Google sign-in fails. Settings suggests once (never repeatedly) adding a second sign-in method for recovery.

### EC1.14

Token replay or audience mismatch: Supabase validates the ID token against the configured client ID, and the client always sends a fresh nonce; failures show a generic error and are logged without personal data.

## Feature 2

### FR2.1

Owner invites by universal link plus an 8-character code. Invites are single-use, expire in 7 days and can be revoked.

### FR2.2

The invitee signs in, sees the household name and inviter, and accepts or declines.

### FR2.3

Guardian limits: 2 on Free, 4 on Plus. A guardian can leave. The owner can remove guardians and transfer ownership.

### FR2.4

Changes propagate to all devices through Realtime.

### EC2.1

Invitee already owns a household: block with options. If their household has no kids and one member, offer to delete it and join; otherwise they must leave or delete it first.

### EC2.2

Link opened while signed out: preserve the invite token through sign-in and onboarding.

### EC2.3

Link already used, expired, revoked, or household full: show a specific friendly state for each.

### EC2.4

Owner tries to delete their account: blocked until ownership is transferred or the household is deleted. If other guardians exist, offer transfer.

### EC2.5

Two guardians edit the same routine at once: each routine has a version number; a stale save is rejected with a refresh prompt and the user's draft is kept.

### EC2.6

Guardian removed while their device is in Kid Mode: the session is invalidated, local household data is wiped on next sync, and a message explains why.

### EC2.7

Co-parents in separate households (separated families): unsupported in v1. Documented limitation; backlog item multi-household kids.

### EC2.8

Subscription purchaser leaves the household: entitlement stays with the household until expiry, then is re-evaluated (Section 5, FS-11).

## Feature 3

### FR3.1

Fields: nickname (1-20 characters), age band (3-4, 5-6, 7-8, 9-10, 11+), character, accent colour (8 options). No birthdate, photo or surname is collected.

### FR3.2

Age band sets defaults: bands 3-6 use pre-reader mode (large icons, read-aloud on tap); bands 7+ show icon plus text.

### FR3.3

Parents can archive or permanently delete a kid, with a confirmation step.

### EC3.1

Nickname validation: trim, Unicode-normalize, reject control and bidirectional override characters, allow letters, numbers, spaces, hyphen and apostrophe. Emoji not allowed. Automated: `src/domain/domain.test.ts`.

### EC3.2

Duplicate nicknames allowed with a warning.

### EC3.3

Plan limits: creating beyond the free limit opens the paywall at that moment and never affects existing kids.

### EC3.4

Deleting a kid with pending approvals or open redemptions: warn, then cascade delete.

### EC3.5

Changing character mid-streak: allowed, nothing is lost.

### EC3.6

Archived kid: hidden from Kid Mode and notifications, kept in history, restorable for 30 days.

## Feature 4

### FR4.1

Templates bundled as JSON: Morning, After School, Bedtime, Chores starter (about 8 steps each). Custom routines can be created from scratch.

### FR4.2

Routine fields: name (1-30 chars), time-of-day label, days of week, optional start time, optional requires-approval toggle (Plus), bonus stars (default 3), assigned kids (one or many).

### FR4.3

Step fields: title (1-40 chars), icon from a bundled searchable set of about 150 icons, optional timer minutes, star value 0-5 (default 1). Reorder by drag, with accessible move up and down actions.

### FR4.4

Preview in Kid Mode style before saving.

### EC4.1

Zero steps cannot be saved; more than 15 steps is blocked with an explanation.

### EC4.2

Duplicate step titles allowed. Control characters rejected.

### EC4.3

Editing while a kid is mid-run: R9 snapshot protects the run.

### EC4.4

Deleting a step that has completions today: step is archived, run keeps its snapshot.

### EC4.5

Changing the schedule to exclude today: any run already started finishes; no new run is created.

### EC4.6

Start time already passed today: routine stays available all day.

### EC4.7

Daylight saving changes: start times use local wall-clock times via a tz-aware library. A skipped or repeated hour must not create duplicate or missing runs. Automated: `src/domain/domain.test.ts`.

### EC4.8

Assigned kid archived: assignment retained but inactive.

### EC4.9

Unsaved changes: confirm before discard. Large Dynamic Type: titles wrap, icons never shrink below 44pt touch targets.

### EC4.10

Routine shared by several kids: editing once changes it for all; each kid keeps separate runs and stars.

## Feature 5

### FR5.1

Entry: Parent Home -> Start Kid Mode -> kid picker (large character avatars) when more than one kid. Kid Mode persists across app kills, restarts and reboots until exited with the parent gate.

### FR5.2

Kid Home: mascot greeting, today's routines ordered by time of day with the current one highlighted, star balance, streak flame, rewards button (if rewards exist), switch-kid control. Switching kids needs no gate; exiting does.

### FR5.3

Routine screen: one step per card with a large icon, title, optional timer ring and a big Done button, plus progress dots. On completion: character cheer, sound and star burst of at most 1.2 seconds, skippable. The final step triggers a celebration and bonus stars.

### FR5.4

Read-aloud through expo-speech via a speaker button, automatic for pre-readers when enabled.

### FR5.5

Undo: an Oops button for 8 seconds after each tap, and any step can be reopened until the routine is finished. Undo writes a reversing ledger entry.

### FR5.6

No text input, external links, purchases, ads or advertising of any kind inside Kid Mode.

### FR5.7

Performance: tap-to-feedback under 100 ms and 60 fps animation on an iPhone 11 class device.

### FR5.8

No dark patterns: no loss-shaming copy, countdown urgency, variable rewards or engagement nagging. Finished means finished, with a calm done state.

### EC5.1

Double tap or rapid taps: debounce plus the R4 idempotency key.

### EC5.2

App backgrounded, phone call or Control Center interruption: state resumes exactly.

### EC5.3

Offline: fully functional from the local cache; writes go to the outbox; only the parent area shows a small sync indicator. No error dialogs in Kid Mode.

### EC5.4

Routine edited on another device: R9 applies. Runs not yet started pick up the change.

### EC5.5

Same kid active on two devices: completions merge as a union; duplicates are impossible by the unique key.

### EC5.6

Two kids using the device back to back: complete state isolation, including animations and pending sounds.

### EC5.7

Completion attempted after the routine day boundary: run is expired; show a friendly message (That was yesterday's one!) and offer today's run.

### EC5.8

Device clock changed: the server is authoritative. It rejects routine_date more than one day away from the server's date in the household timezone and flags the event. Automated: `src/domain/domain.test.ts`.

### EC5.9

No routines today: friendly empty state with the mascot.

### EC5.10

Everything done early: calm done state; no extra tasks are offered.

### EC5.11

Silent switch and volume respected; sound can be turned off in parent settings. Reduce Motion replaces animation with a static image and a fade.

### EC5.12

Rotation: portrait locked on iPhone, both orientations on iPad.

### EC5.13

Low Power Mode: reduce animation frame rate.

### EC5.14

VoiceOver, Switch Control and Guided Access must work. Parent help explains how to use Guided Access as an extra lock.

### EC5.15

Parent gate triggered accidentally by a child: lockout rules in FS-13 apply.

## Feature 6

### FR6.1

For routines with requires-approval, a finished run becomes pending_approval. The kid sees the mascot say it is waiting for a grown-up.

### FR6.2

Guardians get a push notification and an in-app Approval Inbox. Each item shows the steps, with Approve all, or Reject with selection of steps to reopen.

### FR6.3

Stars are credited on approval. Runs pending longer than 48 hours auto-approve (flagged auto).

### EC6.1

Two guardians act at once: first wins; second sees already handled.

### EC6.2

Rejection: selected steps reopen, kid sees a gentle try-again message, no stars credited.

### EC6.3

Approval made offline: queued in the outbox and applied idempotently.

### EC6.4

Notifications disabled: show a badge on the Parent Home and in-app banner.

### EC6.5

Approval for an archived kid: still processed and credited.

### EC6.6

Parent adjusts stars later: manual adjustment entry with an optional reason, never an edit of history.

## Feature 7

### FR7.1

Step stars, routine bonus and streak milestone bonuses are written to the ledger with an idempotency key. Automated: `src/domain/domain.test.ts`.

### FR7.2

Parents define rewards (Plus): title (1-40), icon, cost 1-999, optional per-week limit.

### FR7.3

Kid requests a reward in Kid Mode. Stars are held immediately (a pending ledger entry). The parent fulfils (stars stay spent) or denies (stars refunded).

### FR7.4

Streak, balance and lifetime stars are shown to the kid with positive copy only. When short on stars, show progress (N more stars to go!) instead of any refusal.

### EC7.1

Concurrent redemptions from two devices: a single RPC locks the kid's row so the balance can never go negative.

### EC7.2

Reward price changed after request: the price is locked at request time.

### EC7.3

Reward deleted or archived while requested: the request remains resolvable and shows the archived title.

### EC7.4

Per-week limit counts requests, not fulfilments, and resets by routine week (Monday start).

### EC7.5

Late-synced completions backfill earlier days and trigger a streak recompute.

### EC7.6

Timezone or schedule change: streaks are evaluated against the schedule in force on each date.

### EC7.7

Plan lapses: existing balances and history are untouched; rewards become read-only for requests until Plus returns, with a parent notice (see FS-11).

### EC7.8

Balance cap reached: further star credits are recorded but capped, with a quiet notice to the parent. Automated: `src/domain/domain.test.ts`.

## Feature 8

### FR8.1

Three characters, each with five Lottie states: idle, cheer, celebrate, encourage, sleepy (bedtime routines).

### FR8.2

SHOULD: four cosmetic stages unlocked by lifetime stars (0, 25, 100, 300). Cosmetic only, never a gate or a loss.

### FR8.3

Each animation has a static PNG fallback and a short audio cue (under 2 seconds).

### EC8.1

Asset fails to load: show the static PNG; never block interaction.

### EC8.2

Memory pressure: only the active character's animations are loaded; others are released.

### EC8.3

Reduce Motion and Low Power Mode handled as in FS-5.

### EC8.4

Kid with no character (data error): default to the first character.

### EC8.5

Final art arrives late: the build uses placeholders behind a single asset manifest so art can be swapped without code changes.

## Feature 9

### FR9.1

Push (guardians only): approval needed, kid finished a routine, reward requested, weekly summary ready, invite accepted, subscription billing issue. Per-guardian toggles and quiet hours (default 21:00-07:00).

### FR9.2

Local reminders on guardian devices at a routine's start time, opt-in per routine, default off, text like: Time for Maya's Morning Routine.

### FR9.3

Rolling local schedule: iOS caps pending local notifications at 64. Schedule only the next 7 days, at most 60 total, nearest first. Reschedule on foreground, background refresh, routine edit, timezone change and DST change.

### FR9.4

Permission is requested in context (after the first routine is saved) with a soft pre-prompt, never at launch.

### FR9.5

Completion pushes are coalesced: at most one per kid per event type per 10 minutes.

### FR9.6

Notification text uses nicknames only and never includes star balances or reward details. Tapping opens the relevant screen (deep link).

### EC9.1

Permission denied: show in-app badges and a Settings deep link; never nag more than once per 30 days.

### EC9.2

Multiple devices per guardian: tokens stored per device; stale tokens (Expo receipt DeviceNotRegistered) deleted.

### EC9.3

Duplicate pushes on retry: dedupe key per event.

### EC9.4

Notification tapped while signed out: queue the deep link until sign-in completes.

### EC9.5

Device in Kid Mode: the foreground handler suppresses banners; a kid must never be able to reach a parent screen from a notification without the parent gate.

### EC9.6

Travel and DST: reminders follow the household timezone, not the device timezone.

## Feature 10

### FR10.1

Parent Home: one card per kid (balance, streak, today's progress ring), Approval Inbox badge, Start Kid Mode button, quick add routine.

### FR10.2

Kid Detail: week view of completion dots, run history, star ledger with filters, manual star adjustment, pause streak (date range).

### FR10.3

Weekly Summary (Plus), generated Sunday 18:00 household time: completion rate, best routine, streak, stars earned and spent. Free plan shows basic last-7-day stats.

### FR10.4

Design rule: no sibling rankings, leaderboards or comparisons anywhere.

### EC10.1

No data yet: designed empty states.

### EC10.2

Kid created mid-week: calculate rates only over scheduled days since creation; never show a misleading low percentage.

### EC10.3

Long history: paginate 50 at a time with virtualized lists.

### EC10.4

Offline: show cached data with an updated X ago label.

## Feature 11

### FR11.1

RevenueCat entitlement plus, with monthly and annual offerings and a 7-day introductory trial. The RevenueCat app user ID is the household ID, so any guardian's purchase applies to the household and restores cleanly.

### FR11.2

The paywall appears only in the Parent Area, triggered by hitting a limit, tapping a Plus feature, or from Settings. It is never reachable from Kid Mode and always sits behind the parent gate.

### FR11.3

Paywall MUST show price, period, trial length, when billing starts, auto-renew disclosure, a Restore Purchases button, a manage-subscription link, and Terms and Privacy links (App Store Guideline 3.1.2).

### FR11.4

A RevenueCat webhook updates households.plan and plus_expires_at. The client reads the RevenueCat SDK for instant entitlement; the server confirms. Limits are enforced server-side in RPCs, not only in the UI.

### EC11.1

Restore on a new device or after reinstall: Restore Purchases and automatic sync by household ID.

### EC11.2

Billing retry and grace period: Plus stays active during grace. Refund or revoke events downgrade immediately.

### EC11.3

Webhook duplicates or delays: idempotent on event ID (rc_events); signature or shared-secret verified; client optimistic entitlement covers delay.

### EC11.4

Offline expiry: cache the entitlement with its expiry and allow a 3-day offline grace; recheck on reconnect.

### EC11.5

Ask to Buy or pending purchase: show a pending state, grant nothing until confirmed.

### EC11.6

No network at purchase: clear message, no partial state.

### EC11.7

Lapse policy (grandfathering): nothing is deleted and existing kids and routines keep working, but over-limit creation and edits are blocked. Approval-required routines revert to auto-approve, pending redemptions can still be resolved, and weekly summary falls back to basic. A calm parent banner explains. Revenue leakage from this policy is accepted in v1 and reviewed after launch.

### EC11.8

Purchaser leaves the household: entitlement stays with the household until expiry.

### EC11.9

Family Sharing for the subscription: off by default. [OPEN]

### EC11.10

Offer codes and promo codes: supported through RevenueCat and App Store Connect.

## Feature 12

### FR12.1

Settings: profile, household name and timezone, guardians, notifications, sound, read-aloud, change PIN, privacy policy and terms, data export, delete kid, delete account, restore purchases, manage subscription, support contact, version, and a help page including Guided Access instructions.

### FR12.2

Delete account (in-app, App Store Guideline 5.1.1(v)): re-authenticate, explain consequences, sign out immediately, hide data immediately, and hard purge within 7 days. For Google users, re-authenticate with Google (no provider token revocation is needed). For Sign in with Apple users, call Apple's token revocation endpoint. Remind the parent that deleting the account does NOT cancel an Apple subscription, with a link to manage it.

### FR12.3

Export: JSON plus CSV of all household and kid data, generated server-side and delivered by a signed URL that expires in 15 minutes, shared through the iOS share sheet. This also serves the COPPA parental review right.

### EC12.1

Deleting while other guardians exist: see EC2.4.

### EC12.2

Deleting while offline: blocked with a clear message.

### EC12.3

Deletion in progress or interrupted: idempotent job that resumes until complete.

### EC12.4

Re-registering with the same email after deletion: allowed and starts fresh.

### EC12.5

Large exports: asynchronous with a push or in-app notice when ready.

### EC12.6

Support requests to review or delete a child's data by email: [HUMAN] a monitored support address and a documented process.

## Feature 13

### FR13.1

A 4-digit PIN is set during onboarding and is mandatory. It is stored as a salted hash in the iOS Keychain (expo-secure-store, WHEN_UNLOCKED_THIS_DEVICE_ONLY), per device.

### FR13.2

The gate is required to: exit Kid Mode, open the Parent Area from Kid Mode, reach any purchase UI, open any external link, sign out, and change security settings.

### FR13.3

Five wrong attempts triggers a 5-minute lockout, then 15 minutes after the next five. The counter persists across app restarts. Automated: `src/domain/domain.test.ts`.

### FR13.4

Forgot PIN: re-authenticate (password, fresh Sign in with Apple, or fresh Google sign-in), then set a new PIN.

### FR13.5

SHOULD: Face ID or Touch ID as a shortcut, with PIN fallback.

### EC13.1

Reinstall loophole: iOS Keychain items survive app deletion. On first launch after install (detected by a missing flag in app storage), clear the stored session and PIN so a child cannot reinstall to escape Kid Mode into a signed-in Parent Area.

### EC13.2

Sign-out resets the PIN on that device. Account deletion clears all Keychain items.

### EC13.3

Shoulder surfing: digits are masked. The keypad is accessible with VoiceOver.

### EC13.4

A child entering the gate repeatedly triggers lockout, which shows a neutral message: Ask a grown-up. Automated: `src/domain/domain.test.ts`.

### EC13.5

PIN cannot be skipped, and trivial PINs (0000, 1234) are rejected. Automated: `src/domain/domain.test.ts`.
