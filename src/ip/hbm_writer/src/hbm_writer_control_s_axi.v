`timescale 1ns/1ps
`default_nettype none

module hbm_writer_control_s_axi #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32
)(
    input  wire                   ACLK,
    input  wire                   ARESET,
    input  wire                   ACLK_EN,

    // Write address channel
    input  wire [ADDR_WIDTH-1:0]  AWADDR,
    input  wire                   AWVALID,
    output wire                   AWREADY,

    // Write data channel
    input  wire [DATA_WIDTH-1:0]  WDATA,
    input  wire [DATA_WIDTH/8-1:0] WSTRB,
    input  wire                   WVALID,
    output wire                   WREADY,

    // Write response channel
    output wire [1:0]             BRESP,
    output wire                   BVALID,
    input  wire                   BREADY,

    // Read address channel
    input  wire [ADDR_WIDTH-1:0]  ARADDR,
    input  wire                   ARVALID,
    output wire                   ARREADY,

    // Read data channel
    output wire [DATA_WIDTH-1:0]  RDATA,
    output wire [1:0]             RRESP,
    output wire                   RVALID,
    input  wire                   RREADY,

    // User logic control
    output wire                   ap_start,
    input  wire                   ap_done,
    input  wire                   ap_idle,
    input  wire                   ap_ready,
    output wire                   interrupt
);

    // 地址定义
    localparam ADDR_AP_CTRL = 6'h00;
    localparam ADDR_GIE     = 6'h04;
    localparam ADDR_IER     = 6'h08;
    localparam ADDR_ISR     = 6'h0C;

    // 状态机状态
    localparam WRIDLE = 2'd0, WRDATA = 2'd1, WRRESP = 2'd2;
    localparam RDIDLE = 2'd0, RDDATA = 2'd1;

    // 写通道信号
    reg [1:0] wstate, wnext;
    reg [ADDR_WIDTH-1:0] waddr;
    wire [DATA_WIDTH-1:0] wmask;
    wire aw_hs = AWVALID & AWREADY;
    wire w_hs  = WVALID & WREADY;

    // 读通道信号
    reg [1:0] rstate, rnext;
    reg [DATA_WIDTH-1:0] rdata;
    wire ar_hs = ARVALID & ARREADY;
    wire [ADDR_WIDTH-1:0] raddr = ARADDR;

    // 寄存器
    reg int_ap_start = 0;
    reg int_ap_done = 0;
    reg int_gie = 0;
    reg [1:0] int_ier = 0;
    reg [1:0] int_isr = 0;

    assign ap_start = int_ap_start;
    assign interrupt = int_gie & (|int_isr);

    // 写状态机
    assign AWREADY = (wstate == WRIDLE);
    assign WREADY  = (wstate == WRDATA);
    assign BRESP   = 2'b00;
    assign BVALID  = (wstate == WRRESP);
    assign wmask   = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} };

    always @(posedge ACLK) begin
        if (ARESET)
            wstate <= WRIDLE;
        else if (ACLK_EN)
            wstate <= wnext;
    end

    always @(*) begin
        case (wstate)
            WRIDLE: wnext = AWVALID ? WRDATA : WRIDLE;
            WRDATA: wnext = WVALID  ? WRRESP : WRDATA;
            WRRESP: wnext = BREADY  ? WRIDLE : WRRESP;
            default: wnext = WRIDLE;
        endcase
    end

    always @(posedge ACLK) begin
        if (ACLK_EN && aw_hs)
            waddr <= AWADDR;
    end

    // 读状态机
    assign ARREADY = (rstate == RDIDLE);
    assign RDATA   = rdata;
    assign RRESP   = 2'b00;
    assign RVALID  = (rstate == RDDATA);

    always @(posedge ACLK) begin
        if (ARESET)
            rstate <= RDIDLE;
        else if (ACLK_EN)
            rstate <= rnext;
    end

    always @(*) begin
        case (rstate)
            RDIDLE: rnext = ARVALID ? RDDATA : RDIDLE;
            RDDATA: rnext = RREADY  ? RDIDLE : RDDATA;
            default: rnext = RDIDLE;
        endcase
    end

    always @(posedge ACLK) begin
        if (ACLK_EN && ar_hs) begin
            case (raddr)
                ADDR_AP_CTRL: rdata <= {24'd0, 4'd0, ap_ready, ap_idle, int_ap_done, int_ap_start};
                ADDR_GIE    : rdata <= {31'd0, int_gie};
                ADDR_IER    : rdata <= {30'd0, int_ier};
                ADDR_ISR    : rdata <= {30'd0, int_isr};
                default     : rdata <= 0;
            endcase
        end
    end

    // ap_start 控制
    always @(posedge ACLK) begin
        if (ARESET)
            int_ap_start <= 0;
        else if (ACLK_EN) begin
            if (w_hs && waddr == ADDR_AP_CTRL && WSTRB[0])
                int_ap_start <= WDATA[0];
            else if (ap_ready)
                int_ap_start <= 0;
        end
    end

    // ap_done 清除
    always @(posedge ACLK) begin
        if (ARESET)
            int_ap_done <= 0;
        else if (ACLK_EN) begin
            if (ap_done)
                int_ap_done <= 1;
            else if (ar_hs && raddr == ADDR_AP_CTRL)
                int_ap_done <= 0;
        end
    end

    // GIE
    always @(posedge ACLK) begin
        if (ARESET)
            int_gie <= 0;
        else if (ACLK_EN && w_hs && waddr == ADDR_GIE && WSTRB[0])
            int_gie <= WDATA[0];
    end

    // IER
    always @(posedge ACLK) begin
        if (ARESET)
            int_ier <= 0;
        else if (ACLK_EN && w_hs && waddr == ADDR_IER && WSTRB[0])
            int_ier <= WDATA[1:0];
    end

    // ISR[0] - ap_done
    always @(posedge ACLK) begin
        if (ARESET)
            int_isr[0] <= 0;
        else if (ACLK_EN) begin
            if (int_ier[0] & ap_done)
                int_isr[0] <= 1;
            else if (w_hs && waddr == ADDR_ISR && WSTRB[0])
                int_isr[0] <= int_isr[0] ^ WDATA[0];
        end
    end

    // ISR[1] - ap_ready
    always @(posedge ACLK) begin
        if (ARESET)
            int_isr[1] <= 0;
        else if (ACLK_EN) begin
            if (int_ier[1] & ap_ready)
                int_isr[1] <= 1;
            else if (w_hs && waddr == ADDR_ISR && WSTRB[0])
                int_isr[1] <= int_isr[1] ^ WDATA[1];
        end
    end

endmodule

`default_nettype wire
