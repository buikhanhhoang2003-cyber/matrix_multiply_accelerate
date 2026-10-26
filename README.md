# RISC-V TinyML Accelerator trên FPGA Cyclone IV

**Đề tài:** Thiết kế bộ tăng tốc nhân ma trận và triển khai mô hình TinyML trên FPGA Cyclone IV EP4CE6 sử dụng RISC-V.

## 1. Tổng quan

Đề tài bắt đầu từ việc **thiết kế bộ nhân hai ma trận 8×8 với phần tử signed 16-bit trên FPGA**, sau đó phát triển thành bộ tăng tốc phần cứng (Hardware Accelerator) phục vụ suy luận AI (inference).

Hệ thống sử dụng RISC-V làm bộ xử lý điều khiển và PE/MAC Array để tăng tốc các phép toán nhân ma trận, hướng đến chạy mô hình neural network nhỏ trực tiếp trên FPGA.

**Mục tiêu cuối cùng:** Chạy thành công một mô hình TinyML trên Cyclone IV EP4CE6 và đánh giá hiệu năng so với thực thi bằng phần mềm RISC-V.

## 2. Nền tảng phần cứng

| Thành phần | Cấu hình |
|---|---|
| FPGA | Intel Cyclone IV EP4CE6 |
| Logic Elements | 6,272 |
| Embedded Multipliers 18×18 | 15 |
| Embedded RAM | 270 Kbit |
| CPU | PicoRV32 (RV32I) |
| Ngôn ngữ | Verilog, C, Python |
| Công cụ | Quartus II, ModelSim, RISC-V GCC |

Do tài nguyên FPGA hạn chế, thiết kế ưu tiên **2×2 PE Array (4 MAC)** và tái sử dụng phần cứng thay vì triển khai 64 PE song song.

## 3. Lộ trình phát triển đề tài

### Giai đoạn 1 — Matrix Multiplication Accelerator

Thiết kế bộ nhân hai ma trận 8×8:

- Dữ liệu đầu vào: signed INT16.
- Accumulator: signed 35-bit.
- Thiết kế MAC và PE Array.
- Triển khai nhân ma trận theo phương pháp tiling.
- Tối ưu data reuse, DSP và latency.
- Kiểm tra kết quả bằng Python golden model.

**Kết quả:** Bộ nhân ma trận 8×8 INT16 hoạt động chính xác trên FPGA.

### Giai đoạn 2 — Tích hợp RISC-V SoC

Tích hợp PicoRV32 với Matrix Accelerator thông qua memory-mapped interface.

RISC-V chịu trách nhiệm:

- Cấu hình accelerator.
- Nạp dữ liệu đầu vào.
- Khởi động phép tính.
- Đọc kết quả và kiểm tra trạng thái.

**Kết quả:** Chương trình C trên RISC-V có thể điều khiển bộ nhân ma trận bằng phần cứng.

### Giai đoạn 3 — Phát triển TinyML Accelerator

Mở rộng bộ nhân ma trận để hỗ trợ các phép toán neural network:

| Matrix Accelerator | TinyML Accelerator |
|---|---|
| INT16 MAC | INT8 MAC |
| 35-bit accumulator | INT32 accumulator |
| Matrix multiplication | Fully Connected Layer |
| Matrix buffer | Weight/Activation buffer |
| MAC | MAC + Bias + ReLU + Requantization |

Giữ lại chức năng nhân ma trận INT16 để benchmark. Phần INT8 được phát triển theo hướng tái sử dụng kiến trúc PE, controller và memory buffer.

**Kết quả:** Accelerator hỗ trợ tính toán các lớp Fully Connected của neural network.

### Giai đoạn 4 — Port mô hình AI lên FPGA

**Model đề xuất:** MLP phân loại chữ số viết tay sử dụng scikit-learn Digits 8×8.

Kiến trúc:

`Input (64) → FC (16) → ReLU → FC (10) → Argmax`

| Thông số | Giá trị |
|---|---:|
| Input | 8×8 grayscale |
| Hidden neurons | 16 |
| Output classes | 10 |
| Weights | 1,184 |
| MAC / inference | 1,184 |
| Weight precision | INT8 |

Quy trình triển khai:

1. Train model bằng Python/PyTorch trên PC.
2. Quantize model từ FP32 sang INT8.
3. Export weights, bias và quantization parameters.
4. Nạp model vào BRAM của FPGA.
5. RISC-V điều khiển accelerator thực hiện FC1 và FC2.
6. Đọc kết quả, phân loại chữ số và xuất qua UART.
7. So sánh với kết quả inference trên PC.

**Kết quả:** Chạy inference mô hình MLP thực tế trên EP4CE6.

## 4. Kiến trúc hệ thống

```text
              +------------------+
              | RISC-V PicoRV32  |
              |   C Firmware     |
              +--------+---------+
                       |
              Memory-Mapped Bus
                       |
         +-------------+-------------+
         |                           |
  +------+------+             +------+------+
  | Program BRAM |             | Accelerator |
  +-------------+              | Controller  |
                               +------+------+
                                      |
                         +------------+-----------+
                         |                        |
                   +-----+------+           +-----+------+
                   | Weight /   |           | 2x2 PE/MAC |
                   | Input BRAM  |---------->| INT8/INT16 |
                   +------------+           +-----+------+
                                                  |
                                          +-------+-------+
                                          | Accumulator   |
                                          | Bias / ReLU   |
                                          | Requantize    |
                                          +-------+-------+
                                                  |
                                           Output Buffer
                                                  |
                                            RISC-V / UART
```

## 5. Đánh giá hiệu năng

So sánh các cấu hình:

| Cấu hình | Mục đích |
|---|---|
| RISC-V Software | Baseline |
| 1 MAC | Tiết kiệm tài nguyên |
| 2 MAC | Tăng song song |
| 2×2 PE Array | Accelerator chính |
| INT8 MLP | Inference thực tế |

Các chỉ số cần đánh giá:

- **Correctness:** Kết quả RTL so với Python golden model.
- **Accuracy:** Độ chính xác phân loại sau quantization.
- **Latency:** Số chu kỳ cho một lần inference.
- **Throughput:** Số inference/giây.
- **DSP/LE/BRAM:** Tài nguyên FPGA sử dụng.
- **Speedup:** Tốc độ so với phần mềm RISC-V.
- **Fmax:** Tần số tối đa sau place-and-route.

## 6. Kết quả mong đợi

- Bộ nhân ma trận 8×8 INT16 hoàn chỉnh.
- PE/MAC Array tối ưu cho Cyclone IV EP4CE6.
- RISC-V SoC điều khiển accelerator.
- Bộ tăng tốc Fully Connected INT8.
- Mô hình MLP được quantize và chạy inference trên FPGA.
- Báo cáo so sánh hiệu năng, tài nguyên và độ chính xác.

**Lưu ý:** Khả năng tích hợp toàn bộ CPU, firmware và accelerator trên EP4CE6 cần được xác nhận bằng synthesis và timing analysis. Nếu vượt tài nguyên, giảm số MAC xuống 1–2 nhưng vẫn giữ mục tiêu inference.

## 7. References — Dự án tham khảo

### 7.1. RISC-V Processor

**PicoRV32 — Size-Optimized RISC-V CPU**

https://github.com/YosysHQ/picorv32

- RISC-V softcore viết bằng Verilog.
- Hỗ trợ cấu hình RV32I tối giản.
- Có ví dụ SoC, firmware và memory interface.
- Tham khảo để tích hợp CPU và accelerator.

*Lưu ý: Repository đã được archive, hiện ở trạng thái read-only.*

### 7.2. FPGA Matrix / AI Accelerator

**FPGA AI Inference Accelerator — INT8 Systolic Array**

https://github.com/taitashaw/fpga-ai-accelerator

- Thiết kế systolic array 8×8 INT8 bằng SystemVerilog.
- Có tiling engine và memory banking.
- Hỗ trợ ReLU và requantization.
- Có RTL, testbench và verification scripts.

**Ứng dụng:** Tham khảo thiết kế PE/MAC, dataflow và quantization. Cần thu nhỏ kiến trúc cho EP4CE6; dự án gốc hướng đến Artix-7.

### 7.3. Configurable Neural Network Accelerator

**SARA — Self-Adaptive Reconfigurable Systolic AI Accelerator**

https://github.com/GokulR2003/sara-accelerator

- Nghiên cứu MAC có thể thay đổi độ chính xác.
- Hỗ trợ các chế độ W8A8, W4A8 và W4A4 theo thiết kế.
- Sử dụng output-stationary dataflow.
- Hướng đến TinyML và tối ưu tài nguyên.

**Ứng dụng:** Tham khảo cách thiết kế MAC/PE tái cấu hình và tối ưu precision. Dự án đang trong giai đoạn phát triển, chưa phải giải pháp hoàn chỉnh cho EP4CE6.

### 7.4. TinyML Dataset

**Scikit-learn Digits Dataset**

https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html

- 1,797 ảnh chữ số viết tay.
- Kích thước ảnh 8×8.
- 10 lớp phân loại.
- Phù hợp huấn luyện và kiểm thử MLP nhỏ.

### 7.5. RISC-V Firmware Development

**Running Your Own Programs on PicoRV32**

https://kaniyeri.github.io/2023/08/10/running-picorv32/

- Hướng dẫn chạy chương trình trên PicoRV32.
- Tham khảo quy trình biên dịch và nạp firmware.
- Hữu ích khi xây dựng RISC-V SoC ban đầu.

---

## 8. Kết luận

Đề tài được phát triển theo hướng:

**Matrix Multiplication INT16 → PE/MAC Array → RISC-V SoC → INT8 TinyML Accelerator → AI Model Inference**

Điểm nhấn của đề tài là **Hardware/Software Co-design và Resource Optimization**, chứng minh khả năng triển khai mô hình AI nhỏ trên FPGA có tài nguyên hạn chế như Cyclone IV EP4CE6.
