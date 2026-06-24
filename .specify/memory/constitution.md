<!--
SYNC IMPACT REPORT
==================
Version change: TEMPLATE (unversioned) → 1.0.0
Bump rationale: Initial ratification — first concrete constitution replacing the
unfilled template. MAJOR baseline established.

Modified principles: N/A (initial adoption)
Added principles:
  - I. Hotwire/Turbo-First Architecture
  - II. Comprehensive Test Coverage (NON-NEGOTIABLE)
  - III. Mobile-First, Multi-Platform Parity
  - IV. Design System Fidelity
  - V. Uninterrupted Playback (NON-NEGOTIABLE)
Added sections:
  - Product Scope
  - Technology & Architecture Standards
  - Development Workflow & Quality Gates
Removed sections: None

Templates requiring updates:
  ✅ .specify/templates/plan-template.md (Constitution Check gate aligns; no edit required)
  ✅ .specify/templates/spec-template.md (tests already mandatory here; no edit required)
  ✅ .specify/templates/tasks-template.md (test tasks now mandatory per Principle II — see note below)
  ⚠ .specify/templates/tasks-template.md states tests are OPTIONAL; generators MUST
    treat tests as REQUIRED for this project per Principle II. Flagged for manual
    follow-up if the template is regenerated.

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

## Technology & Architecture Standards

- **Platform**: Ruby on Rails with the Hotwire stack (Turbo + Stimulus).
- **Testing tools**: RSpec (controllers, models, requests), Capybara + Selenium for
  system specs, and Playwright MCP for live task verification.
- **Delivery surfaces**: Responsive web, PWA, and Hotwire Native, all sharing the same
  Rails backend and Turbo-rendered views.
- **Styling**: Page-scoped CSS plus a `shared/` directory for typography and design
  tokens, governed by `DESIGN.md`.
- **CRUD UX**: `new`/`edit` flows MUST use Turbo-rendered modals available app-wide.

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

**Version**: 1.0.0 | **Ratified**: 2026-06-24 | **Last Amended**: 2026-06-24
