#  Multi-Mode AES IP Core (128/192/256-bit) with AXI4-Lite Interface

Dự án triển khai bộ mã hóa/giải mã **AES (Advanced Encryption Standard)** hoàn chỉnh bằng **Verilog HDL**.  
Thiết kế dưới dạng **IP Core cấu hình động**, tích hợp giao tiếp chuẩn **AXI4-Lite**, dễ dàng kết nối với hệ thống SoC hoặc CPU.

---

##  Key Features

* **Multi-Mode Support:**  
  Hỗ trợ AES-128, AES-192 và AES-256 trong cùng một thiết kế.

* **Dual Function (Encrypt/Decrypt):**  
  Lựa chọn chế độ Mã hóa hoặc Giải mã thông qua thanh ghi điều khiển.

* **AXI4-Lite Interface:**  
  Cấu hình và truyền dữ liệu thông qua hệ thống thanh ghi 32-bit chuẩn.

* **Iterative Architecture:**  
  Kiến trúc lặp tối ưu giúp cân bằng giữa diện tích phần cứng (Area) và hiệu suất xử lý (Performance).

* **Integrated Key Expansion:**  
  Module `AES_KEYEXP` tự động tính toán Round Keys cho cả 3 độ dài khóa 128/192/256-bit.

---

##  Project Structure

```
AES_AXI4LITE_TOP.v   # Top wrapper + AXI address decoding + register control
AES_ENCRYPT.v        # Encryption core (round-based processing)
AES_DECRYPT.v        # Decryption core (inverse round processing)
AES_KEYEXP.v         # Key expansion module (128/192/256-bit)

Sub-modules:
  AES_SBOX.v         # SubBytes lookup table
  AES_INVSBOX.v      # InvSubBytes lookup table
  AES_MIXCOL.v       # MixColumns operation
  AES_INVMIXCOL.v    # InvMixColumns operation
  AES_RCON.v         # Round constant generator
  mul2.v             # Galois field multiplication helper
```

---

##  Register Map (AXI4-Lite)

| Address | Register | Description |
|----------|----------|-------------|
| `0x00` | CTRL | `[0] Start` – Kích hoạt xử lý<br>`[1] Mode` – 0: Encrypt, 1: Decrypt |
| `0x04` | STATUS | `[0] Busy` – Đang xử lý<br>`[1] Done` – Hoàn tất (Sticky bit) |
| `0x08` | KEYLEN | 0: 128-bit<br>1: 192-bit<br>2: 256-bit |
| `0x0C – 0x28` | KEY0 – KEY7 | Nạp khóa (tối đa 256-bit) |
| `0x2C – 0x38` | DIN0 – DIN3 | Dữ liệu đầu vào 128-bit |
| `0x3C – 0x48` | DOUT0 – DOUT3 | Dữ liệu đầu ra 128-bit |

---

##  Operation Flow

1. Ghi giá trị vào thanh ghi `KEYLEN`.
2. Nạp khóa vào `KEY0 – KEY7`.
3. Nạp dữ liệu vào `DIN0 – DIN3`.
4. Ghi vào thanh ghi `CTRL`:
   * Bit `[1]` → Chọn chế độ (Encrypt/Decrypt)
   * Bit `[0]` → Start
5. Theo dõi thanh ghi `STATUS`:
   * `Busy = 1` → Đang xử lý
   * `Done = 1` → Hoàn tất
6. Đọc kết quả tại `DOUT0 – DOUT3`.

---

##  Architecture Overview

* Iterative round-based AES core  
* Shared datapath cho encryption và decryption  
* Hardware key expansion engine  
* AXI register-controlled processing  

