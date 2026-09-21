# Architecture — base classes, DI, packages (the house shape)

The concrete shape every screen and data path follows. Generic names (`<Name>`, `XxxViewModel`,
`FooRepository`) — no app id, endpoints, or class names. **Match this when adding code; do not
impose clean-arch (there is no domain/usecase layer).**

## Package layout

```
app/
  di/
    container.ts                  new Container() + container.load(dataModule, viewModelModule)
    types.ts                      Symbol tokens for interface bindings
    useViewModel.ts                container.get() through a useState() hook, for screens
    modules/
      dataModule.ts                StorageService / AuthStore / Api / ApiService / AppDatabase / RoomService / Repository
      viewModelModule.ts           ViewModel bindings
  viewmodels/
    base/BaseViewModel.ts          shared MobX base: isLoading/error/runAction() + property-injected repository
  stores/
    authStore.ts                   MobX singleton for cross-screen shared state, @injectable(), toConstantValue()-bound
  screens/
    <Name>/
      <Name>Screen.tsx             component + its ThemedStyle constants, one file
      <Name>ViewModel.ts           all logic/state (MobX), only if the screen has state
      components/                  screen-local sub-components (promote to app/components only when reused)
  navigators/
    AppNavigator.tsx                root stack (Splash / MainTabs / stack-only screens like Settings)
    MainTabNavigator.tsx            bottom tabs
    navigationTypes.ts              param lists per navigator
  components/                       shared UI: Screen, Text, Button, Icon, TextField, Toggle, LoadingIndicator...
  theme/                            colors, spacing, typography
  i18n/                             en.ts / vi.ts + index.ts (translate, changeLanguage)
  config/                           env config (API_URL, MASTER_API_URL, exitRoutes, ...)
  data/
    Repository.ts                   interface: { apiService; roomService; storageService }
    AppRepositoryImpl.ts             @injectable() impl; property-injected onto BaseViewModel as repository
    remote/api/
      index.ts                       apisauce Api client — attaches the Bearer token
      ApiService.ts                  pure interface — signatures only
      ApiServiceImpl.ts               @injectable() impl — request() helper + one method per endpoint
      apiProblem.ts                   normalizes apisauce errors into GeneralApiProblem
      apiLogger.ts                    request/response logging monitor
      master/                        MasterApiService(Impl) — a second base URL, its own DI Symbol
    model/
      api/
        item/                        domain shape returned to screens, one per file
        response/<domain>/           wire-shape DTOs, one per file
        ResponseWrapper.ts, PageResponse.ts   generic envelope DTOs
      room/                          local SQLite row shapes (entities)
    local/
      room/                          AppDatabase / RoomService(Impl) / <X>Dao(Impl) — expo-sqlite
      storage/                       MMKV load/save/remove + StorageService
  utils/                            logger.ts, crashReporting.ts, date formatting — no data-layer code here
```

**No `domain/`/`usecase/` layer.** The ViewModel calls `this.repository` directly.

## The MVVM screen convention (every screen follows this)

A screen is two files, one responsibility each, both under `app/screens/<Name>/`:

- **`<Name>Screen.tsx`** — the view **and** its styles in one file: the component first, then every
  `$name: ThemedStyle<T> = ({ colors, spacing, ... }) => ({ ... })` style constant below it (`const`,
  not exported), applied via `themed($name)`. Resolves its ViewModel with `useViewModel(<Name>ViewModel)`
  (`@/di/useViewModel`), wraps the component in `observer()` (`mobx-react-lite`) — skip `observer()`
  only if the screen truly has no ViewModel/observable state (a splash screen is the typical
  exception). No business logic, no direct `repository.apiService`/`repository.roomService` calls —
  only read ViewModel fields and call ViewModel methods.
- **`<Name>ViewModel.ts`** — a MobX class extending `BaseViewModel`. All state and logic lives here.

There is no separate `style.ts` and no `index.tsx` — the file is named after the screen itself
(`HomeScreen.tsx`, not `index.tsx`) and imported by that name:
`import { HomeScreen } from "@/screens/Home/HomeScreen"`.

```typescript
import { injectable } from "inversify"
import { actionBound, makeObservable, observable } from "mobx"

import { BaseViewModel } from "@/viewmodels/base/BaseViewModel"

@injectable()
export class <Name>ViewModel extends BaseViewModel {
  count = 0

  constructor() {
    super()
    makeObservable(this, {
      count: observable,
      isLoading: observable,
      error: observable,
      increment: actionBound,
    })
  }

  increment() {
    this.count += 1
  }
}
```

- **`makeAutoObservable` throws** on any class with a superclass — since every ViewModel extends
  `BaseViewModel`, always use `makeObservable` with explicit annotations covering both the
  ViewModel's own fields and the inherited `isLoading`/`error`.
- **`actionBound`** (not plain `action`, not `action.bound`) for any method passed directly as an
  event handler (`onPress={viewModel.increment}`) — a plain `action` method loses its `this` binding
  passed that way and crashes on first use; safe only when called from an inline arrow
  (`onPress={() => viewModel.doThing()}`).
- No `Repository`/`ApiService` import, no `@inject()`, no `super(repository)` in a ViewModel's own
  constructor — `BaseViewModel` property-injects `protected repository: Repository`, so
  `this.repository.apiService`/`this.repository.roomService`/`this.repository.storageService` are
  just there. The only things a ViewModel's own constructor needs are `@injectable()` on the class
  and the `makeObservable` call.
- Call an endpoint via `this.runAction(async () => { ... })` — `runAction` (on `BaseViewModel`) sets
  `isLoading`/`error` around the call so the screen doesn't have to.

### Registering a new screen
1. Create `app/screens/<Name>/{<Name>Screen.tsx,<Name>ViewModel.ts}`.
2. Register the route in `app/navigators/MainTabNavigator.tsx` (bottom tab) or
   `app/navigators/AppNavigator.tsx` (stack-only screen), and add the matching entry to
   `app/navigators/navigationTypes.ts`.
3. Add its ViewModel binding to `app/di/modules/viewModelModule.ts`.
4. Add i18n keys to **both** `app/i18n/en.ts` and `app/i18n/vi.ts` — never hardcode user-facing
   strings, always go through `tx="..."` / `translate("...")`.

### Sub-components — same folder-per-unit convention, local first
A piece of UI worth its own file (a non-trivial `FlatList` `renderItem`, a repeated block within one
screen) stays **local to the screen that owns it**, in a `components/` subfolder next to that
screen's own files:

```
app/screens/Wishlist/
  WishlistScreen.tsx
  WishlistViewModel.ts
  components/
    WishlistCard/
      WishlistCard.tsx     # local sub-component (component + its styles), only Wishlist uses it
```

Same one-file shape as a screen; add a ViewModel to the sub-component only if it has its own
state/logic (most don't). **Promote to `app/components/<Name>/` only once a second screen actually
needs it** — don't guess at reuse that hasn't happened yet.

## Dependency injection (InversifyJS)

Two injection styles, deliberately different:

- **Constructor injection** for everything except the shared `Repository`. For a concrete class,
  inject the class itself as the token (`@inject(Api) private api: Api = new Api()`); for an
  interface (no runtime representation), inject its `Symbol` from `app/di/types.ts` instead.
- **Property injection** for `repository` only: `BaseViewModel` declares
  `@inject(TYPES.Repository) protected repository!: Repository` as a class field, not a constructor
  param — every ViewModel needs data-layer access, so a subclass gets it with zero DI code of its
  own. Don't extend this pattern to other shared dependencies without an equally universal need.

`BaseViewModel` needs `@injectable()` even though it's never bound in the container itself —
Inversify's base-class dependency scan requires it to see the inherited property injection; omitting
it fails with `Missing required @injectable annotation` the moment any subclass is resolved.

Bindings live in two `ContainerModule`s under `app/di/modules/`, not inline in `container.ts` —
mirrors a Dagger `AppComponent` assembled from separate `@Module` classes. `container.ts` itself is
just `new Container()` + `container.load(dataModule, viewModelModule)`. Add a data-layer binding to
`dataModule.ts`, a ViewModel binding to `viewModelModule.ts` (`bind(X).toSelf()` inside the module's
`new ContainerModule((bind) => { ... })` callback). Bind an **interface** token to its implementation
(`bind<ApiService>(TYPES.ApiService).to(ApiServiceImpl)`, `bind<Repository>(TYPES.Repository).to(AppRepositoryImpl)`),
and bind a **shared singleton instance** (like `authStore`) with `toConstantValue(authStore)` — a
fresh `toSelf()` there would give the app two independent copies of that state.

**A second base URL** (a different backend, not just a different endpoint): bind the second
configured `Api` instance behind its own Symbol —
`bind<Api>(TYPES.MasterApi).toDynamicValue(() => new Api(authStore, { url: Config.MASTER_API_URL,
timeout: 10000 })).inSingletonScope()` — then have `MasterApiServiceImpl` inject
`@inject(TYPES.MasterApi)` instead of the plain `Api` token. The default `ApiService` keeps using the
plain (unqualified) `Api` token.

Requires `import "reflect-metadata"` as the very first import in `index.tsx` (and in test setup) —
Inversify's decorators depend on it being loaded before anything else.

## Data layer

- **One `Repository` interface + one `AppRepositoryImpl`.** `apiService`, `roomService`, and
  `storageService` all hang off that interface — there is no separate repository per feature and no
  usecase layer. A ViewModel calls an endpoint via `this.repository.apiService.getX()`, local
  persistence via `this.repository.roomService.userDao()...`, and shared prefs-style storage via
  `this.repository.storageService...` — never inject `ApiService`/`RoomService`/`StorageService`
  directly into a ViewModel.
- `apiService` and `storageService` are eager fields on `AppRepositoryImpl` (safe under Jest);
  `roomService` is a **lazy getter** — it does not construct `RoomServiceImpl` (and therefore does
  not open the real `expo-sqlite` connection) until something actually reads
  `repository.roomService`. This is deliberate: `expo-sqlite` has no Jest mock, so an eager
  `roomService` would crash every ViewModel test the moment `new AppRepositoryImpl()` ran.
- `ApiService.ts` stays a **bare interface** — no apisauce calls, no inline DTO `interface`s.
  `ApiServiceImpl.ts` implements it, going through a shared `protected request()` helper (unwraps an
  apisauce response or throws) — one apisauce call + one DTO→domain mapping per method. Wire-shape
  DTOs live under `data/model/api/response/<domain>/`, one interface per file; the domain shape
  returned to screens lives under `data/model/api/item/<Name>Item.ts`, one per file.
- Persistence is MMKV (`StorageService`) by default for simple key/value state. The `expo-sqlite`
  Room-style layer (`data/local/room/`) exists for structured local data — add a table by adding an
  entity in `data/model/room/`, a DAO interface + impl in `data/local/room/`, and its getter to
  `RoomService`/`RoomServiceImpl`/`AppDatabase`.

## Navigation

React Navigation, two navigators: `AppNavigator` (root `native-stack` — e.g. `Splash` →
`MainTabs`/stack-only screens like `Settings`) and `MainTabNavigator` (`bottom-tabs`, nested under
the root stack). A new tab screen registers in `MainTabNavigator`; a new stack-pushed-only screen
(not a tab) registers directly in `AppNavigator`. Both need a matching entry in
`app/navigators/navigationTypes.ts` so `navigation.navigate("X", params)` type-checks. A modal screen
is the same component, registered with `screenOptions={{ presentation: "modal" }}` in the stack.

## Lists

The house list system is React Native's own **`FlatList`**/**`SectionList`** — reach for
`SectionList` only when the design actually groups rows under section headers. Name row `testID`s to
match design layer names (see `itz-mapping`). A non-trivial `renderItem` becomes its own local
sub-component under the owning screen's `components/` folder (see above), not an inline function
recreated every render.
