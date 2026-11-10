# DayHop

A routine app for parents of kids aged 4 to 10. Parents set the routines. A child taps the steps in Kid Mode. Stars, streaks and parent-defined rewards stay on the household.

The product spec is the Kids-First MVP. Decisions that differ from its defaults are in [docs/decisions.md](docs/decisions.md). Work that needs a person is in [docs/human-tasks.md](docs/human-tasks.md).

## Run the app

```bash
npm install
npm test
npm run web
```

Open http://127.0.0.1:8081. Choose “Preview Maya's morning” on the welcome screen. The parent PIN is 2580.

`npm run typecheck` and `npm run trace` check the TypeScript and the requirement map.

## Run the site

```bash
python3 -m http.server 4173 --bind 127.0.0.1 --directory site
```

Open http://127.0.0.1:4173/.

## What is local

The browser build keeps the household on the device. Apple, Google, Supabase, RevenueCat, push and the final character art need the accounts listed in the human tasks. The SQL migrations are in `supabase/migrations`.
