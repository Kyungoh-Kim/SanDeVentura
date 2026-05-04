# SanDeVentura Constitution

## Core Principles

### I. Hiking Safety First
SanDeVentura exists to reduce wrong turns and uncertainty during hiking, especially in small mountains and informal trails where map coverage is weak. Requirements, plans, and tasks MUST prioritize route confidence, clear user decisions at forks, and graceful behavior under poor connectivity over social, gamification, or growth features.

### II. Offline-First Field Reliability
Core hiking flows MUST remain useful without network access. A user MUST be able to start a hike, keep recording location points, recover an active session after app restart, and understand current recording state while offline. Network-dependent features MUST be framed as synchronization or enrichment, not as prerequisites for field safety.

### III. Location Privacy and Data Minimization
Location data is sensitive. Specifications MUST state why each location-related field is collected, how long it is needed for the MVP scenario, and which user action or system event causes upload. User-facing features MUST avoid exposing another user's raw path or identity unless a later specification explicitly adds sharing consent and access rules.

### IV. Testable Requirements Before Implementation
Every P0 user story MUST include an independent test and Given/When/Then acceptance scenarios before technical planning begins. Any requirement that cannot be verified through a user action, observable system response, stored state, or measurable metric MUST be rewritten or removed.

### V. Technology-Neutral Specification, Explicit Technical Plan
Feature specifications MUST describe user outcomes, domain rules, entities, and measurable success criteria without committing to a technology stack. Technology choices, architecture, APIs, storage engines, map providers, batch strategy, and implementation tradeoffs belong in the Spec Kit plan stage after the spec is accepted.

## Scope Discipline

The MVP specification MUST include only the end-to-end safety loop: pre-hike reference trail access, offline recording, session restoration, post-connectivity upload, canonical trail availability, location-to-trail comparison, and confidence display. Real-time rescue/command-center features, full community features, ranking, mileage competition, and photo-based terrain recognition AI are out of scope until a later spec explicitly introduces them.

## Development Workflow

The authoritative source is the Spec Kit Markdown in this repository. Notion pages are source material only. Existing Flutter/Firebase code is treated as discarded reference material and MUST NOT constrain the MVP specification. The required workflow is: constitution update, MVP specification, clarification/checklist review, then implementation plan. The implementation plan MUST compare viable technology options instead of inheriting the discarded prototype stack or the earlier draft stack by default.

## Governance

This constitution supersedes older planning notes and prototype implementation behavior. Changes require a dated amendment that records the reason, affected specs, and migration impact. A spec cannot proceed to planning while it contains unresolved clarification markers, missing P0 acceptance scenarios, or hidden technology decisions.

**Version**: 1.0.0 | **Ratified**: 2026-05-04 | **Last Amended**: 2026-05-04
