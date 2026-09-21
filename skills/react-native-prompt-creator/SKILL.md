---
name: react-native-prompt-creator
description: Turn a Figma screen into a complete, paste-ready /feature prompt for the React Native app. Runs the requirement Q&A BEFORE /feature — gate checks (figma provided? MCP connected? implement this node? which OpenAPI?), reads the selected node, resolves every itz_ layer via the itz-mapping rule, asks the binding/action gaps as pick-lists, then emits ONE explicit prompt (brief + FEATURE SPEC block). Once complete (Open items: none) it asks whether to hand the spec straight to /feature or let the developer copy it themselves — it never writes app code itself either way. Use for "create the prompt", "prep this feature", "build a /feature prompt from figma", or before starting any React Native screen from a design.
---

# react-native-prompt-creator — build the /feature prompt (ask, don't build)

This skill runs the **ask** phase. It produces a clear, explicit prompt so `/feature` can build
**automatically, with no further questions**. It never writes app code itself — once the prompt is
complete it either hands it straight to `/feature` (on confirm) or prints it for the developer to
copy — either way, `/feature` is the one that builds.

Companion rules: [`itz-mapping`](../../rules/design/figma/itz-mapping.md) (the mandatory authority for
reading `itz_` labels), [`react-native-strings`](../../rules/design/react-native-strings.md) (static
strings), [`question-bank.json`](../../rules/design/figma/question-bank.json) (the canonical question
set), and [`feature-spec-template.md`](../../rules/design/figma/feature-spec-template.md) (the
emitted prompt's plain-text format + per-line build guide). The build side is
[`feature-qa-gate`](../../rules/feature-qa-gate.md).

## Core rule

**Every answer is picked or stated — never guessed.** Offer options (use `AskUserQuestion` when
available); reserve free text for names and values that can't be enumerated. Batch related questions.
The emitted prompt must be complete: no `[NEEDS …]`, `open: []`, `blocking: []`.

## Step 1 — Gate (ask in order, each gate must pass)

1. **Figma provided in this feature?** `{yes|no}` — no → ask for the frame link, or stop.
2. **Figma MCP connected?** `{yes|no}` — verify with `get_selection`/`list_files`. Fails → stop:
   "run the MCP Bridge plugin and confirm Connected," then retry.
3. **Confirm which node to implement — never assume the selection, never scan for one.**
   `get_selection` returning **empty/no node** is not license to search the file tree, walk pages, or
   guess a likely frame from its name — that's exactly the guessing this gate exists to prevent.
   - **`get_selection` returns nothing selected** → **STOP.** Tell the developer, fixed message:
     *"Chưa chọn frame nào trong Figma — chọn 1 frame cần build rồi báo lại."* Wait for their reply,
     call `get_selection` again, repeat until it returns an actual node. Never fall back to
     `list_files`/searching the document for a candidate in the meantime.
   - **`get_selection` returns a node** — a developer often has one frame selected while meaning
     another, so still confirm: state the selected frame's name + id and ask **"implement this node?
     `{yes|no}`."**
     - **yes** → use it.
     - **no** → ask which node instead: *select the intended frame in Figma and re-run
       `get_selection`, or paste its node-id.* Fetch it with `get_node`, state the name + id, and
       **confirm again**. Do not proceed on an unconfirmed node.
4. **Which OpenAPI spec(s)?** Call `get-api-catalog` (scope `{projectId, repoId}`) and present the
   available specs as a **pick-list** — don't make them type a name. Empty catalog → ask for the
   source or proceed mock-first.

## Step 2 — Read the node, enforce itz_

Call `get_node` / `get_metadata` on the frame. Classify **every** layer with the
[`itz-mapping`](../../rules/design/figma/itz-mapping.md) rule:

- `itz_*` components → collect for the mapping Q&A. **Do not descend into a leaf `itz_` component** —
  its child text/image is the component's own label/placeholder/icon, not a separate binding (see
  itz-mapping, "Leaf vs. container"). Descend only into a container `itz_` (e.g. `itz_FlatList` row
  template);
- structural containers (children, no own text/data/action) → inferred as a `View` layout, no
  question;
- system chrome / decoration → ignored;
- **any layer that carries text, data, or an action but is NOT named `itz_*` (and is not inside an
  `itz_` component) → BLOCKING.**

**The Figma must be correctly itz-labeled.** If there is any blocking layer, **STOP** and list them:
"Rename these in Figma to `itz_*` (see itz-mapping) and re-run — the prompt can't be built until the
design is labeled." Do not proceed, do not guess a binding.

## Step 3 — Match the API (search the catalog, don't make them type)

Now that you know the screen + its `data.`/action needs, **search** the openapi MCP and let the junior
**confirm** — never assume or ask them to type an operationId:

1. For the screen and each `data.`-bound layer / API action, call `search-api-operations { spec,
   query }` with `query` = keywords from the screen + layer name (screen `order-list` + layer
   `itz_FlatList[data.items]` → query `"order list"`; a login button → `"login"`).
2. Ask **per need, with the top matches as options**: *"Which API for `<layer / screen>`?"* →
   `[ <op1 — method path summary> | <op2 …> | none / other ]`. The junior **picks**; never default to
   the first hit silently.
3. On a pick, `load-api-operation-by-operationId { operationId }` to pull the **response fields** —
   used in the binding Q&A below. Two plausible fields for one view → ask.
4. Empty catalog / no match → ask for method + path + a response sample, or mark that binding
   mock-first. **Never invent an endpoint.**

## Step 4 — Mapping Q&A (pick-lists)

Use the operations **confirmed in Step 3** (don't re-ask them) and collect the navigable
**destinations (Screens)** once. Then, per `itz_` layer, ask only what the bracket leaves open — as
picks:

- `itz_*[data.field]` → **operation** (pick from the Step-3 matches) + **response field** (pick from
  the loaded operation's fields; two candidates like `price` vs `salePrice` → ask).
- `itz_*[key]` (static) → confirm key + value → `app/i18n/en.ts` + `vi.ts` (react-native-strings
  rule). Usually no question beyond a yes/no confirm.
- `itz_FlatList[data.items]` → list **operation**, **item tap** (pick: `navigate: <Screen>` /
  select / expand / none), optional id arg, **pagination** (pick).
- interactive `itz_*` (button/toggle/tappable/toolbar…) → **on click →** one pick combining
  `navigate: <Screen>` / `call API: <operation>` / dismiss / toggle / custom.

Plus screen-level picks: **feature name** (kebab), **screen type** (pushed / modal — a new screen is
not always pushed onto the stack), **device**, **entry point** (pick from destinations), **error
handling** (pick). Derive names by the fixed formula in `feature-qa-gate` — `OrderListScreen` +
`OrderListScreen.tsx`, `OrderListViewModel`, i18n key `order_list_title`.

## Step 5 — Emit the prompt (plain text)

Print **one plain-text block** the developer copies verbatim, following the fixed template in
[`design/figma/feature-spec-template.md`](../../rules/design/figma/feature-spec-template.md) exactly
(header `# FEATURE SPEC`, the `Feature/Stack/Device/Entry/Figma/OpenAPI` header, `Screen`,
`Components` numbered one per itz_ layer, `Lists`/`Strings`/`API`/`Notes`, and `Open items:`). **No
JSON** — it is a natural-language spec so `/feature` reads it directly. Example:

```
# FEATURE SPEC
Feature: order-list — Order List empty-state screen
Stack: react-native (TypeScript · Expo · MVVM · MobX · InversifyJS)
Device: both
Entry point: Dashboard / Home
Figma: node 7185:80696 (SPOS DESIGN)
OpenAPI: none

Screen:
- Type: pushed
- Screen: OrderListScreen
- ViewModel: OrderListViewModel
- Files: OrderListScreen.tsx, OrderListViewModel.ts

Components:
1. itz_Text[order_list_title] → Text
   bind: static "order_list_title" = "Danh sách gọi"
   on click: none
2. itz_Image[] (back) → Image
   bind: none
   on click: dismiss
3. itz_Image[] (cart) → Image
   bind: none
   on click: navigate CartScreen

Strings:
- order_list_title = "Danh sách gọi"

Open items: none
```

`Open items:` must read `none`. If the developer can't answer a required item, list it under
`Open items:` (don't fill it), print the prompt as-is, and **stop there** — don't offer Step 6 below;
tell the developer to resolve the open items (or paste the incomplete prompt into `/feature`, which
will stop and ask only those).

## Step 6 — Confirm, then hand off (only when `Open items: none`)

Once the spec is complete, ask **one** `AskUserQuestion`, exact shape:

- `header`: `Chạy /feature?`
- `question`: `Prompt đã xong, bạn có muốn chạy /feature luôn không?`
- `options`:
  1. `label`: `Có` — `description`: `` (empty — no explanatory text under the option)
  2. `label`: `Không` — `description`: `` (empty — no explanatory text under the option)

No prose beyond the call itself — no restating the question in chat text next to it.

- **"Có"** → invoke `/tllq-workflow:feature` yourself, passing the exact `# FEATURE SPEC`
  block just printed as its input — verbatim, not re-typed or re-summarized. This skill still never
  writes app code itself; it hands the *unmodified* spec to `/feature`, which is the one that builds,
  per [`feature-qa-gate`](../../rules/feature-qa-gate.md).
- **"Không"** → **stop**, same as before: *"Copy everything above and paste it into
  /feature — it will build without asking."*
- Never ask this question when `Open items:` is not `none` (see Step 5) — an incomplete spec has
  nothing to hand off yet.
