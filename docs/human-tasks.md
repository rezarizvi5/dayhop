# Human tasks

The build does not block on these. Each one is stubbed. The iOS app is the Xcode project in `apple/`. Apple, Google, Supabase, RevenueCat, and push are still not live.

- Apple Developer Program, Paid Apps Agreement, bundle id, and Sign in with Apple.
- Google Cloud iOS OAuth client. Scopes stay openid and email. The client must send a fresh nonce and sign the Google SDK out after Supabase accepts the session.
- Supabase project in a US region. Apply `supabase/migrations`, enable leaked-password protection, email confirmation, and point-in-time recovery. Put only the anon key in the client.
- RevenueCat products: monthly $4.99, annual $34.99, 7-day trial, household id as the app user id, webhook secret on the edge function.
- Counsel review of consent, the privacy policy, COPPA, GDPR-K and US state children's privacy rules before public release.
- Trademark search and the final app name. DayHop is the working name.
- Final character art: five Lottie states plus PNG and a short audio cue for Pip, Bo and Juniper, with written IP assignment. About 150 step icons.
- Privacy policy and terms as legal text. The site copies at `site/privacy.html` and `site/terms.html` are placeholders.
- A monitored support inbox. The placeholder is hello@dayhop.example.
- TestFlight beta with at least 20 families for two weeks, and the child usability sessions in section 13.
- App Store screenshots, age rating, privacy nutrition label, and review notes with a seeded demo account and the parent PIN.
- Run `supabase/tests/rls_isolation.sql` with pgTAP as two different users and extend it to every table and RPC before release.
