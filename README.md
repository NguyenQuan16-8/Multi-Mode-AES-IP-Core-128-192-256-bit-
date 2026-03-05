#  Multi-Mode AES IP Core (128/192/256-bit) with AXI4-Lite Interface

The project implements a complete **AES (Advanced Encryption Standard)** encoder/decoder using **Verilog HDL**.

Designed as a dynamically configurable IP Core, it integrates a standard AXI4-Lite interface, making it easy to connect with SoC systems or CPUs.

---

##  Key Features

* **Multi-Mode Support:**  
  Supports AES-128, AES-192, and AES-256 in the same design.

* **Dual Function (Encrypt/Decrypt):**  
  Select Encryption or Decryption mode via the control register.

* **AXI4-Lite Interface:**  
  Configuration and data transfer via a standard 32-bit register system.

* **Iterative Architecture:**  
  Optimized iterative architecture balances hardware Area and Performance.

* **Integrated Key Expansion:**  
  The `AES_KEYEXP` module automatically calculates Round Keys for all 3 key lengths: 128/192/256-bit.

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
| `0x00` | CTRL | `[0] Start` – Trigger processing<br>`[1] Mode` – 0: Encrypt, 1: Decrypt |
| `0x04` | STATUS | `[0] Busy` – Processing<br>`[1] Done` – Finished (Sticky bit) |
| `0x08` | KEYLEN | 0: 128-bit<br>1: 192-bit<br>2: 256-bit |
| `0x0C – 0x28` | KEY0 – KEY7 | Key loading (up to 256-bit) |
| `0x2C – 0x38` | DIN0 – DIN3 | 128-bit Input Data|
| `0x3C – 0x48` | DOUT0 – DOUT3 | 128-bit Output Data |

---

##  Operation Flow

1. Write the value to the `KEYLEN` register.
2. Load the key into `KEY0 – KEY7`.
3. Load the input data into `DIN0 – DIN3`.
4. Write to the `CTRL` register:
   * Bit `[1]` → Select mode (Encrypt/Decrypt)
   * Bit `[0]` → Start
5. Monitor the `STATUS` register:
   * `Busy = 1` → Processing
   * `Done = 1` → Finished
6. Read the result from `DOUT0 – DOUT3`.



