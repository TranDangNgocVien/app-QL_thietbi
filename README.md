# Ứng dụng quản lý thiết bị

Ứng dụng Flutter sử dụng SQLite cục bộ. Database `equipment_rental.db` phiên
bản 2 chứa schema được chuyển đổi từ `Data_QLTB.sql`, gồm quản lý thiết bị,
khách hàng, mượn trả, thanh toán, gia hạn, phụ phí, bảo trì, báo cáo và các
bảng hỗ trợ tài khoản ứng dụng.

## Tài khoản mẫu

- Quản lý: `admin@thietbi.vn` / `123456`
- Quản lý: `tam@thietbi.vn` / `123456`
- Nhân viên: `bao@thietbi.vn` / `123456`
- Khách hàng: `customer@thietbi.vn` / `123456`
- Kỹ thuật viên: `tech@thietbi.vn` / `123456`
- Kỹ thuật viên Trần Thị Linh: `linh@thietbi.vn` / `123456`
- Quản lý Trần Viên: `vien@thietbi.vn` / `123456`

Database cũ được nâng cấp tự động và giữ nguyên các bảng SQLite đời trước.
Mục **Dữ liệu nghiệp vụ** trong menu cho phép xem dữ liệu các bảng mới.

Khách hàng có menu **Yêu cầu bảo trì** để gửi và theo dõi sự cố của những
thiết bị đã từng thuê. Nhân viên và quản lý không được tạo yêu cầu này.
