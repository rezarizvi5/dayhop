# Decisions

Choices made while building the MVP. The spec wins except where this log says otherwise.

## Name

The spec default is Routine Buddies. The repository and the request use DayHop, so the app, the site and the bundle display name are DayHop. The bundle id stays the placeholder `com.example.routinebuddies` until a human registers one. A web search found dayhop.quest and dayhop.ie, which are different products, and HopRoutine, which is a different kids app. Trademark clearance is still a human task.

## Landing page and Expo web

The spec says a web app is out of scope as a product, and it also requires a marketing URL. `site/` is that page. An earlier pass ran the same screens in the browser so they could be previewed here. That preview is not the app.

## Local data instead of a live Supabase project

There is no Supabase project, anon key or service role in this environment. The app stores the household in Zustand (`dayhop` in localStorage) and applies the same domain rules the SQL RPCs are meant to apply. `supabase/migrations` is the schema and the kid-action RPCs, ready to apply when the project exists. The service-role key is not in the client.

## Parent PIN

The spec stores a salted PIN hash in the iOS Keychain. The browser preview stores a hash in the same local record. The Xcode app stores a SHA-256 hash in the Keychain. Sample household PIN is 2580.

## Preview household

Welcome includes “Preview Maya's morning”. It loads one kid, one routine, a Plus trial and the sample PIN so the browser can reach Kid Mode. It is a demo seed, not a new product feature.

## Sign-in

Email and a password of at least 10 characters create the local household. Apple and Google buttons stay on the screen at equal weight and explain that the native token exchange is not available in the browser. Unverified Google email, nonce, and signing the Google SDK out are specified in the migration notes and blocked on the human Google Cloud and Apple setup.

## Subscriptions

Plus is a local plan flag. The paywall shows $4.99 a month, $34.99 a year, the 7-day trial, when billing starts, and that it renews until cancelled. Restore Purchases and the RevenueCat webhook are not live.

## Characters

Pip, Bo and Juniper render as a letter on their colour. `assets/manifest.json` is the swap point for the five Lottie states and PNG fallbacks.

## Native iOS client

The spec assumed Expo and React Native. The product people open is the Xcode app in `apple/DayHop.xcodeproj`, SwiftUI, iOS 16 and later, iPhone and iPad. The earlier Expo screens stay in the repo only so the existing checks keep running. They are not the app.

The parent PIN is a salted SHA-256 hash in the iOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). A missing install marker clears that Keychain item so reinstalling the app cannot skip the gate. The preview PIN is 2580 and the preview password is `preview-house`.

Sign in with Apple and Google stay on the sign-in screen at the same size as email. Tapping them explains that the developer accounts are not connected. Email creates the household on this device. Two households are never merged.

Plus is a local 7-day flag. The paywall shows $4.99 a month, $34.99 a year, the trial, when billing would start, and that this build does not charge. RevenueCat and StoreKit products are still a human task.

Characters are drawn in SwiftUI. `apple/DayHop/Resources/manifest.json` is the swap point for final art. Step icons are a searchable SF Symbol set of about 150, not the final SVG pack. Streak milestone bonuses are 5 stars, once per milestone per child. A reward's weekly limit is counted per child. Past streak days use the current weekday mask from the day the routine was created; a full schedule history is not stored until the server exists.

Reminders are local notifications only, opt-in, at most 60 over the next 7 days, skipped during quiet hours, and they use the household clock. Push, Supabase, and realtime sync are not in this build. Kid Mode never shows a sync error.

## Routine day

The routine date is the household wall clock minus 3 hours, using `Intl` parts rather than raw millisecond arithmetic. Tests check that against `date-fns-tz` for the DST matrix in section 13.
