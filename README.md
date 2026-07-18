# Sunday League v11 — Home Screen Web Push

This is still a website. It does not require the App Store or Google Play.

## Notifications included

- A registered player creates a new match
- The match creator confirms the final time
- A player taps `I've Arrived at the Field`

The notifications can appear when the Home Screen website is closed.

## Deploy the website

1. Run `v11_push_notifications_migration.sql` in Supabase SQL Editor.
2. Copy these items into the root of your GitHub repository:
   - `index.html`
   - `manifest.webmanifest`
   - `service-worker.js`
   - `push-config.js`
   - the entire `icons` folder
3. Keep your configured `supabase-client.js`.
4. Commit and push to GitHub.
5. Wait for Vercel to redeploy.

## Deploy the Supabase Edge Function

The function source is:

`supabase/functions/send-web-push/index.ts`

From the project folder, run:

```bash
npx supabase login
npx supabase link --project-ref ayqfacnbtttiyhdwytaz
npx supabase secrets set VAPID_PUBLIC_KEY="BNm0-cirwbvoZkCxpKU5x4XiodUMC1r8mxLd88T5lBfC5PPTNaBNiASG9cKrCqHdNdTA2ZfWPfsiLKSOc-jOWaA" VAPID_PRIVATE_KEY="<COPY_FROM_PRIVATE_SECRET_FILE>" VAPID_SUBJECT="https://sunday-league-gamma.vercel.app"
npx supabase functions deploy send-web-push
```

The private key is intentionally excluded from the project ZIP.
Use the separately supplied `VAPID_PRIVATE_SECRET_DO_NOT_COMMIT.txt`.

## iPhone/iPad setup for each friend

1. Open the Vercel link in Safari.
2. Tap Share.
3. Tap Add to Home Screen.
4. Open Sunday League from the new Home Screen icon.
5. Register a player profile.
6. Open Players.
7. Tap Enable notifications.
8. Tap Allow.

## Android setup for each friend

1. Open the Vercel link in Chrome.
2. Use Add to Home screen or Install app.
3. Open Sunday League from the icon.
4. Register a profile.
5. Open Players and tap Enable notifications.
6. Tap Allow.

## Important

- Each device must opt in once.
- Clearing browser/site data removes the subscription.
- The private VAPID key must never be committed to GitHub.
- iPhone notification permission must be requested from the Home Screen web app, not from an ordinary Safari tab.
