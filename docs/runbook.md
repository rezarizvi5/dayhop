# Runbook

## App

```bash
npm install
npm test
npm run typecheck
npm run web
```

Open http://127.0.0.1:8081. On the welcome screen, choose “Preview Maya's morning”. The parent PIN is 2580. Leave Kid Mode through the gate.

## Site

Serve the folder and open the page over http, not as a file:

```bash
python3 -m http.server 4173 --bind 127.0.0.1 --directory site
```

Open http://127.0.0.1:4173/.

## Database

When a Supabase project exists:

1. Apply `supabase/migrations/0001_init.sql`, then `0002_rls_and_rpcs.sql`.
2. Confirm `authenticated` cannot insert into `star_ledger`, `routine_runs`, `step_completions` or `redemptions`.
3. Run `supabase/tests/rls_isolation.sql` with pgTAP.

## Restore drill

Production backups are a human choice on the Supabase plan. Until that project exists there is nothing to restore. After it exists: take a backup, restore it into a scratch project, and confirm a household, a kid balance and a ledger row match production before declaring the drill done. Do not restore over production as the first step.

## Account deletion

The in-app delete hides the local household immediately. It does not cancel an Apple subscription. Hard purge within 7 days, Apple token revocation, and the signed export URL are part of the edge functions and are not running here. The settings export is a JSON download of the local record.
