module histogram_equalization_axi_wrapper # (
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)(
    // AXI-Lite Clock & Reset
    input  wire  S_AXI_ACLK,
    input  wire  S_AXI_ARESETN,

    // AXI4-Lite Slave Interface (Control) 
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input  wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input  wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output reg   S_AXI_BVALID,
    input  wire  S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input  wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input  wire  S_AXI_RREADY,

    // AXI4-Stream Slave Interface (Input Pixel from DMA MM2S) 
    input  wire [7:0]  S_AXIS_TDATA,
    input  wire        S_AXIS_TVALID,
    output wire        S_AXIS_TREADY,
    input  wire        S_AXIS_TLAST,

    // AXI4-Stream Master Interface (Output Pixel to DMA S2MM) 
    output wire [7:0]  M_AXIS_TDATA,
    output wire        M_AXIS_TVALID,
    input  wire        M_AXIS_TREADY,
    output wire        M_AXIS_TLAST
);

    // Controll Registers (AXI-Lite)
    reg [31:0] slv_reg0; // reg0[0]: Start pulse
    reg [31:0] slv_reg1; // reg1: T_TOTAL_PIXELS (VD: 262144 for 512x512)

    // Internal handshake signals
    wire start_pulse = slv_reg0[0];
    wire [31:0] t_total = slv_reg1;

    //  Simple logic for AXI-Lite 
    assign S_AXI_AWREADY = 1'b1;
    assign S_AXI_WREADY  = 1'b1;
    assign S_AXI_BRESP   = 2'b00;
    assign S_AXI_ARREADY = 1'b1;
    assign S_AXI_RVALID  = 1'b0; 
    assign S_AXI_RDATA   = 32'h0;

    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            S_AXI_BVALID <= 1'b0;
            slv_reg0 <= 0;
            slv_reg1 <= 0;
        end else begin
            // Register Logic
            if (S_AXI_AWVALID && S_AXI_WVALID && !S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b1;
                case (S_AXI_AWADDR[3:2])
                    2'h0: slv_reg0 <= S_AXI_WDATA;
                    2'h1: slv_reg1 <= S_AXI_WDATA;
                endcase
            end else begin
                if (S_AXI_BREADY && S_AXI_BVALID) S_AXI_BVALID <= 1'b0;
                // Auto-clear start bit after one clock cycle
                if (slv_reg0[0]) slv_reg0[0] <= 1'b0;
            end
        end
    end

    // Connect Main Module (Core)
    histogram_equalization_ip core_inst (
        .clk(S_AXI_ACLK),
        .reset_n(S_AXI_ARESETN),
        .start_equalization(start_pulse),
        .T_TOTAL_PIXELS(t_total),

        // Streaming Data
        .s_axis_tdata(S_AXIS_TDATA),
        .s_axis_tvalid(S_AXIS_TVALID),
        .s_axis_tready(S_AXIS_TREADY),
        .s_axis_tlast(S_AXIS_TLAST),

        .m_axis_tdata(M_AXIS_TDATA),
        .m_axis_tvalid(M_AXIS_TVALID),
        .m_axis_tready(M_AXIS_TREADY),
        .m_axis_tlast(M_AXIS_TLAST)
    );

endmodule