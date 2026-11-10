# DayHop

DayHop is a native iOS app for parents of children aged 4 to 10. Parents set the routines. A child taps the steps in Kid Mode. Stars, streaks, and parent-defined rewards stay with the household.

Open the Xcode project. That is the app.

## Open it in Xcode

1. Install Xcode 16 or newer.
2. Open `apple/DayHop.xcodeproj`.
3. Choose an iPhone or iPad simulator.
4. Press Run.

On the welcome screen, choose **Preview Maya's morning**. The parent PIN is **2580**. The preview password, used if a grown-up forgets the PIN, is `preview-house`.

Signing is turned off so the simulator runs without an Apple Developer team. A device build needs a team, and the bundle id `com.example.routinebuddies` still has to be registered.

```bash
xcodebuild -project apple/DayHop.xcodeproj -scheme DayHop -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Unit tests for the routine-day, streak, star, and PIN rules:

```bash
xcodebuild -project apple/DayHop.xcodeproj -scheme DayHop -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

The household is stored on the device. Decisions that differ from the spec are in [docs/decisions.md](docs/decisions.md). Work that needs a person is in [docs/human-tasks.md](docs/human-tasks.md).

## Not the app

`app/` and `npm run web` are an earlier browser preview. They are kept so the domain checks and the requirement map still run. They are not the product. `site/` is a placeholder marketing page.

```bash
npm test
npm run typecheck
```
