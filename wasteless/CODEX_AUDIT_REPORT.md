# WasteLess Codebase Audit — Codex

**Scope:** Read-only audit of the active Flutter codebase. No application files were changed.

**Snapshot note:** The repository contains active, uncommitted edits in core pages and the Supabase service. Findings describe the code observed during this audit and should be revalidated before changes are merged.

## Verification summary

- `flutter analyze` completed with no emitted static-analysis findings.
- The automated test suite only contains Flutter's default counter smoke test; it does not exercise WasteLess features.
- The Supabase database schema and RLS policies were not available locally, so server-side authorization could not be verified.

## Findings

### 1. Critical — Local-user authentication can be bypassed across restarts and accounts

The active local-user/admin context is saved in global `SharedPreferences` and restored without a password prompt or validation that it belongs to the currently authenticated Supabase account. A previous session can therefore enter Home automatically on restart and may carry across a subsequent account switch.

**Locations:** `lib/services/supabase_service.dart` (lines 1267–1304), `lib/pages/auth_page.dart` (lines 53–73).

**Recommendation:** Namespace stored context by Supabase user ID, validate the selected local user belongs to that account, and require reauthentication according to the intended security policy.

### 2. Critical — Local passwords use unsalted SHA-256 and are verified in the client

The application hashes local passwords with SHA-256 in the Flutter client, stores the hash in `local_users`, reads it back, and compares it in the client. SHA-256 is unsuitable for password storage and client-side verification exposes password hashes to every authorized reader of that row.

**Location:** `lib/services/supabase_service.dart` (lines 1127–1141 and 1326–1345).

**Recommendation:** Use a server-side authentication/verification flow with Argon2id or bcrypt and a unique salt. Do not expose password hashes to the client.

### 3. High — Authorization checks are placeholders that always grant access

The user-management permission methods return `true` unconditionally. UI gating is not a security boundary, and the service methods perform privileged role/member updates from the client.

**Locations:** `lib/pages/user_page.dart` (lines 486–499), `lib/services/supabase_service.dart` (lines 1185–1263).

**Recommendation:** Implement role checks for user experience, but enforce ownership/admin permissions with Supabase RLS and preferably security-definer RPCs for sensitive operations.

### 4. High — Partial waste logging deletes the complete inventory item

`logWaste(itemId, qty)` records the specified quantity but deletes the whole inventory record. Logging one unit of an item whose quantity is five loses the remaining four. Donation also has no quantity and always removes the item.

**Location:** `lib/services/supabase_service.dart` (lines 204–230 and 238–262).

**Recommendation:** Atomically decrement the quantity when it remains positive; delete only when the remainder is zero. Capture donation quantity explicitly.

### 5. High — Multi-step database actions are non-transactional

Creating an item and its category links, recording waste/donations and deleting inventory, approving requests, and deleting fridges are multi-request workflows. A failure halfway through produces partial, inconsistent data.

**Locations:** `lib/services/supabase_service.dart` (lines 71–201, 204–262, 918–963, and 1227–1249).

**Recommendation:** Move each workflow into an atomic database transaction/RPC, with server-side authorization and clear error reporting.

### 6. Medium — Shared-fridge behavior is inconsistent

Main inventory, dashboard statistics, waste logs, donations, and category inventory are restricted to `user_id == current authenticated user`, whereas fridge-detail screens load items for the whole fridge. Shared members' inventory can be missing from the primary screens.

**Locations:** `lib/services/supabase_service.dart` (lines 20–44, 56–68, 264–277, and 290–315).

**Recommendation:** Define the expected shared-fridge model and consistently query by permitted fridge memberships instead of only the item creator where collaboration is intended.

### 7. Medium — Notification lifecycle can create stale or repeated reminders

Notification IDs use `String.hashCode`, reminders are not cancelled when an item is deleted/donated/wasted, and `matchDateTimeComponents: DateTimeComponents.dateAndTime` makes reminders recur annually. The startup rescheduling path is currently commented out.

**Locations:** `lib/services/supabase_service.dart` (lines 108–131 and 170–196), `lib/main.dart` (lines 194–206).

**Recommendation:** Store stable numeric notification IDs, cancel them when an item leaves inventory, omit repeating date-time components for one-off expiry alerts, and implement deterministic startup rescheduling.

### 8. Medium — Operational errors are silently suppressed

Several broad `catch (_) {}` blocks hide parsing, persistence, network, and notification failures. This makes faults appear as successful operations and limits diagnosis.

**Locations:** `lib/services/supabase_service.dart` (for example lines 131, 196, 216, and 250), `lib/main.dart` (lines 183, 190, and 204).

**Recommendation:** Handle expected exceptions explicitly, log enough safe diagnostic context, and surface actionable failure states to users where operations are incomplete.

### 9. Quality — Tests do not cover the application

The only test is the generated counter-app test and does not import or exercise WasteLess.

**Location:** `test/widget_test.dart`.

**Recommendation:** Add service tests with mocked Supabase, widget tests for auth/local-user flows and quantity handling, and integration tests for RLS-protected workflows.

### 10. Quality — `crypto` is imported directly but not declared directly

`package:crypto/crypto.dart` is imported by the service but `crypto` is absent from direct dependencies in `pubspec.yaml`. It is presently available transitively, which is fragile.

**Locations:** `lib/services/supabase_service.dart` (line 4), `pubspec.yaml`.

**Recommendation:** Add `crypto` as an explicit dependency—or, preferably, remove this client-side password-hashing design as described in finding 2.

## Existing audit document

`APP_AUDIT_AND_BUGS.md` was already present and has active uncommitted edits. It records earlier UI and Supabase relationship issues. Some may be in progress or resolved, so they were not treated as new confirmed defects in this report.

## Priority order

1. Fix local-user session isolation and client-side password handling.
2. Enforce all admin/owner permissions through database RLS/RPCs.
3. Make quantity-changing and multi-table operations atomic.
4. Establish a consistent shared-fridge visibility model.
5. Correct notification lifecycle and build meaningful automated coverage.

## Note on the Supabase anon key

The Supabase anon key embedded in a Flutter client is normally public and is not itself a secret-leak finding. Its safety relies on correctly configured RLS policies, which were outside this repository snapshot and could not be audited.
