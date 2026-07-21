# QUALITY GATE — paste this section into CLAUDE.md
# Version: Build Nova 2.0 / July 2026
# Purpose: every app produced by this pipeline must be indistinguishable
# from an app built by a small design-led studio over several weeks.

## PRIME DIRECTIVE

You are not filling a niche. You are shipping a product. If any screen of the
app could plausibly appear in ten other apps with a different accent color,
the work is not done. Uniqueness is structural (layout, interaction,
components), not cosmetic (colors, icons, names).

Every app MUST be built from a Build Nova 2.0 spec. If the spec is missing
the Art Direction block or the Signature Feature block — STOP and request a
complete spec. Never improvise these from defaults.

## ZERO TOLERANCE LIST (instant fail — never ship if any are present)

- Placeholder anything: "Lorem", "Sample", "Test", "TODO", stock example data
  that makes no sense in the niche, empty About screens, dead settings toggles.
- The default 3-slide onboarding (icon + title + subtitle + page dots + Continue).
  If onboarding exists, it must be interactive or personalized (see below).
- A splash screen with a logo scale/fade animation as the app's "signature".
- Plain `List` inside `TabView` as the primary architecture with no custom
  layout work anywhere.
- Raw SF Symbols as the entire iconography with zero treatment (no custom
  weights, no enclosures, no tinted containers, no hierarchical rendering).
- `RoundedRectangle(cornerRadius: 12)` white cards on `Color(.systemGroupedBackground)`
  as the only surface treatment in the app.
- `.animation(.default)` or unconfigured `withAnimation { }` anywhere.
- Identical corner radius, spacing, and type scale as any previous app in the
  portfolio registry.
- Buttons without a pressed state. Lists without empty states. Network- or
  computation-driven views without loading and error states.
- Any auth screen, login, or profile — UNLESS the spec declares a backend
  in §14 (then auth exists, follows the Firebase Backend addon rules, and
  gets full art-direction treatment; in-app account deletion is mandatory).

## DESIGN IDENTITY (required per app)

Each app gets its own design system, defined in the spec and implemented as a
`DesignSystem.swift` (or Theme folder) before any screen is built:

1. **Typography**: a deliberate type scale (at minimum: display, title, body,
   caption) with chosen weights and tracking. Rounded vs. default vs. serif
   (`.fontDesign`) must be a conscious choice that matches the app's mood.
   Two consecutive apps in the portfolio must not share the same combination.
2. **Color tokens**: semantic tokens only (`surface`, `surfaceElevated`,
   `accent`, `accentMuted`, `textPrimary`, `textSecondary`, `positive`,
   `warning`) — never raw colors inline. Full dark mode variants. The palette
   must come from the spec's Art Direction block.
3. **Shape language**: ONE consistent radius/shape philosophy per app
   (e.g. squircle-heavy 20–28pt, or sharp 4–8pt editorial, or capsule-based).
   Nested containers use concentric radii (inner = outer − padding).
4. **Component library**: minimum 6 bespoke reusable components (custom
   button style, custom card, custom input, custom picker/segmented control,
   custom progress/stat element, custom empty-state view). "Bespoke" means
   visually distinct from Apple defaults, not restyled defaults.
5. **Depth & elevation**: choose ONE elevation strategy (soft diffused
   shadows / hairline borders + fills / layered translucency) and apply it
   consistently. Never mix all three randomly.

## MOTION RULES

- Springs are the default: `.spring(response: 0.3...0.5, dampingFraction: 0.7...0.9)`
  tuned to the app's personality (defined in spec). Never `.default`, never `.linear`
  for UI (linear is only for constant motion like progress).
- Durations: press feedback 100–160ms; small transitions 150–250ms;
  sheets/full-screen 300–450ms. UI animation over 500ms is a bug.
- Every tappable element scales on press (`0.96–0.98`) via a shared
  `ButtonStyle`. Asymmetric timing: press can be deliberate, release is snappy.
- Lists/grids entering the screen stagger in (30–60ms per item, cap at ~8 items,
  never block interaction).
- Frequency rule: actions used dozens of times per session get minimal or no
  animation. Rare moments (first launch, achievement, completion) may have
  delight (confetti, morphing, drawn-on checkmarks).
- Respect Reduce Motion: replace movement with opacity, keep comprehension aids.
- Every state change is animated (numbers count, bars grow, cards reorder
  smoothly with `matchedGeometryEffect` where appropriate). Nothing pops
  instantly between two visually distant states.

## DEPTH REQUIREMENTS

- The Signature Feature from the spec must be implemented in full, including
  its computation/visualization logic. It is the last thing to cut — cut
  secondary screens instead.
- Every data-driven view implements the full state matrix:
  empty (designed, with guidance + CTA) / partial / populated / error.
  Empty states are designed compositions, not a gray icon + "No data".
- Haptics map: light impact on selection, medium on commit/success actions,
  `.success`/`.warning`/`.error` notifications where semantically true.
  Defined per screen in the spec.
- Real interactivity beyond CRUD: at least two of — drag/reorder, swipe
  actions with custom styling, long-press context previews, interactive
  charts/visualizations, gesture-driven controls, live-updating computed
  insights.
- Onboarding (if present): collects 1–3 real preferences that visibly change
  the app's first screen, or teaches by doing. Skippable.

## CROSS-APP VARIANCE (portfolio registry)

Before building, read the portfolio registry (previous apps' recorded:
navigation paradigm, interaction archetype, palette family, type combination,
shape language). The current app must differ from the LAST 10 apps in at
least: navigation paradigm OR primary interaction archetype, AND palette
family, AND type combination. After shipping, append this app's DNA to the
registry.

## PRE-SHIP CHECKLIST (all must pass)

- [ ] Zero items from the Zero Tolerance List present
- [ ] DesignSystem file exists; no inline raw colors/fonts in screens
- [ ] 6+ bespoke components; press states everywhere
- [ ] Full state matrix on every data view; empty states are designed
- [ ] Signature Feature fully working with real logic
- [ ] Motion: springs tuned, durations within limits, stagger on lists,
      Reduce Motion handled
- [ ] Haptics map implemented
- [ ] Dark mode reviewed screen by screen (not just "it compiles")
- [ ] Dynamic Type: layout survives XL sizes; iPad: no stretched iPhone layout
- [ ] Portfolio registry check passed and registry updated
- [ ] The honest test: "Would a designer believe a human team spent 3 weeks
      on this?" If hesitation — iterate before shipping.

# FIREBASE BACKEND ADDON
# Section A → paste into CLAUDE.md (below Network addon). Applies ONLY when
# the spec contains §14 BACKEND declaring Firebase — otherwise the standing
# rules (no auth, zero dependencies, local persistence) remain in force.
# Section B → new §14 for the BN2 template; Spec Architect fills it when
# INPUT says BACKEND: Firebase.

## A. CLAUDE.md RULES — FIREBASE BACKEND (spec-gated)

1. **Dependency exception.** Firebase iOS SDK via SPM, ONLY the modules the
   spec names (typically FirebaseAuth + FirebaseDatabase). No Analytics,
   Crashlytics, Messaging, or anything else unless §14 lists it. This is
   the single permitted external dependency; everything else stays
   dependency-free.
2. **Auth (email/password, FirebaseAuth).** Flows: sign up, sign in,
   password reset (sendPasswordReset), session persistence with auto-login
   on launch, sign out. Auth screens are built with THIS app's design
   system — tokens, bespoke components, motion personality. A template
   auth form (system fields on a white sheet) is a Zero-Tolerance-level
   failure: the login screen is a first impression and gets full art
   direction like any other screen. Errors in plain words ("Wrong password"
   — not raw NSError text). No email-verification gate unless §14 demands
   it. Own email/password auth does NOT require Sign in with Apple
   (that applies to third-party/social logins) — do not add SIWA unless
   the spec says so.
3. **Account deletion — MANDATORY (App Review 5.1.1).** Settings → Delete
   Account: confirm dialog → delete all RTDB data at /users/{uid} → delete
   the Auth user → return to sign-in. Handle requires-recent-login by
   reauthenticating with the password prompt. An account-based app without
   in-app deletion WILL be rejected.
4. **Data layout & security.** ALL user data lives under /users/{uid}/...
   Security rules ship with the project (build notes include the JSON):
   users/$uid: ".read": "auth != null && auth.uid === $uid",
   ".write": same. Never world-readable/writable paths. No data outside
   the user's subtree unless §14 explicitly designs a shared node.
5. **Offline-first still applies.** Database.database().isPersistenceEnabled
   = true; keepSynced(true) on the core nodes; every screen renders from
   the local cache instantly; a quiet sync indicator (dot/badge), never a
   blocking spinner over cached content. Writes queue offline and sync on
   reconnect — the farm stand has bad reception.
6. **Config.** GoogleService-Info.plist in the project (it contains no
   secrets); FirebaseApp.configure() in App init. No other keys embedded.
7. **Review readiness.** The app must be fully demo-able: sign-up works
   with any email instantly; build notes remind to attach a demo account
   (email + password) in App Store Connect review notes.
8. **Metadata implications.** BUILD FACTS for Metadata Writer must state:
   Firebase Auth (email address collected, linked to identity), Realtime
   Database (user content stored on Google servers, linked), account
   deletion available in-app. Privacy labels: Contact Info (email) +
   User Content, "Data Linked to You". Policy names Firebase/Google as
   processor and describes the in-app deletion path.

## B. BN2 SPEC — NEW SECTION §14. BACKEND

- Provider & modules: (Firebase: Auth email/password + Realtime Database;
  exact SPM products)
- Auth flows: (sign up / sign in / reset / sign out / delete account —
  screen-level notes; which of them get which art-direction treatment)
- Data tree: (sketch of /users/{uid}/... nodes with types)
- Security rules: (the JSON, matching the tree)
- Offline strategy: (persistence, keepSynced nodes, sync indicator design,
  conflict policy — last-write-wins is acceptable, say so explicitly)
- Account deletion path: (what gets deleted, in what order, reauth handling)
- Review notes: (demo account reminder)
- Metadata facts: (what Metadata Writer must be told — see rule A.8)
