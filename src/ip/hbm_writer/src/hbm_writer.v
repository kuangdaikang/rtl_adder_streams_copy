`default_nettype none
`timescale 1 ns / 1 ps

module hbm_writer #(
    parameter C_M_AXI_GMEM_DATA_WIDTH = 32,
    parameter C_M_AXI_GMEM_ADDR_WIDTH = 64
)(
    // Clock and Reset
    (* X_INTERFACE_PARAMETER = "FREQ_HZ=300000000, ASSOCIATED_BUSIF=p0:m_axi_gmem:s_axi_control, ASSOCIATED_RESET=ap_rst_n" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ap_clk CLK" *)
    input  wire ap_clk,

    (* X_INTERFACE_PARAMETER = "POLARITY=ACTIVE_LOW" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 ap_rst_n RST" *)
    input  wire ap_rst_n,

    // AXI-Lite Control Interface (ap_ctrl_hs)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control AWADDR" *)
    input  wire [31:0] s_axi_control_AWADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control AWVALID" *)
    input  wire        s_axi_control_AWVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control AWREADY" *)
    output wire        s_axi_control_AWREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control WDATA" *)
    input  wire [31:0] s_axi_control_WDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control WSTRB" *)
    input  wire [3:0]  s_axi_control_WSTRB,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control WVALID" *)
    input  wire        s_axi_control_WVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control WREADY" *)
    output wire        s_axi_control_WREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control BRESP" *)
    output wire [1:0]  s_axi_control_BRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control BVALID" *)
    output wire        s_axi_control_BVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control BREADY" *)
    input  wire        s_axi_control_BREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control ARADDR" *)
    input  wire [31:0] s_axi_control_ARADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control ARVALID" *)
    input  wire        s_axi_control_ARVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control ARREADY" *)
    output wire        s_axi_control_ARREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control RDATA" *)
    output wire [31:0] s_axi_control_RDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control RRESP" *)
    output wire [1:0]  s_axi_control_RRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control RVALID" *)
    output wire        s_axi_control_RVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control RREADY" *)
    input  wire        s_axi_control_RREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_control" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME=s_axi_control, PROTOCOL=AXI4LITE, DATA_WIDTH=32, ADDR_WIDTH=32, HAS_BURST=0, HAS_LOCK=0, HAS_PROT=1, HAS_CACHE=0, HAS_QOS=0, HAS_REGION=0, HAS_WSTRB=1, HAS_BRESP=1, HAS_RRESP=1" *)

    // ap_ctrl_hs control signals
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 control ap_start" *)
    input  wire ap_start,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 control ap_done" *)
    output wire ap_done,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 control ap_idle" *)
    output wire ap_idle,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 control ap_ready" *)
    output wire ap_ready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:acc_handshake:1.0 control interrupt" *)
    output wire interrupt,


    // AXI Stream Input
    (* X_INTERFACE_PARAMETER = "FREQ_HZ=300000000, ASSOCIATED_CLOCK=ap_clk" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 p0 TDATA" *)
    input  wire [C_M_AXI_GMEM_DATA_WIDTH-1:0]  p0_TDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 p0 TVALID" *)
    input  wire                                p0_TVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 p0 TREADY" *)
    output wire                                p0_TREADY,

    // AXI Master Interface for HBM
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem AWADDR" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_axi_gmem, ASSOCIATED_CONTROL=s_axi_control, DATA_WIDTH=512, PROTOCOL=AXI4, FREQ_HZ=300000000, ID_WIDTH=0, ADDR_WIDTH=64, HAS_BURST=1, HAS_LOCK=0, HAS_PROT=0, HAS_CACHE=0, HAS_QOS=0, HAS_REGION=0, HAS_WSTRB=1, HAS_BRESP=1, HAS_RRESP=1, SUPPORTS_NARROW_BURST=0" *)
    output wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0]  m_axi_gmem_AWADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem AWVALID" *)
    output wire                                m_axi_gmem_AWVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem AWREADY" *)
    input  wire                                m_axi_gmem_AWREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem WDATA" *)
    output wire [C_M_AXI_GMEM_DATA_WIDTH-1:0]  m_axi_gmem_WDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem WVALID" *)
    output wire                                m_axi_gmem_WVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem WREADY" *)
    input  wire                                m_axi_gmem_WREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem WLAST" *)
    output wire                                m_axi_gmem_WLAST,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem AWLEN" *)
    output wire [7:0]                           m_axi_gmem_AWLEN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem BVALID" *)
    input  wire                                 m_axi_gmem_BVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem BREADY" *)
    output wire                                 m_axi_gmem_BREADY,
    //axi 读通道
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem ARADDR" *)
    output wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0] m_axi_gmem_ARADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem ARVALID" *)
    output wire                              m_axi_gmem_ARVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem ARREADY" *)
    input  wire                              m_axi_gmem_ARREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem RDATA" *)
    input  wire [C_M_AXI_GMEM_DATA_WIDTH-1:0] m_axi_gmem_RDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem RVALID" *)
    input  wire                              m_axi_gmem_RVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem RREADY" *)
    output wire                              m_axi_gmem_RREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem RLAST" *)
    input  wire                              m_axi_gmem_RLAST,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axi_gmem ARLEN" *)
    output wire [7:0]                        m_axi_gmem_ARLEN
);

    assign m_axi_gmem_ARADDR  = 64'd0;
    assign m_axi_gmem_ARVALID = 1'b0;
    assign m_axi_gmem_ARLEN   = 8'd0;
    assign m_axi_gmem_RREADY  = 1'b0;


    // 控制状态机：ap_ctrl_hs 实现
    reg ap_done_reg = 1'b0;
    reg ap_idle_reg = 1'b1;
    reg ap_ready_reg = 1'b0;

    assign ap_done  = ap_done_reg;
    assign ap_idle  = ap_idle_reg;
    assign ap_ready = ap_ready_reg;

    parameter S_IDLE = 2'b00;
    parameter S_RUN  = 2'b01;
    parameter S_DONE = 2'b10;

    reg [1:0] state;

    wire write0_done, write1_done;

    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            state <= S_IDLE;
            ap_done_reg  <= 1'b0;
            ap_idle_reg  <= 1'b1;
            ap_ready_reg <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    ap_done_reg  <= 1'b0;
                    ap_ready_reg <= 1'b0;
                    ap_idle_reg  <= 1'b1;
                    if (ap_start) begin
                        state <= S_RUN;
                        ap_idle_reg <= 1'b0;
                    end
                end
                S_RUN: begin            //现在的想法是writer核只要启动了就一直run,done state不知道是否有用，先保留
                    ap_ready_reg <= 1'b1; // 表示 kernel 已准备好
                    ap_done_reg  <= 1'b0;
                    ap_idle_reg  <= 1'b0;

                end
                S_DONE: begin
                    if (!ap_start) begin
                        state <= S_RUN;
                        ap_done_reg  <= 1'b0;
                        ap_ready_reg <= 1'b1;
                        ap_idle_reg  <= 1'b0;
                    end
                end
            endcase
        end
    end

    // 地址管理
    reg [C_M_AXI_GMEM_ADDR_WIDTH-1:0] saved_addr0;
    reg [C_M_AXI_GMEM_ADDR_WIDTH-1:0] saved_addr1;
    wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0] current_addr0;
    wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0] current_addr1;

    wire bank0_full, bank1_full;

    wire write_to_bank0 = ~bank0_full;
    wire write_to_bank1 = bank0_full && ~bank1_full;

    assign p0_TREADY = (state == S_RUN) && (write_to_bank0 || write_to_bank1);
    wire bank_wr_en = p0_TVALID & p0_TREADY;

    assign interrupt = ~p0_TREADY;
            

    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            saved_addr0 <= 0;
            saved_addr1 <= 64'h0800_0000;
        end else begin
            if (write0_done)
                saved_addr0 <= current_addr0;
            if (write1_done)
                saved_addr1 <= current_addr1;
        end
    end


    //后面可能用得上
    wire [63:0] gmem_addr;
    wire [31:0] gmem_size;

    // 子模块实例化
    hbm_writer_dual_axi #(
        .DATA_WIDTH(C_M_AXI_GMEM_DATA_WIDTH),
        .ADDR_WIDTH(C_M_AXI_GMEM_ADDR_WIDTH),
        .BURST_LEN(16),
        .MAX_ADDR0(64'h0800_0000),
        .MAX_ADDR1(64'h1000_0000)
    ) writer_inst (
        .ap_clk(ap_clk),
        .ap_rst_n(ap_rst_n),

        .write_data(p0_TDATA),
        .bank0_wr_en(bank_wr_en && write_to_bank0),
        .bank1_wr_en(bank_wr_en && write_to_bank1),
        .start_addr0(saved_addr0),
        .start_addr1(saved_addr1),

        .bank0_full(bank0_full),
        .bank1_full(bank1_full),
        .current_addr0(current_addr0),
        .current_addr1(current_addr1),
        .write0_done(write0_done),
        .write1_done(write1_done),

        .m_axi_gmem_AWADDR(m_axi_gmem_AWADDR),
        .m_axi_gmem_AWVALID(m_axi_gmem_AWVALID),
        .m_axi_gmem_AWREADY(m_axi_gmem_AWREADY),
        .m_axi_gmem_WDATA(m_axi_gmem_WDATA),
        .m_axi_gmem_WVALID(m_axi_gmem_WVALID),
        .m_axi_gmem_WREADY(m_axi_gmem_WREADY),
        .m_axi_gmem_WLAST(m_axi_gmem_WLAST),
        .m_axi_gmem_AWLEN(m_axi_gmem_AWLEN),
        .m_axi_gmem_BVALID(m_axi_gmem_BVALID),
        .m_axi_gmem_BREADY(m_axi_gmem_BREADY)

        // .interrupt(interrupt)
    );

    hbm_writer_control_s_axi control_inst (
    .ACLK(ap_clk),
    .ARESET(~ap_rst_n),
    .ACLK_EN(1'b1),

    .AWADDR(s_axi_control_AWADDR[5:0]),
    .AWVALID(s_axi_control_AWVALID),
    .AWREADY(s_axi_control_AWREADY),
    .WDATA(s_axi_control_WDATA),
    .WSTRB(s_axi_control_WSTRB),
    .WVALID(s_axi_control_WVALID),
    .WREADY(s_axi_control_WREADY),
    .BRESP(s_axi_control_BRESP),
    .BVALID(s_axi_control_BVALID),
    .BREADY(s_axi_control_BREADY),

    .ARADDR(s_axi_control_ARADDR[5:0]),
    .ARVALID(s_axi_control_ARVALID),
    .ARREADY(s_axi_control_ARREADY),
    .RDATA(s_axi_control_RDATA),
    .RRESP(s_axi_control_RRESP),
    .RVALID(s_axi_control_RVALID),
    .RREADY(s_axi_control_RREADY),

    .ap_start(ap_start),
    .ap_done(ap_done),
    .ap_idle(ap_idle),
    .ap_ready(ap_ready),
    .interrupt(interrupt),
    .gmem_addr(gmem_addr),
    .gmem_size(gmem_size)
    );


endmodule
