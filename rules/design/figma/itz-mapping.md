# itz-mapping — Figma `itz_<Component>` layer → React Native type (enforce itz_)

**The mandatory authority for reading `itz_` labels.** Both the
[`react-native-prompt-creator`](../../skills/react-native-prompt-creator/SKILL.md) skill (when it
reads the node to build the prompt) and `/feature` (when it builds) resolve every layer through this
rule — which React Native component it becomes, how it binds to data, how its action is resolved —
so work is done from facts, not guesses. The Figma design must be labeled to this convention;
unlabeled content/action layers are blocking (below).

## Enforce itz_

**Every layer that becomes a real component with text, data, an action, or a deliberate component
type MUST be named `itz_<Component>[<binding>]`.** `<Component>` is not a stylized role name — it is
the **literal component to instantiate**, written exactly as it appears in code: `itz_Text`,
`itz_TextField`, `itz_Button`, `itz_FlatList`, `itz_Toggle`, `itz_RemoteImage`, `itz_CardView`. Read
the name directly; there is no lookup table translating it into something else — if the layer says
`itz_TextField`, the build uses the project's `TextField` component.

- **A built-in React Native / project base component** → PascalCase, matching the real import:
  `Text`, `TextField`, `Button`, `Toggle`, `Switch`, `Picker`, `Slider`, `LoadingIndicator`,
  `FlatList`, `SectionList`, `ScrollView`, `Image`.
- **A type with no built-in equivalent** (a checkbox, a radio button, a star rating, a chip, a card,
  a wrapped web view) → the exact name of the reusable custom component the project already has
  (`CheckboxView`, `RadioButtonView`, `RatingView`, `ChipView`, `CardView`, `WebView`) — verify it
  exists (grep / code-graph, under `app/components/`) before relying on it. If the project doesn't
  have one yet, this label is what names the one this build creates.
- **Third-party types already in the stack** — `WebView` (`react-native-webview`), `Slider`
  (`@react-native-community/slider`).

A `<Component>` that isn't a real component and isn't shaped like a plausible one to create (a
description, a Vietnamese phrase, a generic Figma default like `Frame 12`) is a **BLOCKING
question** — the AI never invents a component name, and never guesses a binding from an unnamed
layer.

Only two kinds of layer are exempt, because they are not components:

- **Structural containers** — grouping/positioning only → inferred as a layout (below).
- **Chrome / decoration** — system status bar, notch, home indicator, illustration vectors → ignored,
  not built (`SafeAreaView`/the OS draws the status bar itself).

## Binding grammar — the bracket decides

`itz_<Component>[<binding>]`:

| bracket | meaning | result |
|---|---|---|
| `[data.field]` | dynamic | bind from the screen ViewModel — `<Text text={viewModel.field} />` (two-way for an input: `value={viewModel.field}` + `onChangeText={(v) => viewModel.setField(v)}`). The field is confirmed against the openapi operation via the gate — never taken from the layer's sample text. Nested `data.user.name` → `viewModel.user.name`. |
| `[key]` | static | an `app/i18n/*.ts` resource; `key` is the resource key, the layer's text is the value. Follows [`../react-native-strings.md`](../react-native-strings.md). `itz_Msg[key]` (legacy `itz_msg[key]`) is an accepted alias for `itz_Text[key]`. |
| `[]` / bare `itz_<Component>` | hint only | picks the RN component type; no text/data. A child `itz_*` supplies content. |

The layer's visible Figma text on a `[data.field]` layer is **design-time sample data** — never
copied to `app/i18n/*.ts`.

## No translation table — the name is the type

Earlier drafts of this rule kept a lookup table mapping a generic role name (`edit text`, `recycler
view`) to a component type. That's gone: the Figma layer now names the real component directly, so
there is nothing to translate — read `itz_TextField` as `TextField`, `itz_FlatList` as `FlatList`,
`itz_Toggle` as `Toggle`. A component new to this project is still allowed — it just means naming it
correctly (and, for a custom component, checking whether it already exists before assuming a new one
is needed) rather than finding it in a table here.

## Leaf vs. container — decided by the component's own shape, not a list

Whether an `itz_` component's children are separate bindings or its own internals follows from the
component's own API, not a memorized list:

- **Container** — the component takes children/content (`children` prop, or a data collection with a
  row renderer — `FlatList`/`SectionList` with `renderItem`, `ScrollView`, `View` used as
  `VStack`/`HStack`, `CardView`, `ChipGroup`). **Keep descending** — its `itz_*` children are real
  components (a `FlatList`'s children are the **row template**, each child `itz_*` = a row field).
- **Leaf** — the component takes no content, only data/labels/props (`Text`, `TextField`, `Button`,
  `Image`, `Toggle`, `Switch`, `CheckboxView`, `RadioButtonView`, `Picker`, `LoadingIndicator`,
  `Slider`, `RatingView`, `WebView`). **Stop descending** — a text inside `itz_Button[…]` is the
  button's **label**; a text inside `itz_TextField[…]` is the **placeholder**; an image inside
  `itz_TouchableOpacity[]` is the **icon**. These are not independent bindings, so they are **not**
  BLOCKING even when unnamed.

Unsure whether a project's custom component is a leaf or a container → check its prop types, don't
guess.

## Actions — always asked

For any interactive `itz_*`, the gate asks the action and its target — never inferred:

- **Always interactive** — a component whose own API models user input or an action (`Button`,
  `Toggle`, `Switch`, `Slider`, `Picker`, `TextField`, a `CheckboxView`/`RadioButtonView`).
- **Interactive only if the design marks it tappable** — a display/container component (`Image`,
  `CardView`, a `FlatList` row, a header icon) is only asked about when the Figma prototype/notes (or
  the developer) actually mark it tappable — ask when in doubt, never assume either way.

Resolve every interactive component to one of:

- **navigate** → `navigation.navigate('<Screen>', { ...args })` (push) or
  `navigation.navigate('<Screen>', { ...args })` with the route registered `presentation: 'modal'`
  — which screen + args (verified in the code graph);
- **call API** → which openapi operation (a ViewModel method calling `this.repository.apiService...`);
- **dismiss / back** → `navigation.goBack()`;
- **toggle state**, or **custom**;
- **list item tap** → navigate detail (which id field is the arg) / select / expand / none.

## Structural containers

A node is **structural** if it is a `FRAME`/`GROUP` that **has children** but carries **no own text,
no `data.` binding, and no action.** This is checkable from the meta — not a judgment call. A
structural container is **not mapped to a component or binding**; it is **realized as a layout
container**, inferred from `autoLayout`:

| Figma | React Native container |
|---|---|
| `autoLayout: VERTICAL` | `View` with `style={{ flexDirection: 'column', gap }}` |
| `autoLayout: HORIZONTAL` | `View` with `style={{ flexDirection: 'row', gap }}` |
| `autoLayout` + `wrap: WRAP` | `View` with `flexWrap: 'wrap'`, or a grid `FlatList` (`numColumns`) |
| `primaryAxisAlign: SPACE_BETWEEN` | `justifyContent: 'space-between'` on the container |
| no `autoLayout` (absolute bounds) | `View` with `position: 'absolute'` children, or a fixed-height wrapper |
| `gap` / `padding` | `gap`/`padding` style props on the `View` |

- **Do not skip it** like chrome — its `autoLayout` *is* the arrangement. Keep the structure, add
  zero logic. Auto-name the `testID` from parent + role (`view_navigation_bar`), no question.
- **Flatten trivial wrappers** — a frame that only offsets a single child → fold the offset into the
  child's `style.margin`; emit a container only when it groups 2+ children or defines real
  arrangement (shallow view hierarchy).
- A container that carries its own content/action is **not** "just grouping" — enforce-itz_ applies:
  name it `itz_*` (e.g. `itz_TouchableOpacity[]`) or it is BLOCKING.
- Designers do **not** rename pure grouping frames (`Frame 2187` stays). Name a container only when
  it is a list/row template (`itz_FlatList[data.items]`), tappable (`itz_CardView[]`), or needs a
  forced type (`itz_View[]`).

## Chrome / decoration — ignored

Never build these; they are not app UI:

- system status bar and its parts: `iPhone XStatus Bars`, `Notch`, `Dynamic Island`, `WiFi Signal`,
  `Battery`, `Time`, `Home Indicator`, `Status Icons` — `SafeAreaView`/the OS draws the status bar /
  home indicator itself;
- pure decorative vectors (e.g. the many `Vector` layers of an illustration) → export the whole
  illustration as one local image asset, don't rebuild each path.

## Reading node meta

- **`node.name`** → parse the `itz_` grammar (component name + bracket). Typos/generic names
  (`Frame 2187`, `ORDER LIST TITILE`) → structural or BLOCKING per the rules above, never guessed.
- **`node.type`** sanity-checks the type: `TEXT` + `[data.field]` = bound `Text`; a repeated
  `INSTANCE` under an `itz_FlatList` = the **row template** (each child `itz_*` = a row field).
- **dimensions** → React Native dp 1:1 with the Figma frame (Figma px at the design's base scale ==
  RN `dp`); reuse spacing/radius via `app/theme/spacing` rather than repeating raw numbers, never
  hardcode ad-hoc magic numbers per screen.
- **text layers** → `app/i18n/*.ts` per [`../react-native-strings.md`](../react-native-strings.md).

## Machine-readable Q&A + prompt

The questions this mapping drives are enumerated (with node triggers + answer types) in
[`question-bank.json`](question-bank.json); the emitted prompt's plain-text format is defined by
[`feature-spec-template.md`](feature-spec-template.md). The
[`react-native-prompt-creator`](../../skills/react-native-prompt-creator/SKILL.md) skill reads the
node, walks those questions, and emits a `# FEATURE SPEC` that
[`feature-qa-gate`](../../feature-qa-gate.md) builds from without guessing.

## Scope

Naming-convention rule, stack-aware but generic — no project ids or class names.
