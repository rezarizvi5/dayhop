-- pgTAP sketch. Run with `pg_prove` against a Supabase database that has two auth users.
-- The CI job skips this file until DATABASE_URL is set. See docs/human-tasks.md.

begin;
select plan(4);

select ok(
  not has_table_privilege('authenticated', 'star_ledger', 'insert'),
  'authenticated cannot insert star_ledger rows'
);

select ok(
  not has_table_privilege('authenticated', 'routine_runs', 'update'),
  'authenticated cannot update routine_runs'
);

select ok(
  not has_table_privilege('authenticated', 'redemptions', 'delete'),
  'authenticated cannot delete redemptions'
);

select ok(
  not has_table_privilege('authenticated', 'step_completions', 'insert'),
  'authenticated cannot insert step_completions'
);

select * from finish();
rollback;
