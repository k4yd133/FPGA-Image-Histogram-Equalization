module top_controller_fsm (
    input clk,
    input reset_n,
    input start_equalization,    
    input [31:0] T_TOTAL_PIXELS, 
    
    // AXI-Stream
    input  wire axis_tvalid,      // s_axis_tvalid from DMA
    input  wire axis_tready,      // m_axis_tready from DMA
    input  wire axis_push_ok,    // (s_axis_tvalid && s_axis_tready)
    input  wire s_axis_tlast,    // End signal from DMA
    
    output reg  s_axis_tready_out, // Inform DMA ready to receive data
    output wire  m_axis_tvalid_out, // Inform DMA data is valid 
    output wire  m_axis_tlast_out,  // Inform DMA end of frame

    // Internal Controll
    output reg hist_start,      
    output reg cdf_start,       
    output reg remap_enable,    
    output reg [7:0] lut_k_addr  
);

// FSM 4 States using 2-bit encoding
parameter S_IDLE        = 2'b00; // Waiting, Ready to start
parameter S_HIST_PASS1  = 2'b01; // Read file + build histogram
parameter S_CDF_LUT     = 2'b10; // Calculate CDF + LUT
parameter S_APPLY_PASS2 = 2'b11; // Read again + Remap

reg [1:0] current_state, next_state;

// Address Counters
reg [31:0] addr_counter;    // Address counter for external RAM (0 -> T_TOTAL_PIXELS - 1)
reg [7:0] lut_counter;      // Address counter for LUT (0 -> 255)

// Delayed AXI-Stream signals
reg m_axis_tvalid_delayed;
reg m_axis_tlast_delayed;


//////////////////////////////////////////////////////////////////////////////
// FSM SEQUENTIAL LOGIC (Update state and counters)
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        current_state <= S_IDLE;
        addr_counter <= 32'd0;
        lut_counter <= 8'd0;

        m_axis_tvalid_delayed <= 1'b0;
        m_axis_tlast_delayed <= 1'b0;
    end
    else begin
        current_state <= next_state;

        // addr_counter only increase when handshaking TVALID/TREADY successful
        if (current_state == S_HIST_PASS1 || current_state == S_APPLY_PASS2) begin
            if (axis_push_ok) begin
                if (addr_counter < T_TOTAL_PIXELS - 1)
                    addr_counter <= addr_counter + 1'b1;
                else
                    addr_counter <= 32'd0;
            end
        end else begin
            addr_counter <= 32'd0;
        end

        // lut_counter run from 0 to 255 in CDF_LUT state
        if (current_state == S_CDF_LUT) begin
            if (lut_counter < 8'd255)
                lut_counter <= lut_counter + 1'b1;
            else
                lut_counter <= 8'd0;
        end else begin
            lut_counter <= 8'd0;
        end
        m_axis_tvalid_delayed <= (current_state == S_APPLY_PASS2) ? axis_tvalid : 1'b0;
        m_axis_tlast_delayed  <= (current_state == S_APPLY_PASS2 && addr_counter == T_TOTAL_PIXELS - 1) ? 1'b1 : 1'b0;
    end
end


//////////////////////////////////////////////////////////////////////////////
// FSM COMBINATIONAL LOGIC (Next State Logic & Output Control)
always @(*) begin
    next_state = current_state;
    
    // Default controll signals
    hist_start = 1'b0;
    cdf_start = 1'b0;
    remap_enable = 1'b0;
    s_axis_tready_out = 1'b0;
    lut_k_addr = lut_counter;

    case (current_state)
        S_IDLE: begin
            if (start_equalization)
                next_state = S_HIST_PASS1;
        end
        
        S_HIST_PASS1: begin
            hist_start = 1'b1;
            s_axis_tready_out = 1'b1; // Always ready to receive pixel data from DMA
            // Change to next state after receiving all pixels
            if (axis_push_ok && addr_counter == T_TOTAL_PIXELS - 1)
                next_state = S_CDF_LUT;
        end
        
        S_CDF_LUT: begin
            cdf_start = 1'b1;
            if (lut_counter == 8'd255)
                next_state = S_APPLY_PASS2;
        end
        
        S_APPLY_PASS2: begin
            remap_enable = 1'b1;
            s_axis_tready_out = axis_tready; // Only receive when DMA is ready  
            // TLAST for end of frame at Pass 2
            if (axis_push_ok && addr_counter == T_TOTAL_PIXELS - 1) begin
                //m_axis_tlast_out = 1'b1;
                if (axis_push_ok)
                    next_state = S_IDLE;
            end
        end
        
        default: next_state = S_IDLE;
    endcase
end

assign m_axis_tvalid_out = m_axis_tvalid_delayed;
assign m_axis_tlast_out  = m_axis_tlast_delayed;

endmodule