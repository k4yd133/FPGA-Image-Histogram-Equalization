module histogram_equalization_ip (
    // Clock & Reset
    input clk,
    input reset_n,
    
    // Control Signal 
    input start_equalization,
    input [31:0] T_TOTAL_PIXELS,

    // AXIS Slave Interface (Receive pixels from DMA - MM2S)
    input wire [7:0]  s_axis_tdata,
    input wire        s_axis_tvalid,
    output wire       s_axis_tready,
    input wire        s_axis_tlast,

    // AXIS Master Interface (Send pixels to DMA - S2MM)
    output wire [7:0] m_axis_tdata,
    output wire       m_axis_tvalid,
    input wire        m_axis_tready,
    output wire       m_axis_tlast 
);

// Internal Signals (WIRES)
// FSM Control Signals
wire hist_start;
wire cdf_start;
wire remap_enable;
wire [7:0] lut_k_addr;

// Data Signals
wire [7:0] pixel_in;              // Input pixel from mem_data_in for Pass 1
wire [31:0] total_pixels_out;           // Total number of pixels output from Pass 1
wire [31:0] hist_data_out;              // Histogram data output from Pass 1
wire [7:0] pixel_equalized_out;         // Equalized pixel output from Pass 2 -> mem_data_out

// Handshake Signals
wire axis_push_ok = s_axis_tvalid && s_axis_tready;


//////////////////////////////////////////////////////////////////////////////
// 1. TOP CONTROLLER FSM (top_controller_fsm.v)
top_controller_fsm fsm_inst (
    .clk(clk),
    .reset_n(reset_n),
    .start_equalization(start_equalization),
    .T_TOTAL_PIXELS(T_TOTAL_PIXELS),

    // AXIS GATES
    .axis_tvalid(s_axis_tvalid),
    .axis_tready(m_axis_tready),
    .axis_push_ok(axis_push_ok),
    .s_axis_tlast(s_axis_tlast),

    // Output
    .hist_start(hist_start),
    .cdf_start(cdf_start),
    .remap_enable(remap_enable),
    .s_axis_tready_out(s_axis_tready), // FSM decide when to receive data
    .m_axis_tvalid_out(m_axis_tvalid), // FSM inform when data is valid to send
    .m_axis_tlast_out(m_axis_tlast),   // FSM inform when it's the last pixel of the frame
    .lut_k_addr(lut_k_addr)
);


//////////////////////////////////////////////////////////////////////////////
// 2. DATA PATH & INTERFACE
// Data from external RAM is used for 2 purposes:
// a) Pass 1: Input pixels for histogram calculation
// b) Pass 2: Input pixels to LUT Core/Remapper for equalization
assign pixel_in = s_axis_tdata;
// Data out (equalized pixels) to external RAM
assign m_axis_tdata = pixel_equalized_out;


//////////////////////////////////////////////////////////////////////////////
// 3. HISTOGRAM ACCUMULATOR (histogram_accumulator.v)
histogram_accumulator hist_inst (
    .clk(clk),
    .reset_n(reset_n),
    .hist_start(hist_start && axis_push_ok), 
    .pixel_input(pixel_in), 
    .k_read_addr(lut_k_addr),     // address for histogram read
    
    // Outputs
    .total_pixels(total_pixels_out),
    .hist_data_out(hist_data_out)
);


//////////////////////////////////////////////////////////////////////////////
// 4. LUT CORE (lut_core.v)
lut_core lut_inst (
    .clk(clk),
    .reset_n(reset_n),
    .cdf_start(cdf_start),
    .remap_enable(remap_enable),

    .pixel_in_pass2(pixel_in),       // old pixel input (Pass 1) for remapping
    .hist_in(hist_data_out),         // Histogram count (Pass 1/CDF)
    .k_write_addr(lut_k_addr),       // address for histogram write
    .T_TOTAL(T_TOTAL_PIXELS),        // Total number of pixels (T)

    // Output
    .pixel_out_equalized(pixel_equalized_out)
);

endmodule