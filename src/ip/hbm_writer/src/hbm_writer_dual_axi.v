`default_nettype none
`timescale 1 ns / 1 ps 

module hbm_writer_dual_axi #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 64,
    parameter BURST_LEN  = 16,
    parameter [63:0] MAX_ADDR0 = 64'h0800_0000,   // 128MB
    parameter [63:0] MAX_ADDR1 = 64'h1000_0000    // 256MB

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

    // AXI Master interface
    output reg [ADDR_WIDTH-1:0] m_axi_gmem_AWADDR,
    output reg [7:0]            m_axi_gmem_AWLEN,
    output reg                  m_axi_gmem_AWVALID,
    input  wire                 m_axi_gmem_AWREADY,

    output reg [DATA_WIDTH-1:0] m_axi_gmem_WDATA,
    output reg                  m_axi_gmem_WVALID,
    output reg                  m_axi_gmem_WLAST,
    input  wire                 m_axi_gmem_WREADY,
    input  wire                 m_axi_gmem_BVALID,
    output reg                  m_axi_gmem_BREADY

);

    localparam IDLE        = 2'b00;
    localparam WRITE       = 2'b01;
    localparam WAIT_BRESP  = 2'b10;

    reg state;
    reg [$clog2(BURST_LEN):0] write_cnt;
    reg is_bank0;

    // FSM for bank 0 and bank 1
    always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        state <= IDLE;
        m_axi_gmem_AWVALID <= 0;
        m_axi_gmem_AWADDR  <= 0;
        m_axi_gmem_AWLEN   <= 0;
        m_axi_gmem_WVALID  <= 0;
        m_axi_gmem_WDATA   <= 0;
        m_axi_gmem_WLAST   <= 0;
        m_axi_gmem_BREADY  <= 0;
        current_addr0      <= 0;
        current_addr1      <= 64'h0800_0000;
        write_cnt          <= 0;
        write0_done        <= 0;
        write1_done        <= 0;
        bank0_full         <= 0;
        bank1_full         <= 0;
        is_bank0           <= 1;
    end else begin
        m_axi_gmem_WVALID <= 0;
        m_axi_gmem_WLAST  <= 0;
        m_axi_gmem_BREADY <= 0;  // 默认不拉高

        case (state)
            IDLE: begin
                if (bank0_wr_en) begin
                    is_bank0 <= 1;
                    m_axi_gmem_AWADDR  <= start_addr0;
                    m_axi_gmem_AWLEN   <= BURST_LEN - 1;
                    m_axi_gmem_AWVALID <= 1;
                    write_cnt          <= 0;
                    state              <= WRITE;
                    write0_done        <= 0;
                end else if (bank1_wr_en) begin
                    is_bank0 <= 0;
                    m_axi_gmem_AWADDR  <= start_addr1;
                    m_axi_gmem_AWLEN   <= BURST_LEN - 1;
                    m_axi_gmem_AWVALID <= 1;
                    write_cnt          <= 0;
                    state              <= WRITE;
                    write1_done        <= 0;
                end
            end

            WRITE: begin
                if (m_axi_gmem_AWVALID && m_axi_gmem_AWREADY)
                    m_axi_gmem_AWVALID <= 0;

                if (m_axi_gmem_WREADY) begin
                    m_axi_gmem_WVALID <= 1;
                    m_axi_gmem_WLAST  <= (write_cnt == BURST_LEN - 1);
                    m_axi_gmem_WDATA  <= write_data;

                    write_cnt <= write_cnt + 1;

                    if (write_cnt == BURST_LEN - 1) begin
                        state <= WAIT_BRESP;  // 写完数据后等待写响应
                    end
                end
            end

            WAIT_BRESP: begin
                if (m_axi_gmem_BVALID) begin
                    m_axi_gmem_BREADY <= 1;  // 拉高 BREADY 一拍

                    // 更新地址和状态
                    if (is_bank0) begin
                        current_addr0  <= start_addr0 + BURST_LEN * (DATA_WIDTH/8);
                        write0_done    <= 1;
                        bank0_full     <= (start_addr0 + 2*BURST_LEN*(DATA_WIDTH/8) >= MAX_ADDR0);
                    end else begin
                        current_addr1  <= start_addr1 + BURST_LEN * (DATA_WIDTH/8);
                        write1_done    <= 1;
                        bank1_full     <= (start_addr1 + 2*BURST_LEN*(DATA_WIDTH/8) >= MAX_ADDR1);
                    end

                    state <= IDLE;
                end
            end
        endcase
    end
end


endmodule
