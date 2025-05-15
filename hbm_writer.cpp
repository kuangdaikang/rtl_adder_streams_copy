#include <hls_stream.h>
#include <ap_axi_sdata.h>
#include <ap_int.h>
#include <ap_utils.h>

#define BURST_LEN 16
#define DATA_WIDTH 512
#define DATA_BYTES (DATA_WIDTH / 8)
#define MAX_ADDR0 0x08000000ULL
#define MAX_ADDR1 0x10000000ULL

typedef ap_axiu<DATA_WIDTH, 0, 0, 0> pkt512;

void receive_stream(
    hls::stream<pkt512>& in_stream,
    hls::stream<pkt512>& fifo_out,
    volatile ap_uint<1>* done_flag
) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1

    bool done = false;
    while (!done) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=65536
#pragma HLS PIPELINE II=1
        if (!in_stream.empty()) {
            pkt512 pkt = in_stream.read();
            fifo_out.write(pkt);
            if (pkt.last) {
                done = true;
            }
        }
    }

    *done_flag = 1;
}

void write_to_hbm(
    hls::stream<pkt512>& fifo_in,
    ap_uint<512>* gmem,
    ap_uint<64> gmem_addr0,
    ap_uint<64> gmem_addr1,
    volatile ap_uint<1>* done_flag
) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1

    ap_uint<64> addr0 = gmem_addr0;
    ap_uint<64> addr1 = gmem_addr1;
    ap_uint<64> max_addr0 = MAX_ADDR0;
    ap_uint<64> max_addr1 = MAX_ADDR1;

    bool use_bank0 = true;
    bool done = false;

    pkt512 buffer[BURST_LEN];
#pragma HLS ARRAY_PARTITION variable=buffer complete dim=1

    while (!done || !fifo_in.empty()) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=65536
#pragma HLS PIPELINE II=1

        int valid_count = 0;
        bool burst_last = false;

        // Fill burst buffer
        for (int i = 0; i < BURST_LEN; i++) {
#pragma HLS PIPELINE II=1
            if (!fifo_in.empty()) {
                pkt512 pkt = fifo_in.read();
                buffer[i] = pkt;
                valid_count++;
                if (pkt.last) {
                    burst_last = true;
                    break;
                }
            }
        }

        // Write valid data to memory
        ap_uint<64> write_addr = use_bank0 ? addr0 : addr1;

        for (int i = 0; i < BURST_LEN; i++) {
#pragma HLS UNROLL
            if (i < valid_count) {
                gmem[(write_addr / DATA_BYTES) + i] = buffer[i].data;
            }
        }

        // Advance address
        if (use_bank0) {
            addr0 += BURST_LEN * DATA_BYTES;
            if (addr0 >= max_addr0) {
                use_bank0 = false;
            }
        } else {
            addr1 += BURST_LEN * DATA_BYTES;
            if (addr1 >= max_addr1) {
                use_bank0 = true;
            }
        }

        if (burst_last) {
            done = true;
        }
    }

    *done_flag = 1;
}

extern "C" {
void hbm_writer_fifo(
    hls::stream<pkt512>& in_stream,
    ap_uint<512>* gmem,
    ap_uint<64> gmem_addr0,
    ap_uint<64> gmem_addr1,
    volatile ap_uint<1>* ap_done,
    volatile ap_uint<1>* ap_idle,
    volatile ap_uint<1>* ap_ready,
    volatile ap_uint<1>* interrupt
) {
#pragma HLS INTERFACE axis port=in_stream
#pragma HLS INTERFACE m_axi depth=65536 port=gmem offset=slave bundle=gmem max_write_burst_length=16

#pragma HLS INTERFACE s_axilite port=gmem_addr0 bundle=control
#pragma HLS INTERFACE s_axilite port=gmem_addr1 bundle=control

#pragma HLS INTERFACE s_axilite port=ap_done   bundle=control
#pragma HLS INTERFACE s_axilite port=ap_idle   bundle=control
#pragma HLS INTERFACE s_axilite port=ap_ready  bundle=control
#pragma HLS INTERFACE s_axilite port=interrupt bundle=control
#pragma HLS INTERFACE s_axilite port=return    bundle=control

#pragma HLS DATAFLOW

    *ap_idle = 0;
    *ap_ready = 1;
    *ap_done = 0;
    *interrupt = 0;

    hls::stream<pkt512> fifo("fifo");
#pragma HLS STREAM variable=fifo depth=1024

    static ap_uint<1> recv_done = 0;
    static ap_uint<1> write_done = 0;

    recv_done = 0;
    write_done = 0;

    receive_stream(in_stream, fifo, &recv_done);
    write_to_hbm(fifo, gmem, gmem_addr0, gmem_addr1, &write_done);

    // 等待两个子模块都完成
    if (recv_done && write_done) {
        *ap_done = 1;
        *ap_idle = 1;
        *interrupt = 1;
    }
}
}
