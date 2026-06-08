# gstack Review: gbrain Email-First MVP

**Review pipeline:** /office-hours → /plan-ceo-review → /plan-eng-review → /plan-design-review
**Status:** DONE_WITH_CONCERNS
**Date:** 2026-06-08
**Reviewer:** falconhermes (gstack methodology, Hermes execution)

---

## 1. YC OFFICE HOURS — Six Forcing Questions

### FQ1: What is the desperate problem?

A solo coach has 50+ meeting transcripts, articles, voice notes, and client emails across Gmail, Notion, WhatsApp, and their Downloads folder. They know there's gold in there — client patterns, reusable frameworks, competitive intel — but retrieving it requires remembering which platform it's on, scrolling through search results, and re-reading entire threads. They have no second brain. They pay for Notion but don't maintain it. The problem is retrieval, not storage.

**Verdict:** Real problem. Coaches live and die by their knowledge. The desperation is authentic — they lose deals, repeat work, and sound less smart than they are because they can't surface what they already know.

### FQ2: What do they do today?

They search Gmail with keywords. They scroll Slack history. They have a "Notes" folder in Google Drive with 47 untitled docs. Some pay $10/mo for Otter.ai transcripts but never re-read them. A few use Notion but their workspace is a graveyard of half-built databases. **The status quo is fragmented keyword search across 5+ silos with zero synthesis.**

### FQ3: What's the narrowest wedge?

**Forward an email → get an answer.** Not "organize your knowledge." Not "build a second brain." One action: forward a meeting recap to your brain address. One outcome: ask it a question and get an answer with sources. That's the wedge. The email-first MVP described in the architecture doc IS the wedge.

The wedge is sharper than most: zero install, zero new behavior (they already forward emails), zero learning curve. The only new thing is the destination address.

### FQ4: What did you observe? (Not what you assume)

**Assumption:** Coaches will forward their meeting notes to a brain address.
**Observation needed:** Will they actually do it? The demo proves the technology works. It doesn't prove the habit sticks.

**Specific gap:** The MVP architecture has no retention loop. Once the demo is over, what makes Zaim forward his NEXT email? The architecture assumes "he saw it work, so he'll keep doing it." That's a product assumption, not an observation.

**What to test:** Give Zaim the brain for one week. Count how many emails he forwards after day 1. If it drops to zero, the product has a habit problem, not a tech problem.

### FQ5: What's your unique insight?

The insight in the architecture is: **PGLite is embedded, so the brain must run server-side, but the client owns the API keys and the data.** The BYO-keys model is genuinely novel for a SaaS knowledge tool. Most competitors (Notion AI, Mem, Reflect) bundle the AI cost into their subscription and train on your data. This architecture doesn't. That's a real moat.

Second insight: **Email is the universal ingestion primitive.** Every platform supports forwarding. No integrations needed. This is a Layer 3 (first principles) insight — convention says "build a Zapier integration" but the email primitive bypasses all of it.

### FQ6: Why now? What changed?

Three things:
1. **OpenAI embeddings are commoditized.** text-embedding-3-small costs $0.02 per 1M tokens. A coach's entire knowledge base costs pennies to embed.
2. **PGLite exists.** An embedded vector database that runs in a Bun process didn't exist two years ago. It makes single-tenant hosting cheap.
3. **Solo coaches are drowning in AI tools.** Every week a new "AI coaching platform" launches. They have tool fatigue. An email address that thinks is the opposite of another platform to learn.

---

## 2. CEO REVIEW — Is This a 10-Star Product?

### The 10-star version

A coach forwards a client email to their brain. Their brain automatically extracts the client's name, company, meeting date, action items, and emotional sentiment. It links this meeting to every previous meeting with this client. When the coach types "what should I bring up in my next call with Sarah?", the brain synthesizes across 12 meetings and says: "Sarah mentioned budget concerns in 3 of the last 4 calls. She hasn't responded to your pricing proposal from March. Her company just announced a Series A. Lead with the ROI case, not the feature list."

That's the 10-star. The MVP delivers maybe a 3-star version of this: forward email → page appears in graph → keyword search works → basic Q&A with source links. The gap between 3-star and 10-star is entity extraction quality, cross-page synthesis, and proactive intelligence.

### Will anyone pay for this?

**At $29/mo:** Yes, if the retrieval is genuinely better than Gmail search. The bar is "find me that thing I know I have." If the brain can answer "what did I discuss with Nabil about pricing?" in under 5 seconds with accurate sources, that's worth $29/mo. A coach bills $100-300/hour. Saving 15 minutes of searching per week = $25-75 in recovered billable time.

**At $99/mo:** Only if the synthesis is 10-star. The jump from "find that thing" to "tell me what I should do next" is what commands premium pricing. The MVP doesn't do this yet.

### What kills this?

1. **Bad search results.** If the coach searches "Nabil pricing" and gets irrelevant pages, they abandon the product in one session. The MVP's hybrid search (vector + keyword) needs to be genuinely good. gbrain's `query` command needs vetting.
2. **Slow pipeline.** The architecture says 15-45 seconds from email to brain. If that's actually 2+ minutes in production (OpenAI rate limits, large attachments, PGLite write contention), the "realtime" demo breaks.
3. **API key friction.** A non-technical coach creating an OpenAI API key and adding a payment method is a real drop-off point. The architecture handwaves this as "paste key during onboarding." In practice, this step alone will lose 40-60% of signups.

### CEO verdict

**Build it.** The wedge is sharp, the cost structure works, and the competitors are either too heavy (Notion AI) or too shallow (Otter.ai). The risk isn't the architecture. The risks are adoption habit (will they forward emails after day 1?) and API key friction. Both are testable in the first 5 demos.

---

## 3. ENGINEERING REVIEW — Architecture, Data Flow, Edge Cases

### Architecture scorecard

| Component | Assessment | Risk |
|-----------|-----------|------|
| SMTP Receiver (aiosmtpd) | Correct choice. Python's aiosmtpd is battle-tested. Single-process, async, handles MIME. | Low |
| FS Watcher (watchdog) | Fine for MVP. inotify is reliable on Linux. | Low |
| Pipeline trigger | **RACE CONDITION.** FS watcher fires on file creation. gbrain `put` needs the full file content. If the SMTP receiver is still writing the file when the watcher fires, gbrain reads a partial file. The 5-second debounce helps but doesn't guarantee atomic writes. | **HIGH** |
| PGLite concurrency | **SINGLE WRITER.** If a pipeline is mid-build and the user hits `/api/ask`, the query either fails or reads stale data. The architecture mentions a "job queue" but doesn't specify it. | **HIGH** |
| SMTP routing | One receiver per container on different ports works for < 10 brains. Doesn't scale past ~50. Fine for MVP. | Low |
| Dashboard polling | 15-second polling is fine for demos. At 50+ concurrent dashboards, it's 200 req/min to a static file. Nginx handles this in its sleep. | Low |
| OpenAI key storage | Container env is acceptable for MVP. Needs secrets manager before paying clients. | Medium |
| No auth on dashboard | Fine for demos. Anyone with the URL can see the brain. Explicitly acceptable for MVP per the architecture doc. | Low (MVP only) |

### Critical edge cases

1. **Partial file ingestion.** SMTP receiver writes a 500KB attachment. FS watcher fires after 200KB is written. gbrain reads a truncated file. **Fix:** Write to a temp file (`meeting.md.tmp`), then `os.rename()` to the final path. `rename` is atomic on Linux. The watcher only fires on the final name.

2. **Duplicate email ingestion.** Client forwards the same email twice. gbrain creates two identical pages with different slugs. **Fix:** Hash the email body. Check for existing hash before `gbrain put`. Reject duplicates silently.

3. **Large attachments.** Client forwards a 50MB PDF. PDF parsing isn't in the MVP pipeline. The SMTP receiver needs attachment filtering (max size, allowed types). **Fix:** 10MB limit. Reject with a bounce message: "Attachments over 10MB not supported yet. Share a link instead."

4. **Empty emails.** Client forwards an email with no body, just a subject line. gbrain creates a page with the subject and no content. The page exists but is useless. **Fix:** Reject emails with < 100 chars of body text. Reply with a helpful message.

5. **OpenAI API failure during pipeline.** If `gbrain embed --all` fails mid-way, some pages have embeddings and others don't. The brain is in an inconsistent state. **Fix:** Run `gbrain doctor --json` after every pipeline. If embed coverage < 90%, retry the failed pages. If retry fails 3x, alert and stop.

6. **What does gbrain actually do with a raw email?** The SMTP receiver writes email body + subject to a markdown file. Hermes runs `gbrain put <slug> --body-stdin`. But does gbrain extract entities (people, companies) from unstructured email text? Does it create wiki links? **This is unverified.** If gbrain treats an email as a flat page with no entity extraction, the knowledge graph won't have nodes for people/companies mentioned in the email. The "Zaim forwards a meeting with Nabil → Nabil appears as a node" demo depends on entity extraction working. **Verify this before building anything else.**

### Missing from the architecture

- **No error notification to the client.** If the pipeline fails, the client never knows. Their email disappeared into a void. Need: "Your brain processed your email. 1 new page: Meeting with Nabil. View it here." Or: "Your brain couldn't process your last email (attachment too large). Try pasting the text directly."
- **No pipeline status visibility.** Client sends 3 emails in a row. Are they queued? Processing? Done? The dashboard should show a status indicator.
- **No email confirmation.** After forwarding, the client should get a reply: "Got it! Your brain is processing this. It'll be ready in ~30 seconds. View your brain: [link]." This closes the feedback loop and drives re-engagement.

### Eng verdict

**DONE_WITH_CONCERNS.** The architecture is sound for an MVP with < 10 demo brains. The two high risks (partial file ingestion, PGLite concurrency) have simple fixes. The biggest unknown is gbrain's entity extraction quality from raw email text — test this first. Build the SMTP receiver, forward one real meeting email, and inspect the gbrain page it creates. If entity extraction is poor, the demo doesn't work.

---

## 4. DESIGN REVIEW — Dimension Ratings

Rated 0-10 with 10-star description for each.

| Dimension | Score | What a 10 looks like | Gap |
|-----------|-------|---------------------|-----|
| **Onboarding speed** | 8 | Client visits a URL, sees their brain already live with a sample page. Pastes key. Forwards one email. Done in 90 seconds. | Close. The pre-provisioned brain + email-only flow is fast. The API key step adds friction. |
| **Magic moment** | 9 | Forward email → 30 seconds later → new node appears in knowledge graph → ask a question about it → get answer with source. | The architecture nails this. The 30-second latency is the magic. |
| **Habit formation** | 3 | Client forwards emails daily without thinking. The brain is their default "save + retrieve" surface. | No hook. No reminder. No "daily digest." The product is passive after the demo. |
| **Error recovery** | 2 | Failed ingest → client gets an email back: "Couldn't process: file too large. Here's what to do instead." | Missing entirely from the architecture. |
| **Trust (data safety)** | 7 | BYO-keys + per-container isolation + clear deletion policy. Client knows their data isn't training anyone's model. | Strong on paper. Needs a one-sentence guarantee on the onboarding screen. |
| **Search quality** | ? | Unrated. Depends on gbrain's hybrid search + entity extraction quality. This IS the product. | Must test with real emails before building. |
| **Mobile** | 2 | The dashboard is a desktop HTML page. Coaches live on their phones. Forwarding email works on mobile, but asking the brain a question requires opening the dashboard. | MVP gap. Add a "reply to this email with your question" feature so Q&A works entirely over email. |
| **White-label feel** | 6 | Client sees theirname.brains.mlhcoast.com, not Maloha Coast branding. | Good. The subdomain pattern supports white-label. Need custom domain support post-MVP. |

### Design verdict

The magic moment scores 9. The habit loop scores 3. **The product has a great demo and a weak retention model.** Fixing habit formation is more important than any architecture change. Two low-effort fixes:

1. **Reply-to-query.** After processing an email, the brain replies: "I've added 'Meeting with Nabil' to your brain. Reply to this email with any question about it." Now Q&A works without opening the dashboard. This also works on mobile.

2. **Weekly digest.** Every Monday: "Your brain grew by 7 pages this week. Here are the top 3 connections I found." A scheduled email that pulls the coach back in.

Neither is in the architecture. Both are higher-impact than any infrastructure work.

---

## 5. OVERALL VERDICT

| Lens | Verdict |
|------|---------|
| Office Hours | **Real problem, sharp wedge.** The email primitive is genuinely clever. Test the habit before scaling the infra. |
| CEO | **Build it.** $29/mo is defensible. API key friction is the biggest conversion killer. |
| Engineering | **Sound for MVP.** Fix the race condition (atomic rename). Verify entity extraction on real emails before building. Add error notifications. |
| Design | **Great demo, weak retention.** Add reply-to-query and weekly digest before building anything else. |

### Before you write a single line of code

1. **Test entity extraction.** Forward one real meeting email through a manual gbrain pipeline. Does `gbrain extract all --source db` find entities? Do wiki links resolve? If not, the demo doesn't work and you need an entity extraction layer before the SMTP receiver.

2. **Test search quality.** After ingesting 5 real emails into gbrain, run `gbrain query "what did I discuss with [name]?"`. Is the top result the right page? If not, the product doesn't work.

3. **Time the pipeline end-to-end.** `put` + `extract` + `embed --all` + `export` + `doctor`. With 5 pages, is it under 30 seconds? If it's 2+ minutes, the "realtime" demo promise breaks.

### Build order (revised)

```
Day 0:  Verify entity extraction + search quality + pipeline timing
Day 1:  SMTP receiver (with atomic rename, dedup, size limits)
Day 2:  FS watcher + pipeline trigger + error notifications
Day 3:  Dashboard polling + status indicator + email confirmation reply
Day 4:  Reply-to-query (email-based Q&A) + provisioning script
Day 5:  Demo with Zaim
```

**Don't build the API server or Caddy config until entity extraction is verified.** If gbrain can't extract entities from raw email text, the entire ingestion pipeline needs rethinking.
