# Sunday League v11.1 — Realtime and Sound Fix

## What changed

- Realtime is split into separate table subscriptions so one failing table does not block all updates.
- The authenticated JWT is explicitly attached to Supabase Realtime.
- Channel errors are logged with their full error details.
- Automatic reconnect uses exponential backoff.
- The app refreshes immediately when it returns to the foreground, regains focus, or comes back online.
- A 5-second match-data fallback and 15-second full-data fallback remove the need for manual refresh even if WebSocket delivery fails.
- The header shows `Live`, `Live + backup`, `Reconnecting`, or `Offline`.
- Push received while the app is open is forwarded from the service worker into the page.
- Open-app alerts use a short Web Audio beep after the user enables or tests sound.
- Closed-app notifications request normal sound and vibration, but the operating system still controls whether sound is played.
- The service worker cache version is bumped so old code is replaced.

## Deploy

1. Run `v11_1_realtime_repair.sql` in Supabase SQL Editor.
2. Replace the v11 website files with the contents of this folder:
   - `index.html`
   - `service-worker.js`
   - `manifest.webmanifest`
   - `push-config.js`
   - `icons/`
3. Keep your configured `supabase-client.js`.
4. Keep the existing deployed `send-web-push` Edge Function and VAPID secrets.
5. Commit and push to GitHub.
6. Wait for Vercel to deploy.
7. Fully close the Home Screen website and reopen it.
8. Open Players and tap `Test in-app sound`.

## Phone settings

For system notification sound, ensure:
- Sunday League notifications are allowed
- Sounds are enabled for Sunday League
- the phone is not muted
- Focus / Do Not Disturb is not suppressing alerts

A website cannot force a system sound when the operating system has silenced it.
