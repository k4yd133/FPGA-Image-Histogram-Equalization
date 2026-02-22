module histogram_accumulator (
    input clk,
    input reset_n,
    input hist_start,         
    input [7:0] pixel_input,  // Pixel value
    input [7:0] k_read_addr,  // Sequential read address - lut_k_addr
    
    // Outputs
    output [31:0] total_pixels,  // Total number of pixels counted (T)
    output reg [31:0] hist_data_out // Histogram data read sequentially (used for CDF)
);

// BRAM SIMULATION
reg [31:0] hist [0:255]; 
reg [31:0] total_pixels_reg; // accumulating the count of total pixels

integer i; // For initialization

// ==========================================================
// LOGIC BLOCK - Include 3 parts:
// 1. Reset/Initialization
// 2. Write Port - Pass 1
// 3. Read Port - Pass 1 (used for CDF)
// ==========================================================
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        // 1. Reset/Khởi tạo Histogram về 0 khi reset
        for (i=0; i<256; i=i+1) begin
            hist[i] <= 32'd0;
        end
        total_pixels_reg <= 32'd0;
        hist_data_out <= 32'd0;
    end
    else begin
        // 2. Write Port - Pass 1
        if (hist_start) begin
            hist[pixel_input] <= hist[pixel_input] + 32'd1; 
            total_pixels_reg <= total_pixels_reg + 32'd1;
        end

        // 3. Read Port - Pass 1 (used for CDF)
        // Active after hist_start has finished
        // When FSM is in S_CDF_LUT state, lut_k_addr is used to read histogram data sequentially
        if (!hist_start) begin // Only read when not in Pass 1 (to avoid conflicts)
            hist_data_out <= hist[k_read_addr];
        end
    end
end

assign total_pixels = total_pixels_reg;

endmodule