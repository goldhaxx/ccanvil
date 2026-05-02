# Feature: No GWT when required fixture

> Feature: no-gwt-when-required
> Work: linear:BTS-XXX
> Created: 1700000000
> Status: Draft

## Summary

Spec with 4+ ACs but none use Given/When/Then format. Should drift on missing-given-when-then.

## Acceptance Criteria

- [ ] **AC-1:** Endpoint accepts JSON.
- [ ] **AC-2:** Validation runs before persist.
- [ ] **AC-3 (error):** Invalid input returns 400.
- [ ] **AC-4:** Successful save returns 201.

## Affected Files

| File | Change |
|------|--------|
| `src/api.ts` | New |
