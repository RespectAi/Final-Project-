# WasteLess App — Comprehensive Audit & Bug Report

**Date**: September 14, 2026  
**Target App**: WasteLess (Flutter Mobile & Web)  
**Target Directory**: `C:\Users\Moses\Documents\PLP Febuary Chort\Python2\Flutter Assignment\Final-Project-\wasteless`  
**Test Account Used**:
- **Email**: `moses@gmail.com`
- **Password**: `moses`
- **Role**: Admin (Password for Admin gate: `moses`)

---

## 1. Executive Summary

During testing and interactive exploration of the WasteLess application (running via Chrome/Web renderer), the application boots successfully and connects to Supabase. However, several critical schema/foreign-key query bugs, an unmounted widget lifecycle exception, and multiple UI/layout flaws were discovered that impede user experience.

This document serves as an exhaustive reference for the next agent or developer to immediately pick up and implement fixes.

---

## 2. Detailed Findings & Bugs

### Bug #1: Supabase Foreign Key Relationship Errors (`PGRST200 / HTTP 400`) — CRITICAL
- **Files Affected**:
  - `lib/services/supabase_service.dart` (around lines where `fridge_users` and `fridge_requests` queries are built)
  - `lib/pages/fridges_page.dart`
  - `lib/pages/user_page.dart`
- **Symptoms**:
  - When opening any Fridge detail view (e.g. *Fridge 1* or *Respect*), the **Members** list is completely blank.
  - In *User Management* -> *Fridge Members* tab, member data fails to load with HTTP 400.
  - In *User Management* -> *Join Requests* tab, pending requests fail to load with HTTP 400.
- **Exact Error Messages**:
  ```
  PostgrestException(
    message: Could not find a relationship between 'fridge_users' and 'profiles' in the schema cache,
    code: PGRST200,
    details: Searched for a foreign key relationship between 'fridge_users' and 'profiles' using the hint 'fridge_users_user_id_fkey' in the schema 'public', but no matches were found.,
    hint: Perhaps you meant 'fridges' instead of 'profiles'.
  )
  ```
  ```
  PostgrestException(
    message: Could not find a relationship between 'fridge_requests' and 'profiles' in the schema cache,
    code: PGRST200,
    details: Searched for a foreign key relationship between 'fridge_requests' and 'profiles' using the hint 'fridge_requests_requester_id_fkey' in the schema 'public', but no matches were found.
  )
  ```
- **Root Cause**:
  In `supabase_service.dart`, queries specify explicit foreign key relationship hints:
  - `profiles!fridge_users_user_id_fkey(full_name)`
  - `profiles!fridge_requests_requester_id_fkey(full_name)`
  In the PostgreSQL database schema on Supabase, the foreign key constraint is either named differently (e.g., standard `user_id_fkey` or referencing `auth.users` rather than `public.profiles`), or `profiles` does not have a direct foreign key mapped to `fridge_users.user_id`.
- **Recommended Fix**:
  1. Remove the explicit hint and query either without hint (e.g. `profiles(full_name)`) if a foreign key exists, or perform a manual profile join/lookup via `profiles.id = fridge_users.user_id`.
  2. Inspect the Supabase table schema for `fridge_users` and `profiles` to align constraint names.

---

### Bug #2: Unmounted BuildContext Lifecycle Error — RUNTIME EXCEPTION
- **File Affected**: `lib/pages/user_page.dart` (around line 9652 in transpiled JS)
- **Symptoms**:
  Console throws `DartError: This widget has been unmounted, so the State no longer has a context`.
- **Exact Error Message**:
  ```
  DartError: This widget has been unmounted, so the State no longer has a context (and should be considered defunct).
  Consider canceling any active work during "dispose" or using the "mounted" getter to determine if the State is still active.
  ```
- **Root Cause**:
  In `user_page.dart`, an asynchronous method awaits a Supabase response and subsequently accesses `context` (or `ScaffoldMessenger.of(context)` / `Navigator.of(context)`) after the widget has already been popped or disposed.
- **Recommended Fix**:
  Insert `if (!mounted) return;` immediately before any `context` reference following an `await` expression.

---

### Bug #3: Recent Items Card Expansion / Overflow Glitch on Dashboard — UI BUG
- **File Affected**: `lib/pages/dashboard_page.dart` (`_buildLeftPane()`, lines 346–425)
- **Symptoms**:
  - In the Dashboard left pane ("Recent Items"), clicking the dropdown chevron on an item (e.g. *kola Nut*) to view expiry dates causes an ugly, awkward vertical scrollbar to render right across the card.
  - The second recent item (*ginja*) gets pushed completely out of sight or clipped because the inner `Expanded(child: ListView)` has constrained vertical bounds above the fixed 120px *Other Reminders* card.
- **Root Cause**:
  The left column is constrained to an `Expanded` height, and the expansion tile inside the `ListView` does not trigger a natural layout expansion of the container.
- **Recommended Fix**:
  Allow the left pane content to scroll naturally as a whole (e.g., using a single scroll view or flexible expansion) rather than trapping an accordion inside a tight inner `Expanded(ListView)`.

---

### Bug #4: Bottom Navigation Bar Clips Content on Multiple Screens — LAYOUT BUG
- **Files Affected**:
  - `lib/pages/inventory_list.dart`
  - `lib/pages/waste_log_page.dart`
  - `lib/pages/donation_page.dart`
- **Symptoms**:
  - On **Inventory**, the bottom-most item (e.g. *yougut*) is partially obscured by the bottom navigation bar.
  - On **Waste Log**, the bottom-most entry (e.g. *Orange — 1*) is cut in half beneath the navigation bar.
  - On **All Donations**, the bottom donation card (*Fried Fish*) is clipped.
- **Root Cause**:
  The `ListView` or `ListView.builder` on these pages uses `padding: const EdgeInsets.all(8);`. Because the custom bottom navigation bar and floating action buttons overlay the bottom 60–80px of the viewport, the scrollable area does not have enough bottom inset.
- **Recommended Fix**:
  Update padding to:
  ```dart
  padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
  ```
  This guarantees that users can scroll the final item completely clear of the bottom navigation bar and floating action button.

---

### Bug #5: Announcement Ticker Marquee Overlap / Word Collision — VISUAL BUG
- **File Affected**: `lib/pages/dashboard_page.dart` (`_Marquee` widget, lines 456–538)
- **Symptoms**:
  The announcement text overlaps and collides into single merged words (e.g., `...codes to add items fastpcoming Feature: AI-based expiry p...`).
- **Root Cause**:
  In `_MarqueeState.build()`, text calculation width and the translation `Offset(dx, 0)` do not account for dynamic resizing or inter-string delimiters cleanly across different screen widths.
- **Recommended Fix**:
  Ensure clean spacing delimiters (e.g. `   •   `) and ensure `TextPainter` width uses proper padding margins so words never visually collide.

---

### Bug #6: Duplicate Header on "All Donations" Screen — UI BUG
- **File Affected**: `lib/pages/donation_page.dart`
- **Symptoms**:
  The string `"All Donations"` appears twice consecutively: once in the standard top AppBar and immediately below it as a large heading inside the green gradient header banner.
- **Recommended Fix**:
  Remove the redundant second heading or convert the top AppBar title into a contextual back title.

---

### Bug #7: Text Typos & Data Inconsistencies — CONTENT BUGS
- **Files Affected**:
  - `lib/pages/waste_log_page.dart` (or database seed values)
- **Details**:
  - Status is displayed as `"soilt"` instead of `"spoilt"` on multiple items (*Jolly Juice*, *mango*, *Butter*).
  - Inconsistent capitalization between `"Spoilt"` and `"spoilt"`.
  - Recipient name in donation record appears as `"Resect"` instead of `"Respect"`.

---

### Bug #8: Placeholders / Incomplete Actions — ENHANCEMENT
- **QR Code Scanner**: Clicking `Icons.qr_code_scanner` triggers `showCornerToast('QR scanner coming soon')`.
- **Other Reminders**: Clicking the card triggers `showCornerToast('Other Reminders — coming soon')`.

---

## 3. Recommended Priority Roadmap for Next Agent

1. **Priority 1 (Data Loading)**: Fix foreign key relationship hints in `lib/services/supabase_service.dart` for `fridge_users` and `fridge_requests`.
2. **Priority 2 (App Stability)**: Fix unmounted `BuildContext` in `lib/pages/user_page.dart`.
3. **Priority 3 (Scroll & Navigation Usability)**: Add bottom padding (`bottom: 90`) to `inventory_list.dart`, `waste_log_page.dart`, and `donation_page.dart`.
4. **Priority 4 (Dashboard Polish)**: Refactor Dashboard recent items expansion and marquee text formatting in `dashboard_page.dart`.
5. **Priority 5 (Data & Label Polish)**: Correct duplicate header in `donation_page.dart` and fix `"soilt"` typo in waste log status handling.
