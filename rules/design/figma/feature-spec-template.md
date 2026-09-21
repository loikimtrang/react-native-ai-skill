# FEATURE SPEC — the plain-text prompt

The prompt `react-native-prompt-creator` emits and `/feature` builds from. **Plain text, no JSON.**
Fixed sections so it's unambiguous to read and build from. The header line `# FEATURE SPEC` is the
sentinel `/feature` detects. It is complete when **`Open items: none`**.

## Template

```
# FEATURE SPEC
Feature: <name-kebab> — <one-line goal>
Stack: react-native (TypeScript · Expo · MVVM · MobX · InversifyJS · apisauce)
Device: <ios | android | both>
Entry point: <where the screen is launched from>
Figma: node <nodeId> (<file name>)
OpenAPI: <spec name(s), or "none">

Screen:
- Type: <pushed | modal>
- Screen: <Base>Screen         (function component, observer(), navigation.navigate destination or modal route)
- ViewModel: <Base>ViewModel   (extends BaseViewModel, @injectable())
- Files: <Base>Screen.tsx, <Base>ViewModel.ts  (in app/screens/<Base>/)

Components:   (one numbered item per itz_ layer, in top-to-bottom order)
1. <layer name> → <RN component>
   bind: <one of: data <field> ← <operation>.<responseField> | static "<key>" = "<text>" | none>
   on click: <one of: navigate <Screen>(<args>) | call API <operation> | dismiss | toggle | none>
2. ...

Lists:   (only if there is an itz_FlatList/itz_SectionList; else omit)
- <layer> → FlatList; items ← <operation>; row fields: <child itz_ → field, ...>;
  item tap: <navigate <Screen>(<idField>) | select | none>; paging: <none | paged | pull-refresh>

Strings:
- <key> = "<value>"

API:   (omit if OpenAPI is none)
- request params: <where each param comes from>
- errors: <per-error behavior, e.g. 401 → relogin, else alert + retry>

Notes:
- <assumptions / ignored chrome / illustration → asset / etc.>

Open items: none
```

## How /feature reads each line (build actions — no interpretation slack)

| line | build action |
|---|---|
| `Feature` / `Screen` names | create exactly these files/types (already the deterministic-naming result) |
| `<layer> → <component>` | add that RN component to the screen JSX at the layer's position |
| `bind: data <field> ← <op>.<respField>` | an observable `field` on the ViewModel (`makeAutoObservable`/`@observable`); ViewModel method calls `this.repository.apiService.<op>()` via `runAction()`; map `<respField>` |
| `bind: static "<key>" = "<text>"` | add `<key>: "<text>"` to `app/i18n/en.ts`/`vi.ts` (react-native-strings rule); `translate('<key>')` in JSX |
| `bind: none` | no text/data — component hint only |
| `on click: navigate <Screen>(<args>)` | `pushed` → `navigation.navigate('<Screen>', { <args> })`; `modal` → same call, with `<Screen>` registered `presentation: 'modal'` in its navigator |
| `on click: call API <operation>` | tap → `onPress={() => viewModel.<operation>()}` → `this.repository.apiService.<operation>()` |
| `on click: dismiss` | `navigation.goBack()` |
| `Lists` line | `FlatList` `data`/`renderItem` over `items`; each row from `row fields`; tap → the listed action |
| `Open items: none` | build with no questions. **Any listed open item → stop, ask only those, then build.** |

## Completeness

`Open items: none` and no `[NEEDS: …]` anywhere → deterministic build. Otherwise `/feature` stops,
lists them, asks only those, and the gap is logged to improve the skill (`feature-qa-gate`).
