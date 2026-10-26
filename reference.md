# FPGA Matrix Multiplication — References

## 1. Project Overview

**Đề tài:** Thiết kế bộ nhân hai ma trận 8×8 signed INT16 trên FPGA Intel Cyclone IV EP4CE6.

**Kiến trúc dự kiến:**

- 2×2 PE Array (4 MAC song song).
- FSM Controller điều khiển phép nhân ma trận.
- ROM/RAM lưu ma trận A, B và C.
- UART RX/TX để nhập ma trận từ PC và trả kết quả.
- Python Golden Model để kiểm tra tính chính xác.

**Phạm vi:** Thiết kế RTL bằng Verilog, không sử dụng RISC-V hoặc CPU softcore.

## 2. Matrix Multiplication & PE Array

| Reference | Nội dung tham khảo | Ưu tiên |
|---|---|---|
| [Matrix Multiplication Accelerator](https://github.com/GuanShiChen/matrix-multiplication-accelerator) | Processing Element, systolic array, controller, testbench | Cao |
| [Systolic Array Matrix Multiplier](https://github.com/debtanu09/systolic_array_matrix_multiplier) | Kiến trúc PE, MAC và systolic array bằng Verilog | Cao |
| [INT8 Systolic MatMul FPGA](https://github.com/bgordeev/int8-systolic-matmul-fpga) | Sequential MAC, systolic array, verification, benchmark | Cao |
| [Matrix Multiplier Verilog](https://github.com/YevgeniYagudin/Matrix-multiplier-Verilog) | Matrix memory, control logic, verification | Trung bình |
| [2D Systolic Array Multiplier](https://github.com/tms4517/2D-Systolic-Array-Multiplier) | 2D PE Array, RTL và simulation | Trung bình |

### Nội dung cần nghiên cứu

- Thiết kế signed INT16 multiplier và 35-bit accumulator.
- Cấu trúc PE/MAC Array.
- Output-stationary dataflow.
- Matrix tiling và data reuse.
- Điều khiển FSM và quản lý bộ nhớ.
- Testbench kiểm tra kết quả.

**Lưu ý:** Các project tham khảo có thể dùng kích thước ma trận, precision và FPGA khác nhau. Không giả định chúng tương thích trực tiếp với EP4CE6.

## 3. UART Communication

| Reference | Nội dung |
|---|---|
| [Nandland UART](https://github.com/nandland/UART) | UART RX/TX bằng Verilog |
| [UART for FPGA](https://github.com/stffrdhrn/uart) | Ví dụ UART RTL và FPGA integration |
| [PySerial Documentation](https://pyserial.readthedocs.io/en/latest/) | Python serial communication |

### Mục tiêu

```text
PC (Python)
    |
    | UART RX: Matrix A + Matrix B
    v
Cyclone IV FPGA
    |
    | Matrix Multiplication
    v
Matrix C Buffer
    |
    | UART TX: Matrix C
    v
PC (Python)
    |
    v
Compare with NumPy
    |
    v
PASS / FAIL
```

Dữ liệu truyền dự kiến:

- Matrix A: 64 × INT16 = 128 bytes.
- Matrix B: 64 × INT16 = 128 bytes.
- Matrix C: 64 × INT64 = 512 bytes (mở rộng dấu từ kết quả INT35).
- UART baud rate: 115200.

Cần thiết kế giao thức truyền với header, độ dài dữ liệu, lệnh START và phản hồi DONE để tránh nhầm frame.

## 4. FPGA Memory & Quartus

| Reference | Nội dung |
|---|---|
| [Intel/Altera Memory Initialization File](https://resources.altera.com/quartushelp/26.1/reference/glossary/def_mif.htm) | Cú pháp `.mif` để khởi tạo ROM/RAM |
| [Cyclone IV Device Handbook](https://www.intel.com/content/www/us/en/docs/programmable/683151/current/overview.html) | Tài nguyên FPGA, embedded memory và multiplier |
| [Quartus Prime Lite](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/download.html) | Công cụ synthesis và FPGA programming |

### Nội dung cần nghiên cứu

- Khởi tạo ROM bằng `.mif`.
- Sử dụng M9K embedded memory.
- Synthesis signed multiplication sang embedded multiplier.
- Timing analysis và Fmax.
- FPGA pin assignment.
- Nạp `.sof` qua USB-Blaster.

## 5. Verification & Golden Model

| Reference | Nội dung |
|---|---|
| [NumPy Matrix Multiplication](https://numpy.org/doc/stable/reference/generated/numpy.matmul.html) | Tính ma trận tham chiếu |
| [Icarus Verilog](https://github.com/steveicarus/iverilog) | RTL simulation |
| [Verilator](https://github.com/verilator/verilator) | Verilog/SystemVerilog simulation |

### Test Cases

| ID | Test | Expected |
|---|---|---|
| TC01 | Zero Matrix | C = 0 |
| TC02 | Identity Matrix | C = B |
| TC03 | Constant Matrix | A = 2, B = 3 → C = 48 |
| TC04 | Signed Values | Đúng với số âm/dương |
| TC05 | INT16 Boundary | Không overflow accumulator |
| TC06 | Random Matrix | 64/64 kết quả khớp Python |

## 6. Phân công nghiên cứu

| Thành viên | Phụ trách | Reference ưu tiên |
|---|---|---|
| **Huy** | MAC và 2×2 PE Array | Matrix Multiplication Accelerator, Systolic Array |
| **Cảnh** | FSM, tiling, matrix buffer | Matrix Multiplier Verilog, Intel MIF |
| **Hoàng** | Quartus, FPGA integration, UART | Nandland UART, Cyclone IV Handbook |
| **Lê** | Testbench, Python, golden model | INT8 Systolic MatMul, NumPy, PySerial |

## 7. Thứ tự triển khai

1. **FPGA Bring-up:** Quartus project và LED Blink.
2. **MAC Unit:** Thiết kế và simulation signed INT16 MAC.
3. **PE Array:** Tích hợp 4 MAC thành 2×2 PE Array.
4. **Matrix Controller:** FSM thực hiện phép nhân 8×8.
5. **Memory:** ROM/RAM lưu A, B và C.
6. **Verification:** So sánh với Python golden model.
7. **UART:** Nhập hai ma trận từ PC, trả kết quả.
8. **FPGA Demo:** Chạy trên Cyclone IV EP4CE6.

## 8. Expected Deliverables

```text
fpga-matrix-multiplier/
├── rtl/
│   ├── mac.v
│   ├── pe_array.v
│   ├── matrix_controller.v
│   ├── matrix_memory.v
│   ├── uart_rx.v
│   ├── uart_tx.v
│   └── fpga_top.v
├── tb/
│   ├── tb_mac.v
│   ├── tb_pe_array.v
│   └── tb_matrix.v
├── scripts/
│   ├── golden_model.py
│   └── uart_test.py
├── memory/
│   ├── matrix_a.mif
│   └── matrix_b.mif
├── quartus/
└── README.md
```

## 9. Completion Criteria

- [ ] Nhân đúng hai ma trận 8×8 signed INT16.
- [ ] Hoàn thành 2×2 PE Array.
- [ ] Có FSM Controller và matrix buffers.
- [ ] Simulation PASS với các test cases.
- [ ] Nạp và chạy được trên EP4CE6.
- [ ] Nhập ma trận qua UART.
- [ ] Đọc kết quả C về Python.
- [ ] Golden model xác nhận 64/64 kết quả đúng.
- [ ] Có báo cáo LE, DSP, M9K, Fmax và latency.

**Reference chính nên nghiên cứu đầu tiên:** [GuanShiChen/matrix-multiplication-accelerator](https://github.com/GuanShiChen/matrix-multiplication-accelerator), kết hợp [Nandland UART](https://github.com/nandland/UART) và [NumPy](https://numpy.org/doc/stable/reference/generated/numpy.matmul.html).

*Ghi chú: Đây là danh sách tham khảo để nghiên cứu và điều chỉnh kiến trúc, không phải danh sách project đã được xác nhận chạy trực tiếp trên kit EP4CE6.*
