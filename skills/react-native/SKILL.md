---
name: react-native
description: Conventions for building features in a TypeScript + Expo/React Native app — Ignite-flavored MVVM (BaseViewModel/observer Screen via MobX) with InversifyJS dependency injection (mirrors a Dagger 2 AppComponent composition root), React Navigation, apisauce + hand-written DTOs, expo-sqlite, react-native-mmkv, i18next. Use for ANY React Native work in this stack — adding or editing a Screen/ViewModel, an apisauce API call or repository method, a DI binding/module, a FlatList/SectionList, navigation, local storage, logging, or a React Native bug fix. Also for "add a screen", "call the API", "wire up DI", "build the app".
---

# React Native (TypeScript · Expo · MVVM · MobX · InversifyJS · apisauce)

Build features the way this codebase already works. **TypeScript-first** on **Expo/React Native**
with **functional components** — the concrete house shape (DI layering, package layout, the MVVM
screen convention) is in **`references/architecture.md`**; read it before adding a screen or wiring
DI. Concrete versions + build config: **`references/stack.md`**.

## Stack at a glance
- **TypeScript (strict)**, functional components, `observer()` (`mobx-react-lite`) for reactive
  screens.
- **UI:** React Native core wrapped by this project's own base components (`Screen`, `Text`,
  `Button`, `TextField`, `Toggle`, `LoadingIndicator` under `app/components/`) — prefer these over
  raw `View`/`TextInput`; theming via `app/theme/` (`colors`, `spacing`, `typography`) and
  `themed($style)`, never ad-hoc magic numbers.
- **Arch:** MVVM — a screen is `<Name>Screen.tsx` (component + its `ThemedStyle` constants, one
  file) + `<Name>ViewModel.ts` (a MobX class extending `BaseViewModel`). **No domain/usecase
  layer** — the ViewModel calls `this.repository` directly.
- **DI:** **InversifyJS**, one composition root (`app/di/container.ts` = `new Container()` +
  `container.load(dataModule, viewModelModule)`), bindings split across `ContainerModule`s in
  `app/di/modules/` (mirrors Dagger's `AppComponent` assembled from separate `@Module`s). Constructor
  injection everywhere **except** `repository`, which is property-injected on `BaseViewModel`.
- **Async:** MobX `runAction`/`actionBound` around `async/await` — `this.runAction(async () => {
  ... })` wraps an API call with `isLoading`/`error` bookkeeping already handled by the base class.
- **Network:** **apisauce** over a single `Api` client (Bearer-token attachment via
  `addAsyncRequestTransform`), `ApiService` interface + `ApiServiceImpl`, one DTO per file.
- **Persistence:** **expo-sqlite**, wrapped in `AppDatabase`/`RoomService(Impl)` (Android-Room-style
  naming for parity with the Kotlin/Java reference stack) — reached lazily via
  `repository.roomService` so it never breaks a Jest run that doesn't touch it.
- **Local storage:** **react-native-mmkv** via `StorageService`.
- **Navigation:** **React Navigation** (`native-stack` root + `bottom-tabs`).
- **i18n:** **i18next** — `app/i18n/en.ts` + `app/i18n/vi.ts` (Vietnamese default), `translate()`/
  `tx="key"`.
- **Logs:** `app/utils/logger.ts` (`logger.d/i/w/e`), never bare `console.log`.

## Recipes

Requirements come pre-resolved: the
[`react-native-prompt-creator`](../react-native-prompt-creator/SKILL.md) skill gathered them and
emitted a `FEATURE SPEC`, which `/feature` builds from per
[`feature-qa-gate`](../../rules/feature-qa-gate.md) — don't re-derive a separate question set here.
Follow the spec; if a required item is missing, stop and ask it (never guess). Any user-facing string
added along the way (from a design or not) follows the always-on
[`react-native-strings`](../../rules/design/react-native-strings.md) rule — naming, per-screen
grouping in `app/i18n/*.ts`, and multi-language handling.

### Add a screen (Screen + ViewModel)
1. `app/screens/<Name>/<Name>Screen.tsx` — function component, `observer(() => { ... })`, resolve
   the ViewModel with `useViewModel(<Name>ViewModel)` (`@/di/useViewModel`). Component first, then
   every `$name: ThemedStyle<T>` style constant below it, applied via `themed($name)`. No business
   logic and no direct `repository.apiService`/`repository.roomService` calls in the screen — only
   read ViewModel fields and call ViewModel methods.
2. `<Name>ViewModel.ts` — `@injectable() class <Name>ViewModel extends BaseViewModel`. Constructor
   calls `super()` then `makeObservable(this, { ...ownFields, isLoading: observable, error:
   observable, ...ownActions: actionBound })` — **never `makeAutoObservable`**, it throws on a class
   with a superclass. Any handler passed directly as a prop (`onPress={viewModel.foo}`) must be
   `actionBound`, not `action`/`action.bound`.
3. **Register the route:** add the screen to `app/navigators/AppNavigator.tsx` (stack-only) or
   `app/navigators/MainTabNavigator.tsx` (bottom tab), and add the matching entry to
   `app/navigators/navigationTypes.ts`. A modal presentation sets `presentation: "modal"` on the
   stack screen options — still the same component.
4. **Register DI:** add the ViewModel binding (`bind(XViewModel).toSelf()`) to
   `app/di/modules/viewModelModule.ts` — a missing binding surfaces as a `container.get()` throw at
   runtime, not a compile error.
5. **i18n:** add every user-facing string's key to **both** `app/i18n/en.ts` and `app/i18n/vi.ts`.

A sub-component used by only this screen goes in `app/screens/<Name>/components/<Sub>/<Sub>.tsx`
(same one-file shape: component + its styles) — not `app/components/`, until a second screen needs
it (promote then, not before).

### Call the API
0. Purpose unclear — which screen consumes it, which response fields feed which views, error
   behavior — → ask (the `feature-qa-gate` rule), never guess.
1. Add the method signature to `app/data/remote/api/ApiService.ts` (bare interface, no apisauce
   calls, no inline DTO `interface`s here).
2. Implement it in `app/data/remote/api/ApiServiceImpl.ts` — one apisauce call through the shared
   `request()` helper, one DTO→domain mapping. Wire-shape DTOs go in
   `app/data/model/api/response/<domain>/`, the domain shape returned to screens in
   `app/data/model/api/item/<Name>Item.ts` — never inline either as an unexported `interface` in
   `ApiServiceImpl.ts`.
3. In the ViewModel: `this.runAction(async () => { const x = await
   this.repository.apiService.getX(); ... })` — `runAction` (on `BaseViewModel`) already sets
   `isLoading`/`error` around the call.
4. Base URLs / keys come from `app/config/`, **never hardcoded**. A second backend (a genuinely
   different base URL, not just a different endpoint) gets its own `Api` instance bound behind its
   own DI `Symbol` in `dataModule.ts` (see `references/architecture.md`) — don't reuse the primary
   `Api` token for it.

### List (FlatList / SectionList)
Plain list → `FlatList` with `data`/`renderItem`/`keyExtractor`; a non-trivial `renderItem` becomes
its own local sub-component (`app/screens/<Name>/components/<Row>/<Row>.tsx`), not an inline
function recreated every render. Grouped list → `SectionList`. Name row testIDs to match design
layer names (see `itz-mapping`). The row's data contract (element → field, source, tap action) comes
from the `feature-qa-gate` rule's answers, never inferred from the design alone. Pagination:
`onEndReached` (+ `onEndReachedThreshold`); pull-to-refresh: `refreshing`/`onRefresh` props (or a
wrapping `RefreshControl` for a non-`FlatList` scroll view).

### Wire up DI (InversifyJS)
Bindings live in `app/di/modules/dataModule.ts` (services/repository) and
`app/di/modules/viewModelModule.ts` (ViewModels), never inline in `container.ts`. Interface tokens
use a `Symbol` from `app/di/types.ts` (`bind<ApiService>(TYPES.ApiService).to(ApiServiceImpl)`); a
concrete class can be its own token (`bind(HomeViewModel).toSelf()`). A singleton shared instance
(like `authStore`) is bound with `toConstantValue(...)`, not `toSelf()`, so every consumer shares the
same object. `BaseViewModel` needs `@injectable()` even though it's never bound directly — Inversify's
base-class scan requires it to see the inherited `repository` property injection.

### Local storage / persistence
Shared key/value state (a flag, a token, a language choice) → `StorageService` (MMKV), reached via
`this.repository.storageService`. Structured local data → the `expo-sqlite`-backed
`RoomService`/DAO layer under `app/data/local/room/`, reached via `this.repository.roomService` —
remember this constructs the real SQLite connection on first read, so a ViewModel test that never
touches it stays safe under Jest; one that does must mock at the DAO/`AppDatabase` boundary, not try
to make `expo-sqlite` itself work under Jest.

### Event / Dialog / Notification
Use this recipe for any interstitial that isn't its own screen — a confirmation before a destructive
action, a result notification, a picker. Presentation, confirm/cancel vs informational, and whether a
result flows back to the caller are requirements the `feature-qa-gate` rule should have already
settled — don't re-derive them here.

Implement with a modal screen (`presentation: "modal"` in the stack) or a bottom-sheet component for
the first two presentations; use a toast/snackbar component or the platform `Alert` API directly for
the third. Pass a result back via navigation params on `goBack()` (e.g.
`navigation.navigate("Prev", { result })`) or a callback prop, not a direct reference to a parent
ViewModel.

## Testing
Where the project has tests (Jest + `@testing-library/react-native`), the seam is
**ViewModels / repository / mappers** — construct the ViewModel directly (`new XViewModel()`, not
through the container) and assign a plain mock object literal to `repository` (see any
`*ViewModel.test.ts`'s `mockApiServiceOf()`-style helper) rather than `jest.mock()`-ing
`ApiServiceImpl`. `expo-sqlite` has no Jest mock — a ViewModel test must never read
`repository.roomService` unless it explicitly mocks the DAO/`AppDatabase` collaborator. Don't claim a
suite exists; state what you actually ran (`npx jest`, `npx tsc --noEmit`).

## Build / run
- Dev: `npx expo start --dev-client`. iOS: `npx expo run:ios`. Android: `npx expo run:android`.
- Type check (the definition-of-done gate for this stack): `npx tsc --noEmit -p . --pretty`.
- Lint: `npx eslint . --fix`.
- Release builds: EAS Build profiles (`eas build --profile <development|preview|production>
  --platform <ios|android>`).

## Gotchas
- **`makeAutoObservable` throws** on any class with a superclass — always `makeObservable` with
  explicit annotations in a ViewModel (see the screen recipe above).
- **`actionBound`, not `action`/`action.bound`**, for any method passed as an event handler.
- **Never `new XViewModel()` in app code** — always `useViewModel()` so `repository` is
  property-injected; a manually constructed ViewModel has an unset `repository` and crashes on first
  use (this is *intentional* in tests, where you assign a mock instead).
- **Never edit `ios/`/`android/`** by hand — they're generated by `expo prebuild`; change
  `app.json`/`app.config.ts` (or a config plugin) and re-run prebuild.
- Keep secrets (API keys, Firebase config) out of the repo → `app/config/` / EAS secrets, never
  hardcoded in a screen or service.
