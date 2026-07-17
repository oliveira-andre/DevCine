<!--
SYNC IMPACT REPORT
==================
Version change: 1.1.0 → 1.1.1
Bump rationale: PATCH — clarified Principle VI to state that all caching MUST go through
`Rails.cache` (e.g. `Rails.cache.fetch`) as the single mandatory mechanism, with no other
caching approach permitted. No new principle; no semantic change to obligations.

Prior amendment (1.0.0 → 1.1.0, MINOR): added Principle VI. Cache-by-Default with
Automatic Invalidation plus supporting Technology Standard and Quality Gate.

Modified principles:
  - VI. Cache-by-Default with Automatic Invalidation (clarified mechanism: Rails.cache)
Added principles: N/A
Added sections: None (extended Technology & Architecture Standards and Development
  Workflow & Quality Gates with caching entries)
Removed sections: None

Templates requiring updates:
  ✅ .specify/templates/plan-template.md (Constitution Check derives gates from this file
    generically; no edit required)
  ✅ .specify/templates/spec-template.md (no principle enumeration; no edit required)
  ✅ .specify/templates/tasks-template.md (no principle enumeration; tests remain REQUIRED
    per Principle II as previously flagged)

Follow-up TODOs: None
-->

# DevCine Constitution

DevCine is a streaming application that combines a Disney+-style premium, cinematic
experience with YouTube-style functionality layered inside it. It is built on Ruby on
Rails with the Hotwire stack. This constitution defines the non-negotiable engineering
principles that govern every feature, task, and review.

## Product Scope

DevCine's experience is **mostly Disney+** in look, feel, and navigation — a dark,
premium, franchise-first streaming interface — **augmented with YouTube features**
embedded within it (e.g. user-oriented video interactions and discovery patterns
familiar from YouTube). Both product dimensions MUST coexist coherently: the Disney+
aesthetic and structure lead, while YouTube-style functionality extends what users can
do. `DESIGN.md` governs the visual language for both.

## Core Principles

### I. Hotwire/Turbo-First Architecture

All interactive behavior MUST be implemented with the Hotwire/Turbo stack (Turbo
Drive, Turbo Frames, Turbo Streams, and Stimulus) as the default strategy; custom
client-side JavaScript frameworks are prohibited without an explicit, documented
exception. Creating and editing records (`new` and `edit` routes) MUST be presented
in a modal that is Turbo-rendered and available consistently from any page. Server
responses MUST drive UI updates via Turbo Streams rather than bespoke client logic.

**Rationale**: A single, consistent rendering strategy keeps the app fast, reduces
JavaScript surface area, and guarantees the modal-based CRUD experience behaves
identically everywhere.

### II. Comprehensive Test Coverage (NON-NEGOTIABLE)

Every feature and every task MUST ship with automated tests written in RSpec. The
minimum coverage is:

- **Backend**: request/controller specs and model specs for all business logic and
  endpoints.
- **Frontend & behavior**: system specs driven by Capybara with the Selenium driver
  for user-facing flows (including Turbo modal interactions).

In addition, every completed task MUST be exercised and confirmed working through the
Playwright MCP against a running instance before it is considered done. A task with
failing or absent tests is not complete. Tests MUST be authored alongside (or before)
the implementation they cover.

**Rationale**: Streaming UX has many moving parts (modals, streams, playback); only
layered automated coverage plus live MCP verification keeps regressions out.

### III. Mobile-First, Multi-Platform Parity

The application is mobile-first. Every UI change MUST be designed and verified on
mobile first — via the PWA and Hotwire Native presentation — before being verified on
desktop. Desktop and mobile MUST present the same information and capabilities and feel
cohesive, while being allowed to differ in layout (they are similar, not identical).
A change that only works or has only been checked on desktop is incomplete.

**Rationale**: The primary audience consumes content on phones; designing for the
constrained surface first prevents desktop-only assumptions from leaking into the app.

### IV. Design System Fidelity

`DESIGN.md` is the single source of truth for visual language, tokens, color, motion,
and component patterns; all styling decisions MUST trace back to it. CSS MUST be
scoped per page (page-specific stylesheets), while cross-cutting concerns — typography,
variables, and other shared tokens — MUST live in a `shared/` folder and be reused
rather than duplicated. Hard-coded values that bypass shared tokens are prohibited.

**Rationale**: Centralized tokens plus page-scoped styles keep the cinematic Disney+
aesthetic consistent and prevent style drift as the app grows.

### V. Uninterrupted Playback (NON-NEGOTIABLE)

Video playback is the core purpose of DevCine and MUST be resilient. When the user
locks or blocks the screen, audio/video playback MUST continue. Playback MUST pause
ONLY when the user explicitly invokes pause. No background, navigation, lifecycle, or
lock-screen event may pause or stop playback on its own. Any feature touching the
player MUST include tests and live verification of this behavior.

**Rationale**: Continuous playback through screen-lock is the defining product promise;
silent interruptions break the core experience.

### VI. Cache-by-Default with Automatic Invalidation

Read access to persisted data MUST be cached. Every model query that serves a read —
whether a single record or a collection (categories, videos, playlists, and any other
model) — MUST be served through `Rails.cache` rather than hitting the database on
every request. `Rails.cache` (e.g. `Rails.cache.fetch`) is the single, mandatory caching
mechanism: all cache reads and writes MUST go through it. Other caching mechanisms
(view/fragment caching helpers, per-request memoization as a substitute, or bespoke
in-memory stores) MUST NOT be used in its place. The following rules are non-negotiable:

- **Cache on read**: Reads MUST go through `Rails.cache.fetch` (or an equivalent
  `Rails.cache` call) keyed by a deterministic, version-aware key derived from the model
  and its identity plus version (e.g. `cache_key_with_version`, record `id` +
  `updated_at`, or a collection key incorporating `count` and `max(updated_at)`).
- **Invalidate on write**: Any create, update, or destroy MUST expire (stale) the cache
  for the affected record AND for every associated record or collection whose cached view
  includes it. Uploading a new video MUST stale that video's cache and the caches of its
  categories/genres and any collection that lists it; changing a category MUST stale that
  category's cache and every collection derived from it; the same cascade applies to all
  other records.
- **Automatic, not ad-hoc**: Invalidation MUST be wired through model callbacks
  (`after_commit`) and/or `touch:` associations so it cannot be forgotten at a call site.
  Manual, scattered cache-busting is prohibited.
- **No stale reads after a committed write**: A read issued after a write commits MUST
  reflect that write. Correctness always wins over cache retention.
- **Tested both ways**: Every cached path MUST have tests proving (a) the cache-hit path
  avoids redundant queries and (b) a change to the underlying data invalidates the cache.

**Rationale**: A streaming catalog is read-heavy; caching every model query keeps the app
fast at scale, while callback-driven invalidation guarantees users never see stale
categories, videos, or associations after a change.

## Technology & Architecture Standards

- **Platform**: Ruby on Rails with the Hotwire stack (Turbo + Stimulus).
- **Testing tools**: RSpec (controllers, models, requests), Capybara + Selenium for
  system specs, and Playwright MCP for live task verification.
- **Delivery surfaces**: Responsive web, PWA, and Hotwire Native, all sharing the same
  Rails backend and Turbo-rendered views.
- **Styling**: Page-scoped CSS plus a `shared/` directory for typography and design
  tokens, governed by `DESIGN.md`.
- **CRUD UX**: `new`/`edit` flows MUST use Turbo-rendered modals available app-wide.
- **Caching**: Model read queries MUST be served through `Rails.cache` (e.g.
  `Rails.cache.fetch`) with version-aware keys — no other caching mechanism — and writes
  MUST invalidate the affected record and its associated records/collections via model
  callbacks (Principle VI).

## Development Workflow & Quality Gates

For every task, the following gates MUST pass before it is marked complete:

1. Implementation uses the Turbo/Hotwire strategy (Principle I).
2. RSpec backend specs (controllers + models) and Capybara/Selenium system specs exist
   and pass (Principle II).
3. The task is verified working live via Playwright MCP (Principle II).
4. The change is verified on mobile (PWA / Hotwire Native) first, then desktop
   (Principle III).
5. Styling traces to `DESIGN.md` and reuses `shared/` tokens (Principle IV).
6. Any player-related change preserves uninterrupted playback (Principle V).
7. Model read queries are cached and every write invalidates the affected record and its
   associated records/collections, with tests for both the hit and invalidation paths
   (Principle VI).

Pull requests and reviews MUST confirm each applicable gate. Deviations require a
documented justification recorded in the plan's Complexity Tracking section.

## Governance

This constitution supersedes all other development practices. When guidance conflicts,
the constitution wins.

- **Amendments** MUST be proposed via pull request, documented with rationale, and
  approved by the project maintainer before taking effect. Material amendments MUST
  include a migration/update note for any affected templates or code.
- **Versioning** follows semantic versioning: MAJOR for backward-incompatible
  principle removals or redefinitions, MINOR for new principles or materially expanded
  guidance, PATCH for clarifications and non-semantic refinements.
- **Compliance review**: every PR MUST verify adherence to the applicable Quality Gates
  above. Unjustified violations block merge.
- **Runtime guidance**: agents and contributors use the active feature plan and
  `DESIGN.md` for day-to-day development guidance, within the bounds set here.

**Version**: 1.1.1 | **Ratified**: 2026-06-24 | **Last Amended**: 2026-07-13
