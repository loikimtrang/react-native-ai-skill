# GUIDE — Thêm feature mới từ Figma (React Native)

> Phần chung (cập nhật, xóa, mẹo): [../GUIDE.md](../GUIDE.md)
> Nguồn Claude Design: [GUIDE-ClaudeDesign.md](./GUIDE-ClaudeDesign.md)
> Syntax label control trên Figma: [GUIDE-Figma-Labels.md](./GUIDE-Figma-Labels.md)

---

## Chuẩn bị

Trước khi prompt:
1. Mở **Figma desktop**, connect plugin `figma-bridge`
2. **Select sẵn frame** cần implement — agent đọc node đang select, không tự tìm theo tên
3. Label layer đúng syntax `itz_<RNComponent>[<binding>]` (`itz_Text`, `itz_TextField`,
   `itz_Button`, `itz_FlatList`, …) — xem đầy đủ bảng syntax ở
   [GUIDE-Figma-Labels.md](./GUIDE-Figma-Labels.md). Layer có text/data/action mà không label
   `itz_*` sẽ bị chặn (BLOCKING) khi build prompt.
4. Đặt `testID` khớp tên layer khi build — dùng để đối chiếu thủ công screenshot simulator vs Figma.

---

## Prompt

```
/feature <tên chức năng>
Figma: frame đang select.
API: <GET|POST|...> <path> — đọc request/response model từ OpenAPI.
```

Chỉ thêm dòng cuối khi có business rule model không tự đoán được:

```
/feature <tên chức năng>
Figma: frame đang select.
API: <GET|POST|...> <path> — đọc request/response model từ OpenAPI.
<Ràng buộc — ví dụ: ẩn item status=0, bấm item navigate tới XxxScreen.>
```

Ví dụ:

```
/feature Màn hình Danh sách Sản phẩm
Figma: frame đang select.
API: GET /v1/product/list — đọc request/response model từ OpenAPI.
Ẩn item status = 0. Bấm item navigate tới ProductDetailScreen.
```

```
/feature Màn hình Thực đơn
Figma: frame đang select.
API: GET /v1/menu/list — đọc request/response model từ OpenAPI.
List nhóm theo category, ẩn món isAvailable = false.
```

```
/feature Màn hình CourseList
Figma: frame đang select.
API: GET /v1/course/list — đọc request/response model từ OpenAPI.
```

Muốn agent tự hỏi + build sẵn prompt đầy đủ (khuyên dùng cho screen phức tạp nhiều component):
dùng skill [`react-native-prompt-creator`](../../skills/react-native-prompt-creator/SKILL.md) — nó
đọc node, resolve từng layer `itz_*`, hỏi phần binding/action còn thiếu, rồi in ra prompt paste
thẳng vào `/feature`.

`/feature` sinh spec/plan/tasks → **dừng để bạn duyệt**.

---

## Review → Sửa spec → Approve

Kiểm tra spec có đúng phạm vi không: file list, Screen/ViewModel, navigation
(`navigate`/`push`/modal), DI qua `useViewModel`/constructor.

```
Sửa spec: bỏ sót empty state — thêm vào plan. List cần multi-type (header + item).
```

```
ok, build đi.
```

---

## Xác nhận khớp thiết kế (thủ công)

React Native chưa có script auto coord-diff/pixel-diff đóng gói sẵn (khác với `ios-ui`/`android-ui`
ở các stack khác) — so sánh **thủ công** sau build:

```
Chụp screenshot màn vừa build trên simulator, so với ảnh export từ Figma (get_screenshot /
save_screenshots), báo chỗ lệch layout/màu/spacing để sửa.
```

- Dùng `testID` trùng tên layer Figma để dễ đối chiếu bằng mắt / bằng công cụ chấm tọa độ ngoài.
- Nếu team cần gate tự động (coord-diff + pixel-diff kiểu `ios-ui`), đó là việc thêm 1 skill
  `react-native-ui` riêng — hiện chưa có trong skill này.

---

## Nối API

Sau khi UI pass, màn đang dùng mock. Khi endpoint thật sẵn:

```
/feature integrate api GET /v1/product/list cho ProductListScreen,
mock cần xóa là ProductListViewModel.
```

Xong: `/done`
