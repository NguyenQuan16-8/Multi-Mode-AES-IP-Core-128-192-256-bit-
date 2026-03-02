# Multi-Mode AES IP Core (128/192/256-bit) with AXI4-Lite Interface

Dự án triển khai một bộ nhân mã hóa/giải mã **AES (Advanced Encryption Standard)** hoàn chỉnh bằng ngôn ngữ Verilog HDL. Hệ thống được thiết kế dưới dạng một **IP Core** có khả năng cấu hình động, tích hợp giao tiếp chuẩn **AXI4-Lite** để dễ dàng kết nối với các hệ thống SoC và CPU.

##  Key Features

* **Hỗ trợ đa chế độ (Multi-Mode):** Tích hợp cả 3 chuẩn độ dài khóa 128-bit, 192-bit và 256-bit trong cùng một thiết kế.
* **Chức năng kép (Dual Function):** Cho phép người dùng lựa chọn giữa chế độ Mã hóa (Encryption) hoặc Giải mã (Decryption) thông qua thanh ghi cấu hình.
* **Giao tiếp AXI4-Lite:** Quản lý cấu hình và truyền nhận dữ liệu thông qua hệ thống thanh ghi 32-bit chuẩn.
* **Kiến trúc:** Sử dụng cấu trúc lặp (Iterative) giúp cân bằng giữa diện tích phần cứng và hiệu suất xử lý.
* **Bộ mở rộng khóa tích hợp:** `AES_KEYEXP` tự động tính toán Round Keys cho cả 3 chế độ ngay trên phần cứng dựa trên tham số đầu vào.

##  Project Structure

* `AES_AXI4LITE_TOP.v`: Module bọc ngoài cùng, thực hiện giải mã địa chỉ AXI và quản lý hệ thống thanh ghi].
* `AES_ENCRYPT.v` & `AES_DECRYPT.v`: Hai khối thực thi chính xử lý thuật toán mã hóa và giải mã theo từng vòng (Round).
* `AES_KEYEXP.v`: Bộ mở rộng khóa thông minh cấp phát khóa vòng (Round Keys) linh hoạt cho các độ dài 128/192/256-bit.
* **Sub-modules:**
    * `AES_SBOX.v` / `AES_INVSBOX.v`: Các bảng tra thế phi tuyến (SubBytes/InvSubBytes).
    * `AES_MIXCOL.v` / `AES_INVMIXCOL.v`: Phép nhân ma trận trong trường Galois (MixColumns/InvMixColumns).
    * `AES_RCON.v` & `mul2.v`: Các thành phần toán học bổ trợ cho quá trình mở rộng khóa và nhân ma trận.

##  Register Map

Thông qua bus AXI4-Lite, bạn có thể điều khiển IP bằng các địa chỉ sau:

| Địa chỉ (Hex) | Tên thanh ghi | Mô tả chi tiết |
| :--- | :--- | :--- |
| **0x00** | **CTRL** |  Start (Kích hoạt);  Mode (0: Mã hóa, 1: Giải mã). |
| **0x04** | **STATUS** |  Busy (Đang xử lý);  Done (Xong - Sticky bit). |
| **0x08** | **KEYLEN** | Chọn chuẩn khóa: 0=128-bit; 1=192-bit; 2=256-bit. |
| **0x0C - 0x28** | **KEY0 - KEY7** | Nạp khóa mã hóa (tối đa 256-bit từ KEY0 đến KEY7). |
| **0x2C - 0x38** | **DIN0 - DIN3** | Nạp dữ liệu đầu vào (Plaintext/Ciphertext - 128-bit). |
| **0x3C - 0x48** | **DOUT0 - DOUT3** | Đọc kết quả đầu ra sau khi xử lý (128-bit). |

## Hướng dẫn sử dụng (Usage)

### 1. Mô phỏng (Simulation)
Sử dụng các công cụ như ModelSim, Vivado Simulator để biên dịch toàn bộ file `.v`.
```bash
# Lệnh biên dịch mẫu
vlog *.v
vsim AES_AXI4LITE_TOP
