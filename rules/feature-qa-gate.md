# feature-qa-gate — how /feature consumes the prompt (build, don't re-ask)

Governs `/tllq-workflow:feature` for the React Native app. The **asking** happens earlier, in the
[`react-native-prompt-creator`](../skills/react-native-prompt-creator/SKILL.md) skill, which emits a
complete `FEATURE SPEC`. This rule says what `/feature` does with it.

## Core rule

**A requirement is answered in the spec, or `/feature` stops and asks — never guessed.** The whole
point of the two-step flow is that the spec is already complete, so the build runs hands-off.

## Detect the mode

- **BUILD mode** — the prompt contains a plain-text `# FEATURE SPEC` block (the format in
  [`design/figma/feature-spec-template.md`](design/figma/feature-spec-template.md) — **no JSON**).
  → Build **automatically, with no questions**, taking every component, binding, action, string, and
  name from the spec exactly as written; the template's "build actions" table says what each line
  means. Read the Figma tree only to lay out structure and confirm it matches the spec (a mismatch is
  a gap — see below — not a silent override).
- **NO SPEC** — a bare request / figma link with no `# FEATURE SPEC`.
  → Do **not** start guessing. Tell the developer: *"run `react-native-prompt-creator` first to build
  the prompt, then paste it here."* (That skill runs the gate + mapping Q&A and emits the spec.)

## On a gap (BUILD mode)

If `Open items:` is not `none`, a `[NEEDS: …]` marker appears, a required line is missing, or the spec
contradicts the design:

1. **Stop.** Do not guess and do not silently continue.
2. **List** exactly what is missing or mismatched.
3. **Ask** those items (only those), then build.
4. Treat every gap as a **skill-improvement signal** — note it so `react-native-prompt-creator` /
   `question-bank.json` / `itz-mapping.md` can be tightened to prevent it next time.

Zero gaps is the target: a spec from `react-native-prompt-creator` should build with no interaction.

## Deterministic naming

Names never vary between runs — derive them by fixed formula from `feature` (kebab). Both the prompt
creator and the build use these, so the spec and the code agree. `base = PascalCase(feature)`,
`camel = camelCase(feature)`, `snake = snake_case(feature)`:

The **presentation type** (stack-pushed / modal, asked in the ASK phase) picks how the screen is
registered in the navigator; everything else is the same:

| artifact | formula | `order-list` → |
|---|---|---|
| screen (pushed) | `{base}Screen` — function component, `observer(() => {...})`, registered as a `native-stack` screen | `OrderListScreen` |
| screen (modal) | `{base}Screen` — same component, registered with `presentation: 'modal'` | `OrderListScreen` |
| ViewModel | `{base}ViewModel extends BaseViewModel`, `@injectable()` | `OrderListViewModel` |
| file | `{base}Screen.tsx`, `{base}ViewModel.ts` in `app/screens/{Base}/` | `OrderListScreen.tsx` |
| DI token | `TYPES.{Base}ViewModel` in `app/di/types.ts` | `TYPES.OrderListViewModel` |
| row component (list item) | `{RowBase}Row` from the row template layer | `OrderRow` |
| testID | `snake` of the layer's role/name | `rv_orders`, `tv_title` |
| i18n key | `{snake}_{key}` (react-native-strings prefix rule) | `order_list_title` |

DI wiring follows InversifyJS conventions: the screen resolves its ViewModel with
`const vm = useViewModel(TYPES.{Base}ViewModel)`; a service dependency is constructor-injected into
the ViewModel via `@inject(TYPES.XxxService) private xxxService: XxxService` (or, for the shared
data-access facade, via the `repository` property injected on `BaseViewModel` — see the
`react-native` skill's `references/stack.md`).

## Determinism, honestly

A complete spec pins the same components, bindings, navigation, files, class names, and strings every
run — that is *decision* determinism. It removes guessing; it does not make the LLM's prose identical.

## Scope

Build-time contract — no project ids, endpoints, or class names live here. Component/binding grammar:
[`design/figma/itz-mapping.md`](design/figma/itz-mapping.md). Strings:
[`design/react-native-strings.md`](design/react-native-strings.md). The ask phase + emitted prompt
shape: [`react-native-prompt-creator`](../skills/react-native-prompt-creator/SKILL.md) +
[`design/figma/feature-spec-template.md`](design/figma/feature-spec-template.md).
