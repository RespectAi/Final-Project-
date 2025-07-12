# WasteLess App

WasteLess is a mobile application that helps users track, manage, and share surplus food to reduce waste and combat hunger. Built with Flutter on the frontend and Supabase on the backend, WasteLess leverages real-time synchronization, secure authentication, and push notifications to deliver a seamless experience.

---

## Table of Contents

1. [Problem & Solution](#problem--solution)
2. [MVP Feature Set](#mvp-feature-set)
3. [Tech Stack & Workflow](#tech-stack--workflow)
4. [Database Schema](#database-schema)
5. [Project Setup](#project-setup)
6. [Development & Deployment](#development--deployment)
7. [Next Steps](#next-steps)

---

## Problem & Solution

**Problems:**
- Food going to waste while people go hungry
- Food wastage negatively impacting the economy

**Solution:**
- A mobile app that tracks inventory, notifies users when items are about to expire, logs waste, and facilitates sharing or donating surplus food.

---

## MVP Feature Set

1. **Inventory Entry**  
   Add, edit, and remove food items with details such as name, category, and expiry date.

2. **Expiry Alerts**  
   Push notifications to remind users of items nearing expiration.

3. **Waste Logging**  
   Record discarded items to track waste and generate insights.

4. **Offer to Donate**  
   Basic flow for users to offer surplus food to nearby recipients or shelters.

---

## Tech Stack & Workflow

- **Frontend:** Flutter / Dart  
- **Backend & Database:** Supabase (PostgreSQL, Auth, Realtime, Storage)
- **Version Control:** Git + GitHub
- **CI/CD:** GitHub Actions → Staging / Production environment

---

## Database Schema

| Table               | Fields                                                              | Description                                 |
|---------------------|---------------------------------------------------------------------|---------------------------------------------|
| **users**           | `id` (uuid), `email`, `created_at`                                 | Managed by Supabase Auth                    |
| **inventory_items** | `id` (uuid), `user_id` (fk), `name`, `category`, `expiry_date`, `created_at` | Tracks user food inventory                  |
| **waste_logs**      | `id` (uuid), `user_id`, `item_id`, `quantity`, `logged_at`         | Records discarded items                     |
| **donations**       | `id` (uuid), `user_id`, `item_id`, `recipient_info`, `offered_at`, `status` | Manages basic donation offers and status    |

> **Tip:** Enable Row-Level Security in Supabase and write policies to ensure users only access their own data.

---

## Project Setup

1. **Clone the repository**  
   ```bash
   git clone https://github.com/your-username/wasteless_app.git
   cd wasteless_app
   ```

2. **Install Flutter dependencies**  
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**  
   - Create a Supabase project at https://app.supabase.io
   - Note your `SUPABASE_URL` and `SUPABASE_ANON_KEY`
   - Create required tables as per the schema above
   - Enable RLS and set up policies

4. **Add environment variables**  
   Create a `.env` file in project root:
   ```env
   SUPABASE_URL=your-project-url
   SUPABASE_ANON_KEY=your-anon-key
   ```

5. **Run the app**  
   ```bash
   flutter run
   ```

---

## Development & Deployment

- **Feature Branch Workflow:**  
  Create a branch for each feature: `git checkout -b feature/expiry-alerts`

- **Pull Requests:**  
  Open PRs against `main`, include screenshots or test steps.

- **CI/CD:**  
  GitHub Actions runs tests and builds on push. Merges to `main` deploy to staging.

---

## Next Steps

- Implement user authentication and onboarding flow
- Build inventory CRUD screens in Flutter
- Integrate Supabase Auth and Database SDK
- Set up push notifications for expiry alerts
- Design donation offering and map view
- Gather feedback via beta testing


---

_Ready to reduce food waste and feed communities? Let’s build WasteLess!_
