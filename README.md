# Covary 🔄

Covary is a behavioral research tool I'm building for my Bachelor's Thesis.

The goal is to look at the **"big picture"** of our daily lives. I'm tracking how different parts of our world - like our mood, physical activity, and even our phone habits - all mixed together affect our well-being. It’s about finding the hidden patterns between what’s happening around us and how we’re actually feeling.

### What's happening under the hood?
I'm connecting the dots between your sport habits, the weather (maybe in the future), your daily mood, sleeping patterns, app consumption, and everything in between.

---

## 📱 How to use it

Since this is a research tool (for now), setting it up takes a minute or two.

### 🤖 For Android
Android is the "main" platform for this research because it lets us track things like app usage.

1.  **Sideload the APK:** Download the latest build from the Releases tab and install it.
2.  **Health Access:** Grant permissions for **Health Connect** so I can see your steps and sleep. (not mandatory!)
3.  **App Usage (The tricky part):** Android 13+ might gray out the "Usage Access" toggle. 
    *   **Fix:** Go to *Settings → Apps → Covary → ⋮ (top right) → Allow restricted settings*. Then you can go back and flip the switch!
4.  **Stay Awake:** Disable "Battery Optimization" for Covary if you want the 4-hour background sync to be reliable.

### 🍎 For iOS
I've recently added iOS support. I dont have one tho, so I haven't tested it yet! It's a bit more "lite" due to Apple's privacy rules.

1.  **Build with Xcode:** You'll need a Mac. Run `flutter build ios`, then open the workspace in Xcode.
2.  **Sign it:** Select your development team in *Signing & Capabilities*.
3.  **HealthKit:** When you first open the Data Permissions screen, grant access to **HealthKit** for steps and sleep duration.
4.  **Note:** iOS doesn't allow tracking "App Usage" for other apps, so that section will be disabled.

---

### 🔒 Your data is yours.
Privacy is the most important thing here. Everything stays locally on your phone.
*   **No Cloud:** I don't have a server. I can't see your data.
*   **Manual Export:** If you want to show me your data for the thesis, you have to manually click **Export** and send me the JSON file yourself.
*   **HCI Metrics:** I track things like how fast you respond to prompts (`latencyMs`) because that tells me a lot about how "intrusive" the app is!

### btw,
If you have an idea or want something implemented, just let me know! This is a work in progress and I'm having a lot of fun building it.

---
**All rights reserved.** This code is public for thesis verification only and may not be used or redistributed.
