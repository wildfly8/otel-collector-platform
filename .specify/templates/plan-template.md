# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

*Prerequisite: no pending **semantic edits** without a fresh graph — `npm run domain:extract` + `npm run domain:check` MUST have passed after the last change to this feature's `spec.md` (global recompile validates all features).*

**Note**: Plan answers **technical** questions only (architecture, persistence, APIs, **technical saga**). It MUST NOT discover domain ownership problems — those are ruled out at Domain Validation.

## Summary

[Technical approach — architecture, stack, deployment]

## Technical Context

**Language/Version**: [NEEDS CLARIFICATION]

**Primary Dependencies**: [NEEDS CLARIFICATION]

**Storage**: [N/A or persistence choice]

**Testing**: [strategy]

**Target Platform**: [e.g. Vercel]

**Performance Goals**: [domain-specific]

**Constraints**: [domain-specific]

**Surface projection** (Agentic Foundation / Nextra): prose → `content/*.mdx`; interactive app features → `app/**/page.tsx` + `components/`; nav-only → `content/_meta.ts` `href`. Document in `contracts/` § Architecture.

**Nextra MDX widgets** (only if a client control must live inside prose MDX): document MDX hosting in `contracts/`.

**Scale/Scope**: [domain-specific]

## Constitution Check

*GATE: Technical feasibility only. Domain semantics validated at `/speckit-specify`.*

- [ ] `npm run domain:extract` + `npm run domain:check` passed before planning
- [ ] `npm run domain:check-plan` passed after Phase 1 artifacts
- [ ] Cross-feature contracts identified for amendment (if any)
- [ ] Producer-facing behavior is projected into a versioned
  `contracts/public/<name>/` package (if any)
- [ ] External service dependencies reference pinned public contracts only
- [ ] No new entities/ownership without spec amendment

## Domain Alignment

*Traceability: spec Domain Mapping entity → Phase 1 artifact → implementation.*

| Entity (from spec) | `data-model.md` section | Implementation location | Contract |
|--------------------|---------------------------|-------------------------|----------|
| [Entity] | [§] | [path] | [contracts/...] |

## Cross-Feature Impact

| Feature | Amendment required | Action |
|---------|---------------------|--------|
| [00N] | [yes/no] | [update contract / spec note] |

## Public Contract Impact

| Contract | Current version | Compatibility | Release action |
|----------|-----------------|---------------|----------------|
| [name or N/A] | [semver] | [major / minor / patch / unchanged] | [files, changelog, tests, tag] |

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── spec.md              # Domain theory (Summary + Domain Mapping) — validated before plan
├── plan.md              # This file (technical)
├── research.md
├── data-model.md        # Phase 1 — entity fields
├── quickstart.md
├── contracts/
└── tasks.md

contracts/public/         # only externally consumable service contracts
└── [contract-name]/
    ├── VERSION
    ├── CHANGELOG.md
    ├── contract.yaml
    ├── api-contract.md
    ├── data-contract.md
    └── capability.md
```

### Source Code (repository root)

```text
[project-specific layout]
```

**Structure Decision**: [Document the selected structure]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
