`default_nettype none
`timescale 1 ns / 1 ps 

module hbm_writer_dual_axi #(
    parameter DATA_WIDTH = 512,
    parameter ADDR_WIDTH = 64,
    parameter BURST_LEN  = 16,
    parameter [63:0] MAX_ADDR0 = 64'h1_0000_0000, // 4GB
    parameter [63:0] MAX_ADDR1 = 64'h2_0000_0000  // 8GB

)(
    input wire ap_clk,
    input wire ap_rst_n,

    /*
    // FIFO0 interface
    input wire [DATA_WIDTH-1:0] fifo0_data,
    input wire fifo0_empty,
    output reg fifo0_rd_en,

    // FIFO1 interface
    input wire [DATA_WIDTH-1:0] fifo1_data,
    input wire fifo1_empty,
    output reg fifo1_rd_en,

    */
    input wire [DATA_WIDTH-1:0] write_data,
    input wire bank0_wr_en,
    input wire bank1_wr_en,
    input wire [ADDR_WIDTH-1:0] start_addr0,
    input wire [ADDR_WIDTH-1:0] start_addr1,

    output reg bank0_full,
    output reg bank1_full,
    output reg [ADDR_WIDTH-1:0] current_addr0,
    output reg [ADDR_WIDTH-1:0] current_addr1,
    output reg write0_done,
    output reg write1_done,

    // AXI Master 0 interface
    output reg [ADDR_WIDTH-1:0] m_axi_gmem0_AWADDR,
    output reg [7:0]            m_axi_gmem0_AWLEN,
    output reg                  m_axi_gmem0_AWVALID,
    input  wire                 m_axi_gmem0_AWREADY,

    output reg [DATA_WIDTH-1:0] m_axi_gmem0_WDATA,
    output reg                  m_axi_gmem0_WVALID,
    output reg                  m_axi_gmem0_WLAST,
    input  wire                 m_axi_gmem0_WREADY,

    // AXI Master 1 interface
    output reg [ADDR_WIDTH-1:0] m_axi_gmem1_AWADDR,
    output reg [7:0]            m_axi_gmem1_AWLEN,
    output reg                  m_axi_gmem1_AWVALID,
    input  wire                 m_axi_gmem1_AWREADY,

    output reg [DATA_WIDTH-1:0] m_axi_gmem1_WDATA,
    output reg                  m_axi_gmem1_WVALID,
    output reg                  m_axi_gmem1_WLAST,
    input  wire                 m_axi_gmem1_WREADY

);

    localparam IDLE  = 1'b0;
    localparam WRITE = 1'b1;

    reg state0, state1;
    reg [$clog2(BURST_LEN):0] write_cnt0, write_cnt1;

    // FSM for bank 0
    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            state0 <= IDLE;
            m_axi_gmem0_AWVALID <= 0;
            m_axi_gmem0_AWADDR  <= 0;
            m_axi_gmem0_AWLEN   <= 0;
            m_axi_gmem0_WVALID  <= 0;
            m_axi_gmem0_WDATA   <= 0;
            m_axi_gmem0_WLAST   <= 0;
            // fifo0_rd_en         <= 0;
            current_addr0       <= 0;
            write_cnt0          <= 0;
            write0_done     <= 0;
            bank0_full          <= 0;
        end else begin
            // fifo0_rd_en         <= 0;
            m_axi_gmem0_WVALID  <= 0;
            m_axi_gmem0_WLAST   <= 0;

            case (state0)
                IDLE: begin
                    if (bank0_wr_en) begin
                        m_axi_gmem0_AWADDR  <= start_addr0;
                        m_axi_gmem0_AWLEN   <= BURST_LEN - 1;
                        m_axi_gmem0_AWVALID <= 1;
                        write_cnt0          <= 0;
                        state0              <= WRITE;
                        write0_done     <= 0;
                    end
                end
                WRITE: begin
                    if (m_axi_gmem0_AWVALID && m_axi_gmem0_AWREADY)
                        m_axi_gmem0_AWVALID <= 0;

                    if (m_axi_gmem0_WREADY) begin
                        m_axi_gmem0_WVALID <= 1;
                        m_axi_gmem0_WDATA  <= write_data;
                        // fifo0_rd_en        <= 1;

                        if (write_cnt0 == BURST_LEN - 1) begin
                            m_axi_gmem0_WLAST <= 1;
                            current_addr0     <= start_addr0 + BURST_LEN * (DATA_WIDTH/8);
                            write0_done     <= 1;
                            if (start_addr0+2*BURST_LEN * (DATA_WIDTH/8) >= MAX_ADDR0) begin
                                bank0_full <= 1;
                            end else begin
                                bank0_full <= 0;
                            end
                            state0            <= IDLE;
                        end
                        write_cnt0 <= write_cnt0 + 1;
                    end
                end
            endcase
        end
    end

    // FSM for bank 1
    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            state1 <= IDLE;
            m_axi_gmem1_AWVALID <= 0;
            m_axi_gmem1_AWADDR  <= 0;
            m_axi_gmem1_AWLEN   <= 0;
            m_axi_gmem1_WVALID  <= 0;
            m_axi_gmem1_WDATA   <= 0;
            m_axi_gmem1_WLAST   <= 0;
            // fifo1_rd_en         <= 0;
            current_addr1       <= 32'h0100_0000;
            write1_done     <= 0;
            bank1_full          <= 0;
            write_cnt1          <= 0;
        end else begin
            // fifo1_rd_en         <= 0;
            m_axi_gmem1_WVALID  <= 0;
            m_axi_gmem1_WLAST   <= 0;

            case (state1)
                IDLE: begin
                    if (bank1_wr_en) begin
                        m_axi_gmem1_AWADDR  <= start_addr1;
                        m_axi_gmem1_AWLEN   <= BURST_LEN - 1;
                        m_axi_gmem1_AWVALID <= 1;
                        write_cnt1          <= 0;
                        state1              <= WRITE;
                        write1_done     <= 0;
                    end
                end
                WRITE: begin
                    if (m_axi_gmem1_AWVALID && m_axi_gmem1_AWREADY)
                        m_axi_gmem1_AWVALID <= 0;

                    if (m_axi_gmem1_WREADY) begin
                        m_axi_gmem1_WVALID <= 1;
                        m_axi_gmem1_WDATA  <= write_data;
                        // fifo1_rd_en        <= 1;

                        if (write_cnt1 == BURST_LEN - 1) begin
                            m_axi_gmem1_WLAST <= 1;
                            current_addr1     <= start_addr1 + BURST_LEN * (DATA_WIDTH/8);
                            write1_done     <= 1;
                            if (start_addr1+2*BURST_LEN * (DATA_WIDTH/8) >= MAX_ADDR1) begin
                                bank1_full <= 1;
                            end else begin
                                bank1_full <= 0;
                            end
                            state1            <= IDLE;
                        end
                        write_cnt1 <= write_cnt1 + 1;
                    end
                end
            endcase
        end
    end

endmodule
