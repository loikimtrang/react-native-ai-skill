# GUIDE — Label control trên Figma (React Native)

## 1. Quy tắc chung

**Mọi layer có text, data binding, hoặc action PHẢI đặt tên theo cú pháp:**

```
itz_<Component>[<binding>]
```

- `itz_` là **prefix bắt buộc** — không có prefix này, AI không build layer đó thành component
  (trừ 2 trường hợp ngoại lệ ở mục 4).
- `<Component>` — **tên component React Native thật**, viết đúng như trong code (xem mục 2).
- `[<binding>]` — cặp ngoặc vuông quyết định layer lấy dữ liệu ở đâu (mục 5).
- Layer có nội dung/action mà **không** đặt `itz_*` → AI dừng lại, hỏi lại (**BLOCKING**), không tự
  đoán tên biến hay loại control.
- Layer **con của một `itz_*` component leaf** (label trong Button, placeholder trong TextField,
  icon trong TouchableOpacity) **không cần** đặt `itz_*` riêng — nó là nội dung nội bộ của
  component cha.

---

## 2. Bảng syntax control (React Native)

`itz_<Component>` — **không tra bảng cố định**: tên control là **tên component thật** (RN core hoặc
component dùng chung của project trong `app/components/`), đọc trực tiếp thành code. Bảng dưới là
các component phổ biến đã dùng trong project, không phải danh sách đóng.

| Syntax Figma | React Native / project component | Ví dụ |
|---|---|---|
| `itz_Text` | `Text` (`app/components/Text`) | `itz_Text[order_list_title]` |
| `itz_TextField` | `TextField` (`app/components/TextField`) | `itz_TextField[data.email]` |
| `itz_Button` | `Button` (`app/components/Button`) | `itz_Button[submit_label]` |
| `itz_Toggle` | `Toggle` (`app/components/Toggle`) | `itz_Toggle[data.enabled]` |
| `itz_Switch` | RN `Switch` | `itz_Switch[data.enabled]` |
| `itz_Picker` | project `Picker`/dropdown component | `itz_Picker[data.category]` |
| `itz_Slider` | `@react-native-community/slider` `Slider` | `itz_Slider[data.value]` |
| `itz_LoadingIndicator` | `LoadingIndicator` (`app/components/LoadingIndicator`) | `itz_LoadingIndicator[]` |
| `itz_FlatList` | RN `FlatList` | `itz_FlatList[data.items]` |
| `itz_SectionList` | RN `SectionList` | `itz_SectionList[data.sections]` |
| `itz_ScrollView` | RN `ScrollView` | `itz_ScrollView[]` |
| `itz_Image` | RN `Image` (asset local) | `itz_Image[]` (icon) |
| `itz_RemoteImage` | RN `Image` với `source={{ uri }}` (ảnh remote) | `itz_RemoteImage[data.avatarUrl]` |
| `itz_TouchableOpacity` | RN `TouchableOpacity` (card/row bấm được, không có label riêng) | `itz_TouchableOpacity[]` |
| `itz_CheckboxView` | custom `CheckboxView` (không có RN core built-in) | `itz_CheckboxView[data.agree]` |
| `itz_RadioButtonView` | custom `RadioButtonView` | `itz_RadioButtonView[data.selected]` |
| `itz_RatingView` | custom `RatingView` | `itz_RatingView[data.rating]` |
| `itz_ChipView` / `itz_ChipGroup` | custom `ChipView`/`ChipGroup` | `itz_ChipGroup[data.tags]` |
| `itz_CardView` | custom `CardView` | `itz_CardView[]` |
| `itz_WebView` | `react-native-webview` `WebView` | `itz_WebView[data.url]` |
| `itz_Modal` | RN `Modal` / bottom-sheet component | `itz_Modal[]` |
| `itz_View` / `itz_Screen` | ép kiểu container/screen wrapper khi cần | `itz_View[]`, `itz_Screen[]` |

---

## 3. `itz_Msg` — string tĩnh, không phải component

`itz_Msg` (alias `itz_msg`) **đứng riêng, ngoài bảng component ở mục 2** — nó không map sang một
component RN nào cả, mà chỉ là **alias cú pháp** cho `itz_Text[key]` khi layer thuần túy là một
chuỗi text tĩnh:

```
itz_Msg[key]   ==  itz_Text[key]
```

- Dùng khi layer chỉ cần hiển thị text tĩnh (lấy từ i18next `en.ts`/`vi.ts` qua `translate(key)`),
  không cần chỉ định rõ layer sẽ dựng thành `Text` hay một component khác chứa text.
- `key` là key trong `app/i18n/*.ts`; text trên layer Figma là giá trị (theo
  `react-native-strings.md`).
- Khi build, `itz_Msg[key]` vẫn dựng ra `<Text tx="key" />`/`translate('key')` như `itz_Text[key]`
  — chỉ khác cách đặt tên trên Figma, không có sự khác biệt về code sinh ra.
- Không dùng `itz_Msg[data.field]` — `itz_Msg` chỉ dành cho binding `[key]` (string tĩnh), không
  dùng cho dynamic; layer động phải đặt `itz_Text[data.field]`.

---

## 4. Ngoại lệ — layer KHÔNG cần `itz_*`

Chỉ 2 loại layer được miễn, vì không phải component:

1. **Structural container** — frame/group chỉ để gom nhóm/canh vị trí, không có text/data/action
   riêng. AI tự suy ra `View` với `style={{ flexDirection: 'column' | 'row' }}` từ Auto Layout của
   Figma — không cần đặt tên, giữ nguyên tên Figma mặc định (`Frame 2187`).
2. **Chrome / decoration** — status bar, notch, home indicator, vector trang trí thuần túy → bỏ
   qua hoàn toàn, không build (`SafeAreaView`/hệ điều hành tự vẽ phần này).

Container **có** text/data/action riêng (VD: card bấm được) **không** được coi là "chỉ gom
nhóm" — vẫn phải đặt `itz_*` như bình thường (ví dụ `itz_TouchableOpacity[]`/`itz_CardView[]`),
nếu không sẽ bị chặn.

---

## 5. Cú pháp binding — cặp ngoặc vuông `[...]`

| Ngoặc | Ý nghĩa | Kết quả |
|---|---|---|
| `[data.field]` | dynamic — bind từ ViewModel của màn hình | `viewModel.field` đọc trong `observer()` (two-way cho input: `value={viewModel.field}` + `onChangeText={(v) => viewModel.setField(v)}`). `data.user.name` (nested) → `viewModel.user.name`. |
| `[key]` | static — i18next resource, `key` là key trong `en.ts`/`vi.ts`, text trên layer là giá trị | `app/i18n/*.ts` (theo `react-native-strings.md`) |
| `[]` hoặc để trống `itz_<Component>` | hint — chỉ chọn component RN, không có text/data | con `itz_*` bên trong sẽ cung cấp nội dung |

**Lưu ý quan trọng**: text hiển thị trên Figma của layer `[data.field]` chỉ là **dữ liệu mẫu lúc
thiết kế** — AI **không bao giờ** copy thẳng vào `app/i18n/*.ts`. Field thật được xác nhận qua
OpenAPI, không lấy từ text mẫu trên Figma.

---

## 6. Ví dụ đặt tên layer thực tế

Màn hình danh sách sản phẩm:

| Vai trò | Syntax label Figma |
|---|---|
| Tiêu đề màn hình (static) | `itz_Text[order_list_title]` |
| Nút back (icon, không data) | `itz_Image[]` |
| Danh sách sản phẩm (dynamic) | `itz_FlatList[data.items]` |
| Tên sản phẩm trong row | `itz_Text[data.name]` |
| Ảnh sản phẩm trong row (remote) | `itz_RemoteImage[data.imageUrl]` |
| Nút submit | `itz_Button[submit_label]` |
| Ô nhập tìm kiếm | `itz_TextField[data.query]` |
| Checkbox chọn item | `itz_CheckboxView[data.selected]` |

---

## 7. Checklist trước khi giao Figma cho AI code

- [ ] Mọi layer có text/data/action đã có prefix `itz_` chưa?
- [ ] Tên control là component React Native thật, tồn tại trong `app/components/` (hoặc RN core),
      hoặc rõ ràng là component mới cần tạo?
- [ ] Binding `[data.field]`/`[key]`/`[]` đã chọn đúng loại chưa — không để trống khi cần bind?
- [ ] Container thuần layout **không** bị gán nhầm `itz_*`; container có action **có** được gán
      (`itz_TouchableOpacity`/`itz_CardView`)?
- [ ] Chrome (status bar, notch, home indicator…) chưa bị đặt tên `itz_*` nhầm?

Xem thêm quy trình build đầy đủ: [GUIDE-Figma.md](./GUIDE-Figma.md).
