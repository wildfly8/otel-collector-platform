# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`

**Created**: [DATE]

**Status**: Draft

*New features start **Draft** at `/speckit-specify`. **Approved** is set automatically by `npm run domain:check` when all spec-stage domain proofs pass (constitution v2.10.15 — SDD approval gate). Do not call `/speckit-plan` until **Approved**.*

**Input**: User description: "$ARGUMENTS"

## Summary *(plain language — read this first)*

<!--
  Human-facing overview. No DDD jargon (no "bounded context", "aggregate", "invariant ID").
  Cover: what ships, who it affects, public vs protected behavior, compatibility with other features.
-->

- **What this feature delivers**: [one sentence]
- **Surface type**: [content MDX | App Router page | API only] — interactive UI MUST be App Router (`app/**/page.tsx`), not `content/*.mdx` (constitution Principle IV)
- **Who it affects**: [visitors, operators, other features]
- **Public vs protected**: [what requires login, what stays open]
- **Works with other features**: [plain-language dependencies]
- **Must not break**: [compatibility rules in everyday language]

*The **Domain Mapping** section below is **agent-authored at `/speckit-specify`**. Any change to this `spec.md` is a **semantic edit** (constitution) → **`npm run domain:extract`** then **`npm run domain:check`** (recompiles and validates the **global** model for all features) before planning. Use `npm run domain:normalize` only for cross-feature spec vocabulary drift. Plan-stage `contracts/` are **not** extraction inputs.*

## Domain Mapping *(gates only — Constitution Principle VI; agent-populated at specify)*

**Primary bounded context**: [e.g. Access | Content | Surface | Compliance | Discovery | Syndication | Platform]

| Entity | Role in this feature | Owner context |
|--------|----------------------|---------------|
| [Entity name] | [created / extended / referenced] | [context] |

**Contract Dependencies** (restriction maps / handoffs — feed
`domain:check-glue` when available):

| Feature / Service | Relationship | Contract / SSOT |
|-------------------|--------------|-----------------|
| [00N or service] | [extends / consumes / publishes / orthogonal] | [feature-local contract or `contracts/public/<name>@<semver>`] |

External services expose only versioned public contract surfaces. Do not
import another service's feature specs, domain model, implementation, or
private workflows.

Optional explicit **Handoffs** (preferred when several features share protocol surface):

| From | To | Contract | Restricts (entities / INV / routes) |
|------|-----|----------|-------------------------------------|
| [00N] | [00M] | [contract path] | [what must agree on the overlap] |

**Invariants** (preserve or extend; use `INV-*` from domain-model when applicable):

- **INV-[context]-[nnn]**: [statement]

## User Scenarios & Testing *(mandatory)*

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### Edge Cases

- What happens when [boundary condition]?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST [specific capability]

### Key Entities *(include if feature involves data)*

Align entity **names** with Domain Mapping tables in existing
`specs/NNN-*/spec.md`. Do not redefine fields owned by another local feature.
For another service, reference only its pinned published contract.

- **[Entity 1]**: [What it represents]

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: [Measurable metric]

## Assumptions

- [Assumption 1]

## Out of Scope *(optional)*

- [Explicitly excluded items]
