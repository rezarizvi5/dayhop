# Human tasks

The iOS app is the Xcode project in `apple/`. Sign in with Apple, Google, and Supabase are wired in the client. They stay off until Reza creates the accounts below. The simulator path does not need them: email sign-in, Preview Maya's morning, and PIN 2580 keep working, and the Apple and Google buttons explain that those accounts are not connected. Do not paste a secret into chat or into the app binary. The service-role key never goes in the client.

Reza still has to create:

- An Apple Developer Program membership. Register the bundle id (the placeholder is `com.example.routinebuddies` until it is registered). Turn on Sign in with Apple for that id. In the Supabase Apple provider, set the Team ID, the Key ID, the Services ID or bundle audience, and the Apple private key. Keep that key in the Supabase dashboard. Do not put it in the app, and do not add the Sign in with Apple entitlement to the simulator target.
- A Google Cloud project. Configure the OAuth consent screen with the app name and a privacy-policy URL, then move it to production. Create an iOS OAuth client for the bundle id and the web client the Supabase Google provider expects. Scopes stay openid and email. Put the web client id and secret only in the Supabase Google provider, with manual linking on and automatic linking off. Put the iOS client id in `apple/DayHop/Resources/supabase.json` as `googleClientID`. Put the reversed iOS client id (`com.googleusercontent.apps.…`) in that file as `googleReversedClientID` and in the Xcode build setting `GOOGLE_REVERSED_CLIENT_ID`. Those two values have to match. No Google client secret belongs in the repo.
- A Supabase project in a US region. Apply `supabase/migrations`, including `0003_sync.sql`. Turn on email confirmation, a minimum password length of 10, and leaked-password protection. Turn on the Apple and Google providers and leave the nonce check on. Enable realtime for the household tables and point-in-time recovery. Put only the project URL and the anon key in `apple/DayHop/Resources/supabase.json`. Leave both empty to keep the on-device path.

Still not live:

- RevenueCat products: monthly $4.99, annual $34.99, 7-day trial, household id as the app user id, webhook secret on the edge function.
- Counsel review of consent, the privacy policy, COPPA, GDPR-K and US state children's privacy rules before public release.
- Trademark search and the final app name. DayHop is the working name.
- Final character art: five Lottie states plus PNG and a short audio cue for Pip, Bo and Juniper, with written IP assignment. About 150 step icons.
- Privacy policy and terms as legal text. The site copies at `site/privacy.html` and `site/terms.html` are placeholders.
- A monitored support inbox. The placeholder is hello@dayhop.example.
- TestFlight beta with at least 20 families for two weeks, and the child usability sessions in section 13.
- App Store screenshots, age rating, privacy nutrition label, and review notes with a seeded demo account and the parent PIN.
- Run `supabase/tests/rls_isolation.sql` with pgTAP as two different users and extend it to every table and RPC before release.
