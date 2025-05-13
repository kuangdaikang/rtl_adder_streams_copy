`default_nettype none
`timescale 1 ns / 1 ps

module hbm_writer_control_s_axi (
    input  wire        ACLK,
    input  wire        ARESET,
    input  wire        ACLK_EN,

    // AXI Write Address Channel
    input  wire [5:0]  AWADDR,
    input  wire        AWVALID,
    output wire        AWREADY,

    // AXI Write Data Channel
    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output wire        WREADY,

    // AXI Write Response Channel
    output wire [1:0]  BRESP,
    output wire        BVALID,
    input  wire        BREADY,

    // AXI Read Address Channel
    input  wire [5:0]  ARADDR,
    input  wire        ARVALID,
    output wire        ARREADY,

    // AXI Read Data Channel
    output wire [31:0] RDATA,
    output wire [1:0]  RRESP,
    output wire        RVALID,
    input  wire        RREADY,

    // Control Signals
    output reg         ap_start,
    input  wire        ap_done,
    input  wire        ap_idle,
    input  wire        ap_ready,
    input  wire        interrupt,

    output reg [63:0] gmem_addr,
    output reg [31:0] gmem_size

);

    // AXI Write FSM
    reg awready_reg, wready_reg, bvalid_reg;
    reg [1:0] bresp_reg;
    reg [5:0] awaddr_reg;

    assign AWREADY = awready_reg;
    assign WREADY  = wready_reg;
    assign BRESP   = bresp_reg;
    assign BVALID  = bvalid_reg;

    // AXI Read FSM
    reg arready_reg, rvalid_reg;
    reg [31:0] rdata_reg;
    reg [1:0]  rresp_reg;
    reg [5:0]  araddr_reg;

    assign ARREADY = arready_reg;
    assign RVALID  = rvalid_reg;
    assign RDATA   = rdata_reg;
    assign RRESP   = rresp_reg;

    // Internal registers
    reg ap_start_reg;

    always @(posedge ACLK or posedge ARESET) begin
        if (ARESET) begin
            awready_reg <= 1'b0;
            wready_reg  <= 1'b0;
            bvalid_reg  <= 1'b0;
            bresp_reg   <= 2'b00;
            awaddr_reg  <= 6'd0;
            ap_start    <= 1'b0;
            gmem_addr   <= 64'd0;
            gmem_size   <= 32'd0;
        end else if (ACLK_EN) begin
            // Write Address
            if (!awready_reg && AWVALID) begin
                awready_reg <= 1'b1;
                awaddr_reg  <= AWADDR;
            end else begin
                awready_reg <= 1'b0;
            end

            // Write Data
            if (!wready_reg && WVALID) begin
                wready_reg <= 1'b1;
            end else begin
                wready_reg <= 1'b0;
            end

            // Write Response
            if (awready_reg && wready_reg && !bvalid_reg) begin
                bvalid_reg <= 1'b1;
                bresp_reg  <= 2'b00;

                // Decode register write
                case (awaddr_reg)
                    6'h00: if (WSTRB[0]) ap_start <= WDATA[0];
                    6'h10: gmem_addr[31:0]  <= WDATA;
                    6'h14: gmem_addr[63:32] <= WDATA;
                    6'h18: gmem_size        <= WDATA;
                endcase
            end else if (BREADY && bvalid_reg) begin
                bvalid_reg <= 1'b0;
            end
        end
    end

    // Clear ap_start when ap_done is asserted
    always @(posedge ACLK or posedge ARESET) begin
        if (ARESET) begin
            ap_start <= 1'b0;
        end else if (ACLK_EN) begin
            if (ap_done)
                ap_start <= 1'b0;
        end
    end

    // Read FSM
    always @(posedge ACLK or posedge ARESET) begin
        if (ARESET) begin
            arready_reg <= 1'b0;
            rvalid_reg  <= 1'b0;
            rdata_reg   <= 32'd0;
            rresp_reg   <= 2'b00;
            araddr_reg  <= 6'd0;
        end else if (ACLK_EN) begin
            // Accept read address
            if (!arready_reg && ARVALID) begin
                arready_reg <= 1'b1;
                araddr_reg  <= ARADDR;
            end else begin
                arready_reg <= 1'b0;
            end

            // Output read data
            if (arready_reg && !rvalid_reg) begin
                rvalid_reg <= 1'b1;
                case (araddr_reg)
                    6'h00: rdata_reg <= {28'd0, ap_ready, ap_idle, ap_done, ap_start};
                    6'h04: rdata_reg <= {31'd0, interrupt};
                    6'h10: rdata_reg <= gmem_addr[31:0];
                    6'h14: rdata_reg <= gmem_addr[63:32];
                    6'h18: rdata_reg <= gmem_size;
                    default: rdata_reg <= 32'd0;
                endcase
            end else if (rvalid_reg && RREADY) begin
                rvalid_reg <= 1'b0;
            end
        end
    end

endmodule
