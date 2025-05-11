#include "xcl2.hpp"
#include <vector>
#include <iostream>
#include <cstdlib>

#define DATA_SIZE 4096
#define INCR_VALUE 10

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cout << "Usage: " << argv[0] << " <XCLBIN File>" << std::endl;
        return EXIT_FAILURE;
    }

    std::string binaryFile = argv[1];
    size_t vector_size_bytes = sizeof(int) * DATA_SIZE;

    // 初始化主机数据
    std::vector<int, aligned_allocator<int>> source_input(DATA_SIZE);
    std::vector<int, aligned_allocator<int>> source_hw_results(DATA_SIZE);
    std::vector<int, aligned_allocator<int>> source_sw_results(DATA_SIZE);

    for (int i = 0; i < DATA_SIZE; i++) {
        source_input[i] = i;
        source_sw_results[i] = i + INCR_VALUE;
        source_hw_results[i] = 0;
    }

    // 获取设备
    cl_int err;
    cl::Context context;
    cl::CommandQueue q;
    cl::Program program;
    auto devices = xcl::get_xil_devices();
    auto fileBuf = xcl::read_binary_file(binaryFile);
    cl::Program::Binaries bins{{fileBuf.data(), fileBuf.size()}};

    for (unsigned int i = 0; i < devices.size(); i++) {
        auto device = devices[i];
        context = cl::Context(device, nullptr, nullptr, nullptr, &err);
        q = cl::CommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &err);
        program = cl::Program(context, {device}, bins, nullptr, &err);
        if (err == CL_SUCCESS) break;
    }

    // 创建内核
    cl::Kernel krnl_input_stage(program, "krnl_input_stage_rtl", &err);
    cl::Kernel krnl_adder_stage(program, "krnl_adder_stage_rtl", &err);
    cl::Kernel krnl_hbm_writer(program, "hbm_writer", &err);

    // 创建输入缓冲区（DDR）
    cl::Buffer buffer_input(context,
                            CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
                            vector_size_bytes,
                            source_input.data(),
                            &err);

    // 创建输出缓冲区（HBM）用于 hbm_writer 写入
    cl_mem_ext_ptr_t out_ext;
    out_ext.obj = nullptr;
    out_ext.param = 0;
    out_ext.flags = 0 | XCL_MEM_TOPOLOGY;  // HBM[0]

    cl::Buffer buffer_output(context,
                             CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,
                             vector_size_bytes,
                             &out_ext,
                             &err);

    // 设置内核参数
    int size = DATA_SIZE;
    int inc = INCR_VALUE;

    // input_stage args: input buffer, size
    krnl_input_stage.setArg(0, buffer_input);
    krnl_input_stage.setArg(1, size);

    // adder_stage args: increment, size
    krnl_adder_stage.setArg(0, inc);
    krnl_adder_stage.setArg(1, size);


    // 数据迁移 input buffer 到 device
    std::vector<cl::Memory> inBufVec = {buffer_input};
    q.enqueueMigrateMemObjects(inBufVec, 0 /* 0 means host to device */);

    // 启动内核（按顺序）
    q.enqueueTask(krnl_input_stage);
    q.enqueueTask(krnl_adder_stage);
    q.enqueueTask(krnl_hbm_writer);
    q.finish();

    // 从 HBM 读取数据回主机
    std::vector<cl::Memory> outBufVec = {buffer_output};
    q.enqueueMigrateMemObjects(outBufVec, CL_MIGRATE_MEM_OBJECT_HOST);
    q.finish();

    // 验证结果
    bool match = true;
    for (int i = 0; i < DATA_SIZE; i++) {
        if (source_hw_results[i] != source_sw_results[i]) {
            std::cout << "Error: Result mismatch at index " << i
                      << ", expected " << source_sw_results[i]
                      << ", got " << source_hw_results[i] << std::endl;
            match = false;
            break;
        }
    }

    std::cout << (match ? "TEST PASSED" : "TEST FAILED") << std::endl;
    return match ? EXIT_SUCCESS : EXIT_FAILURE;
}
