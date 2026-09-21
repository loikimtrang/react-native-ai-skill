# react-native-strings — `app/i18n/*.ts` naming, layout, language rules

Applies to **every** addition of a user-facing string to `app/i18n/en.ts` (and every other language
file, e.g. `app/i18n/vi.ts`), regardless of source — a Figma layer (see the `[key]` case in
[`figma/itz-mapping.md`](figma/itz-mapping.md)), a spec/plan written without a design, a manual code
edit, or a bug fix. There is no "no Figma, so no rule" case — a hardcoded UI string is always wrong;
every user-facing string goes through this rule.

## Key naming — prefix by screen

Name every key `<screen_prefix>_key` (e.g. screen `ConsultationFormScreen` →
`consultation_company_title`, not bare `company_title`). Derive the prefix from the screen being
built, stated once per screen, not re-derived per key. This keeps `app/i18n/*.ts` grouped and
searchable per screen as the app grows.

## Key is mandatory and verbatim — never invent or rewrite it

The key comes from an explicit source (a Figma `itz_Text[key]` bracket, a spec, or the developer's
prompt) — never invented or guessed from the display text "reading well". Once known, use it exactly
as given; the AI only *prepends* the screen prefix, it never shortens, rewords, translates, or
"cleans up" the key text itself. No source for the key → ask, don't invent one.

## Always add the key — never dedupe by value

If `<screen_prefix>_key` is not already present in `app/i18n/en.ts`, add it — **even if another
existing entry already has the same text value**. Do not reuse/point to an existing key just because
the value matches; each binding gets its own entry so screens stay independent and don't silently
break when one is edited later.

## Multi-language files

If the project has more than one language file under `app/i18n/` (e.g. `en.ts` + `vi.ts` — Vietnamese
is this project's default locale), add the same key to **every** language file. The **value** in each
language stays exactly as given for that language — never auto-translate it. A missing translation
for a language is a value to ask about, not to invent.

## Physical layout — grouped by screen, then by section within the screen

`app/i18n/en.ts` (and every language variant of it) stays **grouped by screen**, each group opened by
a comment naming the screen. A screen with more than one function/area (header, a form, a list, a
bottom sheet, a result state, …) gets a **sub-comment per section** inside the screen group — don't
dump every key from a large screen flat under one header, that's the "block too big" problem this
section fixes:

```ts
export default {
  // Consultation form screen
  // Header
  consultation_screen_title: "Thông tin liên hệ",

  // Company info section
  consultation_company_title: "Tên Công Ty",
  consultation_company_address: "Địa chỉ",

  // Submit section
  consultation_submit_button: "Gửi",
  consultation_submit_success: "Gửi thành công",
}
```

- A screen with only one function/section (a simple detail or confirmation screen) doesn't need a
  sub-comment — the screen header alone is enough; don't force sub-grouping where there's nothing
  to split.
- The section name comes from the screen's actual structure (a Figma frame/group name, a form
  section, a list vs. its empty/error state) — not invented for the sake of splitting. Ambiguous
  which section a key belongs to → ask, don't guess a split.
- Adding a key for a screen+section that already has a group → insert it **inside that section's
  group**, next to its siblings — never tack it onto the end of the file or the end of the whole
  screen block regardless of where the cursor/diff happens to land.
- Adding the first key for a new section within an existing screen → open a new sub-comment for
  it inside that screen's group, in the order the sections appear in the design/screen.
- Adding the first key for a screen that has no group yet → open a new `// <Screen> screen` group
  (placed alongside the other screen groups, not scattered), with its first section sub-comment
  inside.
- Applies mid-task too: if a screen/section's keys grow while building it, keep appending into
  that same section's group so the file never drifts back into one flat unsorted list.
- Same screen + section grouping and comments in every language file, so they line up 1:1 across
  `en.ts`, `vi.ts`, etc.

## Reading a key in a screen

- `translate('consultation_company_title')` (i18next `t()` alias exported by `app/i18n/`) — use
  directly in JSX: `<Text tx="consultation_company_title" />` if the project's `Text` component
  supports a `tx` prop, or `<Text text={translate('consultation_company_title')} />` otherwise.
- Never interpolate the key itself (`` translate(`${prefix}_title`) ``) — the full literal key must
  appear in source so this rule's grouping and any key-usage lint/codemod both see it.
- Interpolated values inside a translated string use i18next's own `{{ }}` placeholder syntax
  (`translate('order_count', { count })`), not string concatenation.

## Scope

Naming/layout convention, stack-agnostic (applies to the `react-native` skill) — no project ids or
class names live here.
