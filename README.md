
# WasteLess App

**WasteLess** is a mobile application that helps users track, manage, and share surplus food to reduce waste and combat hunger. Built with Flutter on the frontend and Supabase on the backend, WasteLess leverages real-time synchronization, secure authentication, and push notifications to deliver a seamless experience.

-----

### **Pitch Deck**

[**https://wasteless-smart-househol-52lytur.gamma.site/**](https://wasteless-smart-househol-52lytur.gamma.site/)

-----

### **Problem & Solution**

**Problems:**

  * Food going to waste while people go hungry.
  * Food wastage negatively impacting the economy and environment.

**Solution:**
A mobile app that **tracks inventory**, **notifies users when items are about to expire**, **logs waste**, and facilitates **sharing or donating surplus food**.

-----

### **MVP Feature Set**

  * **User Authentication**: Secure sign-up and sign-in functionality using Supabase.
  * **Inventory Entry**: Add, edit, and remove food items with details such as name, category, and expiry date.
  * **Expiry Alerts**: Push notifications to remind users of items nearing expiration.
  * **Waste Logging**: Record discarded items to track waste and generate insights.
  * **Offer to Donate**: Basic flow for users to offer surplus food to nearby recipients or shelters.

-----

### **Tech Stack & Workflow**

  * **Frontend**: Flutter / Dart
  * **Backend & Database**: Supabase (PostgreSQL, Auth, Realtime, Storage)
  * **Version Control**: Git + GitHub
  * **CI/CD**: GitHub Actions → Staging / Production environment

-----

### **Database Schema**

| Table | Fields | Description |
| :--- | :--- | :--- |
| `users` | `id` (uuid), `email`, `created_at` | Managed by Supabase Auth |
| `inventory_items` | `id` (uuid), `user_id` (fk), `name`, `category`, `expiry_date`, `created_at` | Tracks user food inventory |
| `waste_logs` | `id` (uuid), `user_id`, `item_id`, `quantity`, `logged_at` | Records discarded items |
| `donations` | `id` (uuid), `user_id`, `item_id`, `recipient_info`, `offered_at`, `status` | Manages basic donation offers and status |

**Note**: Enabled Row-Level Security in Supabase and write policies to ensure users only access their own data.

-----

### **Project Setup**

**1. Clone the repository**

```bash
git clone [https://github.com/RespectAi/wasteless_app.git](https://github.com/RespectAi/Final-Project-.git)
cd wasteless_app
```

**2. Install Flutter dependencies**

```bash
flutter pub get
```

**3. Configure Supabase**

  * Create a Supabase project at `https://app.supabase.io`.
  * Note your `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
  * Create required tables as per the schema above.
  * Enable RLS and set up policies.

**4. Add environment variables**

  * Create a `.env` file in the project root:

<!-- end list -->

```
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-key
```

**5. Run the app**

```bash
flutter run
```

-----

### **Development & Deployment**

  * **Feature Branch Workflow**:
      * Create a branch for each feature: `git checkout -b feature/expiry-alerts`.
  * **Pull Requests**:
      * Open PRs against `main`, including screenshots or test steps.
  * **CI/CD**:
      * GitHub Actions runs tests and builds on push. Merges to `main` deploy to staging.

-----

### **Live Features **

  * Implement user authentication and onboarding flow ✅
  * Build inventory CRUD screens in Flutter ✅
  * Integrate Supabase Auth and Database SDK ✅
  * Set up push notifications for expiry alerts ✅
  * Design donation offering and map view ✅
  * Gather feedback via beta testing ✅

-----

### **Upcoming Features** (Pending)

  * **AI-Based Expiry Prediction**: An advanced feature that will predict item expiration dates.
  * **QR Code Scanner**: Quickly add new items to your inventory by scanning QR codes.
  * **Enhanced Categories**: A dedicated section to manage and view items by category.
  * **Shared Fridges/Inventory**: A collaborative feature to manage inventory with multiple users.

Ready to reduce food waste and feed communities? Let’s build WasteLess\!
