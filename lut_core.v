module lut_core (
    input wire clk,
    input wire reset_n,
    input wire cdf_start,              
    input wire remap_enable,          
    input wire [7:0]  pixel_in_pass2,   // Pixel data from S_AXIS_TDATA
    input wire [31:0] hist_in,          // From Histogram Accumulator
    input wire [7:0]  k_write_addr,     // Address k from FSM (0-255)
    input wire [31:0] T_TOTAL,          // Total number of pixels (T)

    // Output
    output wire [7:0] pixel_out_equalized 
);

// LUT BRAM SIMULATION
(* ram_style = "block" *) reg [7:0] lut [0:255]; 
reg [31:0] cdf_reg; 
reg [7:0] remap_output_reg; 

parameter L_MINUS_1 = 8'd255;
parameter NUM_BITS = 40; // Extension bits for precision


//////////////////////////////////////////////////////////////////////////////
// FIXED-POINT CALCULATION
wire [NUM_BITS-1:0] current_cdf_value_ext; 
wire [NUM_BITS-1:0] numerator_comb; 
wire [NUM_BITS-1:0] rounding_factor; 
wire [NUM_BITS-1:0] rounded_numerator;
wire [39:0] new_value_div;

// 1. Calculate CDF[k] (cumulative sum) - using bit extension
assign current_cdf_value_ext = {8'd0, cdf_reg} + {8'd0, hist_in}; 

// 2. Calculate numerator: CDF[k] * (L-1)
assign numerator_comb = current_cdf_value_ext * L_MINUS_1; 

// 3. Rounding factor: T / 2
assign rounding_factor = T_TOTAL >> 1;

// 4. Rounded numerator: A + (T / 2)
assign rounded_numerator = numerator_comb + rounding_factor;

// 5. Final new value: rounded_numerator / T
assign new_value_div = (T_TOTAL > 32'd0) ? (rounded_numerator / T_TOTAL) : 8'd0;


//////////////////////////////////////////////////////////////////////////////
// SEQUENTIAL LOGIC
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        cdf_reg <= 32'd0;
        remap_output_reg <= 8'd0;
    end
    else begin
        // S_CDF_LUT
        if (cdf_start) begin
            cdf_reg <= current_cdf_value_ext[31:0];
            
            // Write RAM LUT
            if (new_value_div > 40'd255) begin
                lut[k_write_addr] <= 8'd255;
            end else begin
                lut[k_write_addr] <= new_value_div[7:0]; 
            end
        end
        
        // S_APPLY_PASS2 
        else if (remap_enable) begin
            // Read from BRAM LUT 
            remap_output_reg <= lut[pixel_in_pass2];
            cdf_reg <= 32'd0; // Reset CDF for next frame
        end
    end
end

assign pixel_out_equalized = remap_output_reg;

endmodule