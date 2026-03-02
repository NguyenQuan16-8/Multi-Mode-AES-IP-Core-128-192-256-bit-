# Multi-Mode AES IP Core (128/192/256-bit) with AXI4-Lite Interface
* Dự án triển khai một bộ nhân mã hóa/giải mã AES (Advanced Encryption Standard) hoàn chỉnh bằng ngôn ngữ Verilog HDL. 
* Hệ thống được thiết kế dưới dạng một IP Core có khả năng cấu hình động, tích hợp giao tiếp chuẩn AXI4-Lite để dễ dàng kết nối với các hệ thống SoC và CPU.
## Key Features
* Hỗ trợ đa chế độ (Multi-Mode): Tích hợp cả 3 chuẩn độ dài khóa 128-bit, 192-bit và 256-bit trong cùng một thiết kế.
* Chức năng kép (Dual Function): Cho phép người dùng lựa chọn giữa chế độ Mã hóa (Encryption) hoặc Giải mã (Decryption) thông qua phần mềm.
* Giao tiếp AXI4-Lite: Quản lý cấu hình và truyền nhận dữ liệu thông qua hệ thống thanh ghi 32-bit chuẩn.
* Kiến trúc lặp giúp cân bằng giữa: Diện tích phần cứng (Area) và hiệu suất (Performance).


## Project Structure
├── AES_AXI4LITE_TOP.v   # Top wrapper + AXI address decoding + register control
├── AES_ENCRYPT.v        # Encryption round processing core
├── AES_DECRYPT.v        # Decryption round processing core
├── AES_KEYEXP.v         # Key expansion module (128/192/256-bit)
│
├── AES_SBOX.v           # SubBytes lookup table
├── AES_INVSBOX.v        # InvSubBytes lookup table
├── AES_MIXCOL.v         # MixColumns operation
├── AES_INVMIXCOL.v      # InvMixColumns operation
├── AES_RCON.v           # Round constant generator
└── mul2.v               # Galois field multiplication helper
