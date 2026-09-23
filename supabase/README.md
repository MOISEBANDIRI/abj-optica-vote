# Backend — Supabase

This directory versions the backend of the UABJ OPTICA Student Chapter election system.

## Files
- `migrations/20260922_backend_schema.sql`: tables, constraints, indexes, RLS and public read policies.
- `migrations/20260922_backend_functions.sql`: voting and administration RPCs and grants.
- `seed.sql`: non-sensitive election configuration, positions, candidates and member names.

## Security
The repository intentionally **does not contain** voter codes, voter-code hashes, ballots, receipts, participation records, service-role keys, authentication secrets, or private database credentials. The publishable Supabase key used by the browser is not a service-role secret.

Eligible voters must be provisioned separately. Store only SHA-256 hashes of their individual codes in `eligible_voters.voter_code_hash`.

The deployed admin authorization currently checks the authenticated administrator email in `is_election_admin()`. Review that function before reusing this backend for another election.

## Restore order
1. Create a Supabase project.
2. Run `20260922_backend_schema.sql`.
3. Run `20260922_backend_functions.sql`.
4. Run `seed.sql`.
5. Configure Supabase Auth Site URL / redirect URL for `/admin.html`.
6. Provision eligible voters securely.
7. Update the frontend Supabase URL and publishable key for the new project.
8. Keep the election closed until functional testing and cleanup are complete.

## Privacy architecture
Identity/participation is stored separately from anonymous ballots. `ballots` has no voter foreign key. `participation_log` records voter participation and a hash of the receipt, but does not link to a ballot.
