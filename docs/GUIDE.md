# GUIDE — Vibe coding React Native (spec-kit x superpowers)

> Quy trình **Thêm feature mới** tách theo nguồn thiết kế:
> [design/GUIDE-Figma.md](./design/GUIDE-Figma.md) · [design/GUIDE-ClaudeDesign.md](./design/GUIDE-ClaudeDesign.md)
>
> Cách label control trên Figma (syntax `itz_*` cho React Native):
> [design/GUIDE-Figma-Labels.md](./design/GUIDE-Figma-Labels.md)

Flow chung:

```
/feature <mô tả ngắn gọn>
   → agent đọc design + OpenAPI → sinh spec/plan/tasks
   → BẠN REVIEW
   → sửa spec nếu cần → approve ("ok, build đi")
   → agent build + build check
   → xác nhận kết quả → /done
```

Spec **không** commit vào repo — sống ở spec-vault, bị wipe khi `/done`.

---

## Cấu trúc thư mục source

Stack **TypeScript + Expo/React Native + MVVM (MobX)** (`react-native` skill) — bám đúng cây,
package theo feature:

```
app/
  di/
    container.ts                  composition root — new Container() + container.load(...modules)
    types.ts                      Symbol tokens cho interface bindings
    useViewModel.ts                container.get() qua useState() hook, dùng trong screen
    modules/
      dataModule.ts                StorageService/AuthStore/Api/ApiService/AppDatabase/RoomService/Repository
      viewModelModule.ts           ViewModel bindings
  viewmodels/base/BaseViewModel.ts  base MobX chung: isLoading/error/runAction() + repository
  stores/authStore.ts               MobX singleton cho state dùng chung nhiều screen, @injectable()
  screens/
    <ScreenName>/
      <ScreenName>Screen.tsx         View + styles trong 1 file — xem bên dưới
      <ScreenName>ViewModel.ts        toàn bộ logic/state (MobX) — chỉ khi screen có state
  navigators/                       AppNavigator (root stack) + MainTabNavigator (bottom tabs)
  components/                       UI dùng chung: Screen, Text, Button, Icon, TextField, Toggle...
  theme/                            colors, spacing, typography
  i18n/                             en.ts / vi.ts + translate()
  config/                           env config (API_URL, MASTER_API_URL, ...)
  data/
    Repository.ts                   interface: { apiService; roomService; storageService }
    AppRepositoryImpl.ts             @injectable() impl; property-inject vào BaseViewModel
    remote/api/
      index.ts                       apisauce Api client, attach Bearer token
      ApiService.ts                  interface thuần — chỉ signature, không gọi apisauce ở đây
      ApiServiceImpl.ts               impl — 1 apisauce call + 1 mapping DTO→domain / method
    model/
      api/item/                      domain shape trả về cho screen, 1 file / shape
      api/response/<domain>/         DTO wire-shape, 1 file / response
    local/
      room/                          AppDatabase/RoomService(Impl)/XxxDao(Impl) — expo-sqlite
      storage/                       MMKV load/save/remove + StorageService
  utils/                            date formatting, logging, crash reporting...
```

> Kiểm tra `viewmodels/base/` trước khi prompt — `BaseViewModel` đã có sẵn `isLoading`, `error`,
> `runAction()`. Chi tiết đầy đủ + code mẫu: [`skills/react-native/SKILL.md`](../skills/react-native/SKILL.md)
> và [`skills/react-native/references/stack.md`](../skills/react-native/references/stack.md).

---

## 1. Thêm feature mới

- **Nguồn Figma**: xem [design/GUIDE-Figma.md](./design/GUIDE-Figma.md)
- **Nguồn Claude Design**: xem [design/GUIDE-ClaudeDesign.md](./design/GUIDE-ClaudeDesign.md)
- **Cách label Figma cho AI đọc được**: xem [design/GUIDE-Figma-Labels.md](./design/GUIDE-Figma-Labels.md)
  — bắt buộc đọc trước khi giao design cho designer/AI.

---

## 2. Cập nhật feature có sẵn

> Mọi thay đổi surface/behavior đều phải qua `/feature` — không sửa thẳng file.

```
/feature Cập nhật <tên màn hình>
@<TênScreen>
@<TênViewModel>: <thay đổi cụ thể>, giữ nguyên <phần không đổi>.
```

Ví dụ:

```
/feature Cập nhật OrderListScreen
@OrderListScreen
@OrderListViewModel: thêm filter theo category — Picker load từ GET /v1/category/list
(đọc request/response model từ OpenAPI), khi chọn gọi lại GET /v1/order/list với
query param categoryId. FlatList row và Navigation giữ nguyên.
```

Review spec → sửa nếu lệch phạm vi → approve → build → `/done`.

Nếu screen bị sửa và cắt từ Figma → so sánh thủ công với `figma.png`/screenshot của
simulator sau build (không có script auto-diff sẵn cho RN — xem ghi chú ở
[design/GUIDE-Figma.md](./design/GUIDE-Figma.md)).
Nếu cắt từ Claude Design → so sánh thủ công qua `render_preview`.

---

## 3. Xóa feature

```
/feature Xóa màn hình <tên>
@<TênScreen>
@<TênViewModel>
khỏi app, không dùng nữa. <Lý do / đã thay thế bởi gì>.
Kiểm tra AppNavigator/MainTabNavigator, DI (container.ts/modules/*, types.ts) và bất kỳ
screen nào còn tham chiếu — đề xuất cách xử lý để duyệt trước khi xóa.
```

**Kỹ nhất ở Bước 2** — hành động khó đảo ngược:
- Route/`navigate()` nào còn trỏ tới screen bị xóa không?
- DI (`types.ts`, `modules/viewModelModule.ts`, `modules/dataModule.ts`) còn binding nào tới
  ViewModel/service bị xóa không?
- File nào còn `import` trực tiếp component/hook đã xóa không?

---

## Mẹo prompt chung

- Luôn bắt đầu bằng `/feature` — kể cả khi chỉ sửa 1 field có ảnh hưởng behavior.
- Khi review sai: prompt **"Sửa spec: ..."** + nêu cụ thể — tránh "chưa đúng, sửa lại đi".
- Chỉ approve khi đã đọc xong danh sách file dự kiến trong plan.
- **Figma phải label đúng `itz_*`** trước khi prompt — thiếu label = câu hỏi BLOCKING, agent
  không tự đoán. Chi tiết syntax: [design/GUIDE-Figma-Labels.md](./design/GUIDE-Figma-Labels.md).
- **Nguồn Claude Design**: không có auto-diff — prompt yêu cầu `render_preview` để so sánh thủ công.
- Nối API là **bước tiếp theo của cùng feature**, không phải feature "cập nhật" riêng.
- `/done` sau mỗi feature để giữ context sạch cho feature tiếp theo.
