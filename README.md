# Image Histogram Equalization IP Core (FPGA)

## Overview
This project implements a high-performance hardware accelerator for **Image Histogram Equalization** using **Verilog HDL**. The system is designed to enhance the contrast of 8-bit grayscale images in real-time, supporting resolutions up to **4K (3840x2160)**.

## Key Features
- **Two-Pass Architecture**: Efficiently handles statistical accumulation and pixel remapping.
- **High Throughput**: Fully pipelined design achieving a processing rate of **1 pixel per clock cycle**.
- **AXI4 Integration**: Features **AXI4-Lite** for control registers and **AXI4-Stream** for high-speed DMA data transfer.
- **Hardware Optimization**: Uses fixed-point arithmetic and on-chip **Block RAM (BRAM)** for resource efficiency.

## Tools & Technologies
- **Language**: Verilog HDL
- **Simulation/Synthesis**: Xilinx Vivado, iVerilog, GTKWave
- **Target Hardware**: Arty-Z7 (Xilinx Zynq-7000)
  
## Verification
Validated through Vivado simulations. The design maintains timing closure and functional accuracy for various image sizes, ensuring seamless SoC integration.
