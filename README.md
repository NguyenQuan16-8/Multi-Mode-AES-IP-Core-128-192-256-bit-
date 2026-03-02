# Multi-Mode AES IP Core (128/192/256-bit) with AXI4-Lite Interface

[cite_start]Dự án triển khai một bộ nhân mã hóa/giải mã **AES (Advanced Encryption Standard)** hoàn chỉnh bằng ngôn ngữ Verilog HDL[cite: 1, 49, 102]. [cite_start]Hệ thống được thiết kế dưới dạng một **IP Core** có khả năng cấu hình động, tích hợp giao tiếp chuẩn **AXI4-Lite** để dễ dàng kết nối với các hệ thống SoC và CPU[cite: 1, 4].

## 🚀 Các tính năng chính (Key Features)

* [cite_start]**Hỗ trợ đa chế độ (Multi-Mode):** Tích hợp cả 3 chuẩn độ dài khóa 128-bit, 192-bit và 256-bit trong cùng một thiết kế[cite: 49, 102, 231].
* [cite_start]**Chức năng kép (Dual Function):** Cho phép người dùng lựa chọn giữa chế độ Mã hóa (Encryption) hoặc Giải mã (Decryption) thông qua thanh ghi cấu hình[cite: 4, 11].
* [cite_start]**Giao tiếp AXI4-Lite:** Quản lý cấu hình và truyền nhận dữ liệu thông qua hệ thống thanh ghi 32-bit chuẩn[cite: 1, 6].
* [cite_start]**Kiến trúc tối ưu:** Sử dụng cấu trúc lặp (Iterative) giúp cân bằng giữa diện tích phần cứng và hiệu suất xử lý[cite: 80, 130].
* [cite_start]**Bộ mở rộng khóa tích hợp:** `AES_KEYEXP` tự động tính toán Round Keys cho cả 3 chế độ ngay trên phần cứng dựa trên tham số đầu vào[cite: 231, 233].

## 📂 Cấu trúc thư mục (Project Structure)

* [cite_start]`AES_AXI4LITE_TOP.v`: Module bọc ngoài cùng, thực hiện giải mã địa chỉ AXI và quản lý hệ thống thanh ghi[cite: 1].
* [cite_start]`AES_ENCRYPT.v` & `AES_DECRYPT.v`: Hai khối thực thi chính xử lý thuật toán mã hóa và giải mã theo từng vòng (Round)[cite: 49, 102].
* [cite_start]`AES_KEYEXP.v`: Bộ mở rộng khóa thông minh cấp phát khóa vòng (Round Keys) linh hoạt cho các độ dài 128/192/256-bit[cite: 231].
* **Sub-modules:**
    * [cite_start]`AES_SBOX.v` / `AES_INVSBOX.v`: Các bảng tra thế phi tuyến (SubBytes/InvSubBytes)[cite: 126, 177, 318].
    * [cite_start]`AES_MIXCOL.v` / `AES_INVMIXCOL.v`: Phép nhân ma trận trong trường Galois (MixColumns/InvMixColumns)[cite: 157, 302].
    * [cite_start]`AES_RCON.v` & `mul2.v`: Các thành phần toán học bổ trợ cho quá trình mở rộng khóa và nhân ma trận[cite: 312, 364].

## 🗺️ Bản đồ địa chỉ thanh ghi (Register Map)

[cite_start]Thông qua bus AXI4-Lite, bạn có thể điều khiển IP bằng các địa chỉ sau[cite: 29, 42]:

| Địa chỉ (Hex) | Tên thanh ghi | Mô tả chi tiết |
| :--- | :--- | :--- |
| **0x00** | **CTRL** | [0]: Start (Kích hoạt); [cite_start][1]: Mode (0: Mã hóa, 1: Giải mã)[cite: 29, 31, 42]. |
| **0x04** | **STATUS** | [0]: Busy (Đang xử lý); [cite_start][1]: Done (Xong - Sticky bit)[cite: 32, 43]. |
| **0x08** | **KEYLEN** | Chọn chuẩn khóa: 0=128-bit; 1=192-bit; [cite_start]2=256-bit[cite: 33, 43]. |
| **0x0C - 0x28** | **KEY0 - KEY7** | [cite_start]Nạp khóa mã hóa (tối đa 256-bit từ KEY0 đến KEY7)[cite: 6, 34, 36]. |
| **0x2C - 0x38** | **DIN0 - DIN3** | [cite_start]Nạp dữ liệu đầu vào (Plaintext/Ciphertext - 128-bit)[cite: 6, 36]. |
| **0x3C - 0x48** | **DOUT0 - DOUT3** | [cite_start]Đọc kết quả đầu ra sau khi xử lý (128-bit)[cite: 46]. |

## 🛠 Hướng dẫn sử dụng (Usage)

### 1. Mô phỏng (Simulation)
Sử dụng các công cụ như ModelSim, Vivado Simulator để biên dịch toàn bộ file `.v`.
```bash
# Lệnh biên dịch mẫu
vlog *.v
vsim AES_AXI4LITE_TOP
