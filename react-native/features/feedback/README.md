# `features/feedback`

In-app feedback collection. Solo devs need a tight feedback loop with their small user base — without one, you're guessing at what's broken.

## The pattern

1. A floating "Feedback" button (or settings row) on every screen → opens the feedback sheet.
2. Sheet has 4 category buttons (Bug / Idea / Praise / Other) + free-text input.
3. On submit:
   - Write to Firestore at `users/{uid}/feedback/{id}` with category + body + metadata (app_version, platform, route).
   - Fire `feedback_submitted` event.
   - Show a quick toast: "Thanks — David personally reads every message."
4. A daily Cloud Function (or just `firebase firestore:get` on a cron locally) emails you a digest.

## What gets stored

```ts
{
  uid: string,
  category: 'bug' | 'idea' | 'praise' | 'other',
  body: string,
  app_version: string,
  platform: 'ios' | 'android' | 'web',
  route: string,           // where they were when they tapped feedback
  created_at: Timestamp,
}
```

No email is collected explicitly — if they want a reply, they sign in (you already have the uid, and Auth has their email).

## Why this pattern

- **Categories filter signal from noise.** You can mark "Bug" feedback as P1+ instantly without reading 200 ideas.
- **Route context catches "this screen is broken" patterns** without the user having to describe where they were.
- **Praise is a category** — solo devs underestimate how much "this is nice" feedback matters for motivation. Filter it; read it on bad days.
- **Email-free** lowers the friction of submitting. The uid bridges back when you need to reply.

## Files (when wired)

```
features/feedback/
  useFeedback.ts          mutation hook, fires the event, writes to Firestore
  components/
    FeedbackButton.tsx    floating button or settings row
    FeedbackSheet.tsx     bottom sheet with category + text input
  lib/firebase/feedback.ts  (in lib/firebase/ — typed wrapper via /firestore)
```

Use `/firestore feedback uid:string category:string body:string` to scaffold the wrapper, then `/hook useFeedback feedback` to scaffold the mutation.

## Reading the firehose

For an MVP scale (≤500 active users), the simplest path is good enough:

- Daily: open Firebase Console → Firestore → `feedback` collection → sort by `created_at` desc.
- Weekly: included in the `/weekly-review` command output (it pulls the last 7 days of feedback).

When volume grows past ~10/day, set up a Cloud Function to forward each new doc to a Slack channel / Discord / email digest.
