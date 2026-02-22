`timescale 1ns / 1ps

module tb_histogram_equalization();
    parameter CLK_PERIOD = 8; 
    parameter T_TOTAL = 262144; // Change according to image size (e.g., 512x512 = 262144)
    
    reg clk;
    reg reset_n;
    
    // AXI-Lite
    reg [3:0]  s_axi_awaddr;
    reg        s_axi_awvalid;
    wire       s_axi_awready;
    reg [31:0] s_axi_wdata;
    reg        s_axi_wvalid;
    wire       s_axi_wready;
    wire [1:0] s_axi_bresp;
    wire       s_axi_bvalid;
    reg        s_axi_bready;

    // AXI-Stream Slave
    reg [7:0]  s_axis_tdata;
    reg        s_axis_tvalid;
    wire       s_axis_tready;
    reg        s_axis_tlast;

    // AXI-Stream Master
    wire [7:0] m_axis_tdata;
    wire       m_axis_tvalid;
    reg        m_axis_tready;
    wire       m_axis_tlast;

    reg [7:0] image_mem [0:T_TOTAL-1];
    integer i, out_file;

    histogram_equalization_axi_wrapper dut (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(reset_n),
        .S_AXI_AWADDR(s_axi_awaddr), .S_AXI_AWVALID(s_axi_awvalid), .S_AXI_AWREADY(s_axi_awready),
        .S_AXI_WDATA(s_axi_wdata), .S_AXI_WVALID(s_axi_wvalid), .S_AXI_WREADY(s_axi_wready),
        .S_AXI_BRESP(s_axi_bresp), .S_AXI_BVALID(s_axi_bvalid), .S_AXI_BREADY(s_axi_bready),
        .S_AXI_ARADDR(4'd0), .S_AXI_ARVALID(1'b0), .S_AXI_RREADY(1'b1),
        .S_AXIS_TDATA(s_axis_tdata), .S_AXIS_TVALID(s_axis_tvalid), .S_AXIS_TREADY(s_axis_tready), .S_AXIS_TLAST(s_axis_tlast),
        .M_AXIS_TDATA(m_axis_tdata), .M_AXIS_TVALID(m_axis_tvalid), .M_AXIS_TREADY(m_axis_tready), .M_AXIS_TLAST(m_axis_tlast)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        // Initialize
        clk = 0; reset_n = 0;
        s_axi_awaddr = 0; s_axi_awvalid = 0; s_axi_wdata = 0; s_axi_wvalid = 0; s_axi_bready = 1;
        s_axis_tdata = 0; s_axis_tvalid = 0; s_axis_tlast = 0; m_axis_tready = 1;

        //if (!$readmemh("image_data.mem", image_mem)) begin
            //$display("ERROR: Cannot find image_data.mem");
        //end
        $readmemh("image_data.mem", image_mem);
        out_file = $fopen("output_image.txt", "w");

        repeat(20) @(posedge clk);
        reset_n = 1;
        repeat(10) @(posedge clk);

        // Write T_TOTAL (slv_reg1)
        @(posedge clk);
        s_axi_awaddr = 4'h4; s_axi_awvalid = 1;
        s_axi_wdata = T_TOTAL; s_axi_wvalid = 1;
        // Check bvalid
        while (!s_axi_bvalid) @(posedge clk); 
        s_axi_awvalid = 0; s_axi_wvalid = 0;
        repeat(5) @(posedge clk);
        
        // Signal Start (slv_reg0)
        s_axi_awaddr = 4'h0; s_axi_awvalid = 1;
        s_axi_wdata = 32'h1; s_axi_wvalid = 1;
        while (!s_axi_bvalid) @(posedge clk);
        s_axi_awvalid = 0; s_axi_wvalid = 0;
        repeat(5) @(posedge clk);

        $display("START signal sent, beginning PASS 1...");

        // PASS 1
        for (i = 0; i < T_TOTAL; i = i + 1) begin
            s_axis_tvalid = 1;
            s_axis_tdata  = image_mem[i];
            s_axis_tlast  = (i == T_TOTAL - 1);
    
            // Wait for successful handshake
            while (!s_axis_tready) @(posedge clk); 
            @(posedge clk); 
        end
        // Delete after loop
        s_axis_tvalid = 0;
        s_axis_tdata  = 8'h0;
        s_axis_tlast  = 0;

        $display("PASS 1 finished at %t", $time);
        // Wait for internal processing (CDF calculation)
        $display("PASS 1 finished, waiting for CDF...");
        repeat(400) @(posedge clk);

        // PASS 2
        $display("Beginning PASS 2...");
        for (i = 0; i < T_TOTAL; i = i + 1) begin
            s_axis_tvalid = 1;
            s_axis_tdata = image_mem[i];
            s_axis_tlast = (i == T_TOTAL - 1);
            while (!s_axis_tready) @(posedge clk);
            @(posedge clk);
        end
        s_axis_tvalid = 0; s_axis_tlast = 0;

        repeat(100) @(posedge clk);
        $fclose(out_file);
        $display("Simulation Finished!");
        $finish;
    end

    always @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            $fwrite(out_file, "%h\n", m_axis_tdata);
        end
    end

endmodule