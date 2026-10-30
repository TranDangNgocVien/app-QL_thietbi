
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS GiaHanMuon;
DROP TABLE IF EXISTS ThanhToan;
DROP TABLE IF EXISTS PhieuViPham;
DROP TABLE IF EXISTS ChiTietPM;
DROP TABLE IF EXISTS BaoTri;
DROP TABLE IF EXISTS BaoCao;
DROP TABLE IF EXISTS PhieuMuon;
DROP TABLE IF EXISTS YeuCauMuon;
DROP TABLE IF EXISTS ThietBi;
DROP TABLE IF EXISTS LoaiThietBi;
DROP TABLE IF EXISTS NhaCungCap;
DROP TABLE IF EXISTS KhachHang;
DROP TABLE IF EXISTS NhanVien;

CREATE TABLE LoaiThietBi (
    MaLoai TEXT PRIMARY KEY,
    TenLoai TEXT NOT NULL UNIQUE,
    MoTa TEXT,
    CHECK (length(trim(MaLoai)) > 0),
    CHECK (length(trim(TenLoai)) > 0)
);

CREATE TABLE NhaCungCap (
    MaNCC TEXT PRIMARY KEY,
    TenNCC TEXT NOT NULL,
    DiaChi TEXT,
    SDT TEXT,
    Email TEXT,
    CHECK (length(trim(MaNCC)) > 0),
    CHECK (length(trim(TenNCC)) > 0),
    CHECK (SDT IS NULL OR SDT GLOB '[0-9]*'),
    CHECK (Email IS NULL OR Email LIKE '%_@_%._%')
);

CREATE TABLE NhanVien (
    MaNV TEXT PRIMARY KEY,
    TenNV TEXT NOT NULL,
    ChucVu TEXT,
    QuyenHan TEXT NOT NULL DEFAULT 'nhan_vien',
    CHECK (length(trim(MaNV)) > 0),
    CHECK (length(trim(TenNV)) > 0),
    CHECK (QuyenHan IN ('quan_tri', 'quan_ly', 'nhan_vien'))
);

CREATE TABLE KhachHang (
    MaKH TEXT PRIMARY KEY,
    HoTen TEXT NOT NULL,
    SDT TEXT,
    Email TEXT,
    CCCD TEXT UNIQUE,
    DiaChi TEXT,
    CongNo REAL NOT NULL DEFAULT 0,
    CHECK (length(trim(MaKH)) > 0),
    CHECK (length(trim(HoTen)) > 0),
    CHECK (SDT IS NULL OR SDT GLOB '[0-9]*'),
    CHECK (Email IS NULL OR Email LIKE '%_@_%._%'),
    CHECK (CCCD IS NULL OR length(CCCD) BETWEEN 9 AND 12),
    CHECK (CongNo >= 0)
);

CREATE TABLE ThietBi (
    MaTB TEXT PRIMARY KEY,
    TenTB TEXT NOT NULL,
    DonGiaThue REAL NOT NULL,
    SoLuongTong INTEGER NOT NULL,
    SoLuongKhaDung INTEGER NOT NULL,
    MoTaThuat TEXT,
    HinhAnh TEXT,
    MaLoai TEXT NOT NULL,
    MaNCC TEXT NOT NULL,
    TrangThai TEXT NOT NULL DEFAULT 'kha_dung',
    FOREIGN KEY (MaLoai) REFERENCES LoaiThietBi(MaLoai) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (MaNCC) REFERENCES NhaCungCap(MaNCC) ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (length(trim(MaTB)) > 0),
    CHECK (length(trim(TenTB)) > 0),
    CHECK (DonGiaThue >= 0),
    CHECK (SoLuongTong >= 0),
    CHECK (SoLuongKhaDung >= 0),
    CHECK (SoLuongKhaDung <= SoLuongTong),
    CHECK (TrangThai IN ('kha_dung', 'dang_muon', 'bao_tri', 'hong', 'ngung_su_dung'))
);

CREATE TABLE YeuCauMuon (
    MaYCM TEXT PRIMARY KEY,
    NgayYeuCau TEXT NOT NULL DEFAULT (date('now')),
    NgayBatDau TEXT NOT NULL,
    NgayTraDuKien TEXT NOT NULL,
    MucDichSuDung TEXT,
    TrangThaiYeuCau TEXT NOT NULL DEFAULT 'cho_duyet',
    LyDoTuChoi TEXT,
    MaKH TEXT NOT NULL,
    MaNV TEXT,
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV) ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (date(NgayBatDau) >= date(NgayYeuCau)),
    CHECK (date(NgayTraDuKien) >= date(NgayBatDau)),
    CHECK (TrangThaiYeuCau IN ('cho_duyet', 'da_duyet', 'tu_choi', 'da_lap_phieu', 'huy'))
);

CREATE TABLE PhieuMuon (
    MaPM TEXT PRIMARY KEY,
    NgayMuon TEXT NOT NULL DEFAULT (date('now')),
    NgayTraDuKien TEXT NOT NULL,
    NgayTraThucTe TEXT,
    TongTien REAL NOT NULL DEFAULT 0,
    TrangThai TEXT NOT NULL DEFAULT 'dang_muon',
    MaKH TEXT NOT NULL,
    MaNV TEXT,
    MaYCM TEXT UNIQUE,
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY (MaYCM) REFERENCES YeuCauMuon(MaYCM) ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (date(NgayTraDuKien) >= date(NgayMuon)),
    CHECK (NgayTraThucTe IS NULL OR date(NgayTraThucTe) >= date(NgayMuon)),
    CHECK (TongTien >= 0),
    CHECK (TrangThai IN ('dang_muon', 'da_tra', 'qua_han', 'huy'))
);

CREATE TABLE ChiTietPM (
    MaPM TEXT NOT NULL,
    MaTB TEXT NOT NULL,
    SoLuong INTEGER NOT NULL,
    DonGiaTaiThoiDiem REAL NOT NULL,
    TinhTrangKhiGiao TEXT,
    TinhTrangKhiTra TEXT,
    PhiBoiThuong REAL NOT NULL DEFAULT 0,
    PRIMARY KEY (MaPM, MaTB),
    FOREIGN KEY (MaPM) REFERENCES PhieuMuon(MaPM) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (MaTB) REFERENCES ThietBi(MaTB) ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (SoLuong > 0),
    CHECK (DonGiaTaiThoiDiem >= 0),
    CHECK (PhiBoiThuong >= 0)
);

CREATE TABLE BaoTri (
    MaBT TEXT PRIMARY KEY,
    NgayYeuCau TEXT NOT NULL DEFAULT (date('now')),
    MoTaSuCo TEXT NOT NULL,
    MucDoHuHong TEXT NOT NULL DEFAULT 'nhe',
    TrangThai TEXT NOT NULL DEFAULT 'cho_xu_ly',
    KetQuaXuLy TEXT,
    MaTB TEXT NOT NULL,
    MaKH TEXT,
    MaNV TEXT,
    FOREIGN KEY (MaTB) REFERENCES ThietBi(MaTB) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV) ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (MucDoHuHong IN ('nhe', 'trung_binh', 'nang')),
    CHECK (TrangThai IN ('cho_xu_ly', 'dang_xu_ly', 'da_xu_ly', 'huy'))
);

CREATE TABLE PhieuViPham (
    MaPVP TEXT PRIMARY KEY,
    LoaiViPham TEXT NOT NULL,
    MoTa TEXT,
    SoTienPhat REAL NOT NULL DEFAULT 0,
    NgayGhiNhan TEXT NOT NULL DEFAULT (date('now')),
    TrangThaiXuLy TEXT NOT NULL DEFAULT 'chua_xu_ly',
    MaPM TEXT NOT NULL,
    FOREIGN KEY (MaPM) REFERENCES PhieuMuon(MaPM) ON UPDATE CASCADE ON DELETE CASCADE,
    CHECK (SoTienPhat >= 0),
    CHECK (TrangThaiXuLy IN ('chua_xu_ly', 'da_xu_ly', 'huy'))
);

CREATE TABLE ThanhToan (
    MaTT TEXT PRIMARY KEY,
    NgayThanhToan TEXT NOT NULL DEFAULT (date('now')),
    SoTien REAL NOT NULL,
    PhuongThuc TEXT NOT NULL DEFAULT 'tien_mat',
    LoaiThanhToan TEXT NOT NULL DEFAULT 'tien_thue',
    TrangThai TEXT NOT NULL DEFAULT 'da_thanh_toan',
    MaPM TEXT NOT NULL,
    FOREIGN KEY (MaPM) REFERENCES PhieuMuon(MaPM) ON UPDATE CASCADE ON DELETE CASCADE,
    CHECK (SoTien > 0),
    CHECK (PhuongThuc IN ('tien_mat', 'chuyen_khoan', 'the', 'vi_dien_tu')),
    CHECK (LoaiThanhToan IN ('tien_thue', 'tien_phat', 'boi_thuong', 'dat_coc', 'khac')),
    CHECK (TrangThai IN ('cho_thanh_toan', 'da_thanh_toan', 'that_bai', 'huy'))
);

CREATE TABLE GiaHanMuon (
    MaGH TEXT PRIMARY KEY,
    NgayYeuCau TEXT NOT NULL DEFAULT (date('now')),
    NgayTraCu TEXT NOT NULL,
    NgayTraMoi TEXT NOT NULL,
    TrangThaiGiaHan TEXT NOT NULL DEFAULT 'cho_duyet',
    LyDoGiaHan TEXT,
    MaPM TEXT NOT NULL,
    MaNV TEXT,
    FOREIGN KEY (MaPM) REFERENCES PhieuMuon(MaPM) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV) ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (date(NgayTraMoi) > date(NgayTraCu)),
    CHECK (TrangThaiGiaHan IN ('cho_duyet', 'da_duyet', 'tu_choi', 'huy'))
);

CREATE TABLE BaoCao (
    MaBC TEXT PRIMARY KEY,
    LoaiBaoCao TEXT NOT NULL,
    TuNgay TEXT NOT NULL,
    DenNgay TEXT NOT NULL,
    NgayLap TEXT NOT NULL DEFAULT (date('now')),
    NoiDungTongLap TEXT,
    MaNV TEXT NOT NULL,
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV) ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (date(DenNgay) >= date(TuNgay)),
    CHECK (LoaiBaoCao IN ('thiet_bi', 'muon_tra', 'doanh_thu', 'bao_tri', 'khach_hang'))
);

CREATE TRIGGER trg_ctpm_check_soluong_insert
BEFORE INSERT ON ChiTietPM
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NEW.SoLuong > (SELECT SoLuongKhaDung FROM ThietBi WHERE MaTB = NEW.MaTB)
        THEN RAISE(ABORT, 'So luong muon vuot qua so luong kha dung')
    END;
END;

CREATE TRIGGER trg_ctpm_after_insert
AFTER INSERT ON ChiTietPM
FOR EACH ROW
BEGIN
    UPDATE ThietBi
    SET SoLuongKhaDung = SoLuongKhaDung - NEW.SoLuong,
        TrangThai = CASE
            WHEN SoLuongKhaDung - NEW.SoLuong = 0 THEN 'dang_muon'
            ELSE TrangThai
        END
    WHERE MaTB = NEW.MaTB;

    UPDATE PhieuMuon
    SET TongTien = (
        SELECT IFNULL(SUM(SoLuong * DonGiaTaiThoiDiem), 0)
        FROM ChiTietPM
        WHERE MaPM = NEW.MaPM
    )
    WHERE MaPM = NEW.MaPM;
END;

CREATE TRIGGER trg_ctpm_after_delete
AFTER DELETE ON ChiTietPM
FOR EACH ROW
BEGIN
    UPDATE ThietBi
    SET SoLuongKhaDung = SoLuongKhaDung + OLD.SoLuong,
        TrangThai = CASE
            WHEN SoLuongKhaDung + OLD.SoLuong > 0 AND TrangThai = 'dang_muon' THEN 'kha_dung'
            ELSE TrangThai
        END
    WHERE MaTB = OLD.MaTB;

    UPDATE PhieuMuon
    SET TongTien = (
        SELECT IFNULL(SUM(SoLuong * DonGiaTaiThoiDiem), 0)
        FROM ChiTietPM
        WHERE MaPM = OLD.MaPM
    )
    WHERE MaPM = OLD.MaPM;
END;

CREATE TRIGGER trg_phieumuon_tra_thietbi
AFTER UPDATE OF TrangThai ON PhieuMuon
FOR EACH ROW
WHEN NEW.TrangThai = 'da_tra' AND OLD.TrangThai <> 'da_tra'
BEGIN
    UPDATE ThietBi
    SET SoLuongKhaDung = SoLuongKhaDung + (
        SELECT IFNULL(SUM(SoLuong), 0)
        FROM ChiTietPM
        WHERE ChiTietPM.MaPM = NEW.MaPM
          AND ChiTietPM.MaTB = ThietBi.MaTB
    ),
    TrangThai = CASE
        WHEN TrangThai = 'dang_muon' THEN 'kha_dung'
        ELSE TrangThai
    END
    WHERE MaTB IN (SELECT MaTB FROM ChiTietPM WHERE MaPM = NEW.MaPM);
END;

CREATE TRIGGER trg_giahan_duyet
AFTER UPDATE OF TrangThaiGiaHan ON GiaHanMuon
FOR EACH ROW
WHEN NEW.TrangThaiGiaHan = 'da_duyet'
BEGIN
    UPDATE PhieuMuon
    SET NgayTraDuKien = NEW.NgayTraMoi
    WHERE MaPM = NEW.MaPM;
END;

CREATE TRIGGER trg_thanhtoan_check_tien
BEFORE INSERT ON ThanhToan
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN (
            NEW.SoTien + IFNULL((SELECT SUM(SoTien) FROM ThanhToan WHERE MaPM = NEW.MaPM AND TrangThai = 'da_thanh_toan'), 0)
        ) > (
            IFNULL((SELECT TongTien FROM PhieuMuon WHERE MaPM = NEW.MaPM), 0)
            + IFNULL((SELECT SUM(SoTienPhat) FROM PhieuViPham WHERE MaPM = NEW.MaPM AND TrangThaiXuLy <> 'huy'), 0)
            + IFNULL((SELECT SUM(PhiBoiThuong) FROM ChiTietPM WHERE MaPM = NEW.MaPM), 0)
        )
        THEN RAISE(ABORT, 'So tien thanh toan vuot qua tong so tien phai thu')
    END;
END;

CREATE VIEW v_ThongKeThietBi AS
SELECT tb.MaTB, tb.TenTB, ltb.TenLoai, ncc.TenNCC,
       tb.SoLuongTong, tb.SoLuongKhaDung, tb.TrangThai
FROM ThietBi tb
JOIN LoaiThietBi ltb ON tb.MaLoai = ltb.MaLoai
JOIN NhaCungCap ncc ON tb.MaNCC = ncc.MaNCC;

CREATE VIEW v_CongNoKhachHang AS
SELECT kh.MaKH, kh.HoTen,
       IFNULL(SUM(pm.TongTien), 0)
       + IFNULL(SUM(pvp.SoTienPhat), 0)
       + IFNULL(SUM(ct.PhiBoiThuong), 0)
       - IFNULL(SUM(tt.SoTien), 0) AS CongNoTinhToan
FROM KhachHang kh
LEFT JOIN PhieuMuon pm ON kh.MaKH = pm.MaKH
LEFT JOIN ChiTietPM ct ON pm.MaPM = ct.MaPM
LEFT JOIN PhieuViPham pvp ON pm.MaPM = pvp.MaPM
LEFT JOIN ThanhToan tt ON pm.MaPM = tt.MaPM AND tt.TrangThai = 'da_thanh_toan'
GROUP BY kh.MaKH, kh.HoTen;

INSERT INTO LoaiThietBi(MaLoai, TenLoai, MoTa) VALUES
('LTB001', 'Máy chiếu', 'Thiết bị trình chiếu'),
('LTB002', 'Laptop', 'Máy tính xách tay'),
('LTB003', 'Âm thanh', 'Loa, micro, mixer');

INSERT INTO NhaCungCap(MaNCC, TenNCC, DiaChi, SDT, Email) VALUES
('NCC001', 'Công ty Thiết bị A', 'TP.HCM', '0900000001', 'ncca@example.com'),
('NCC002', 'Công ty Thiết bị B', 'Hà Nội', '0900000002', 'nccb@example.com');

INSERT INTO NhanVien(MaNV, TenNV, ChucVu, QuyenHan) VALUES
('NV001', 'Nguyễn Văn Quản', 'Quản lý', 'quan_ly'),
('NV002', 'Trần Thị Nhân', 'Nhân viên', 'nhan_vien');

INSERT INTO KhachHang(MaKH, HoTen, SDT, Email, CCCD, DiaChi) VALUES
('KH001', 'Lê Văn Khách', '0911111111', 'khach1@example.com', '123456789012', 'TP.HCM');

INSERT INTO ThietBi(MaTB, TenTB, DonGiaThue, SoLuongTong, SoLuongKhaDung, MoTaThuat, MaLoai, MaNCC, TrangThai) VALUES
('TB001', 'Máy chiếu Epson X500', 150000, 5, 5, 'Full HD, HDMI', 'LTB001', 'NCC001', 'kha_dung'),
('TB002', 'Laptop Dell Latitude', 200000, 10, 10, 'Core i5, RAM 8GB', 'LTB002', 'NCC002', 'kha_dung'),
('TB003', 'Loa kéo JBL', 120000, 4, 4, 'Bluetooth, micro không dây', 'LTB003', 'NCC001', 'kha_dung');
