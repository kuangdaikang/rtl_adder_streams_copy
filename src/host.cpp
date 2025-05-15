#include "xcl2.hpp"
#include <vector>
#include <iostream>
#include <cstdlib>
#include <thread>
#include <chrono>
#include <fstream>

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
    bool valid_device = false;
    for (unsigned int i = 0; i < devices.size(); i++) {
        auto device = devices[i];
        OCL_CHECK(err, context = cl::Context(device, nullptr, nullptr, nullptr, &err));
        OCL_CHECK(err, q = cl::CommandQueue(context, device,
                                            CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE | CL_QUEUE_PROFILING_ENABLE, &err));

        std::cout << "Trying to program device[" << i << "]: " << device.getInfo<CL_DEVICE_NAME>() << std::endl;
        program = cl::Program(context, {device}, bins, nullptr, &err);
        if (err != CL_SUCCESS) {
            std::cout << "Failed to program device[" << i << "] with xclbin file!\n";
        } else {
            std::cout << "Device[" << i << "]: program successful!\n";
            valid_device = true;
            break; // we break because we found a valid device
        }
    }
    if (!valid_device) {
        std::cout << "Failed to program any device found, exit!\n";
        exit(EXIT_FAILURE);
    }
    // 创建内核
    OCL_CHECK(err, cl::Kernel krnl_adder_stage(program, "krnl_adder_stage_rtl", &err));
    OCL_CHECK(err, cl::Kernel krnl_input_stage(program, "krnl_input_stage_rtl", &err));
    OCL_CHECK(err, cl::Kernel krnl_hbm_writer(program, "hbm_writer", &err));

    // 创建输入缓冲区
    cl_mem_ext_ptr_t in_ext;
    in_ext.obj = source_input.data();
    in_ext.param = 0;
    in_ext.flags = XCL_MEM_TOPOLOGY | 2;  //  HBM[2]

    OCL_CHECK(err,cl::Buffer buffer_input(context,
        CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX,
        vector_size_bytes,
        &in_ext,
        &err));


    // 创建输出缓冲区（HBM）用于 hbm_writer 写入
    cl_mem_ext_ptr_t out_ext;
    out_ext.obj = source_hw_results.data();
    out_ext.param = 0;
    out_ext.flags = XCL_MEM_TOPOLOGY | 0;  // 0 表示 HBM[0]

    OCL_CHECK(err, cl::Buffer buffer_output(context,
                            CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY | CL_MEM_EXT_PTR_XILINX,
                            vector_size_bytes,
                            &out_ext,
                            &err));




    // 设置 krnl_input_stage_rtl 参数
    OCL_CHECK(err,krnl_input_stage.setArg(0, buffer_input)); 
    OCL_CHECK(err,krnl_input_stage.setArg(1, DATA_SIZE));

    // 设置 krnl_adder_stage_rtl 参数
    OCL_CHECK(err,krnl_adder_stage.setArg(0, INCR_VALUE));
    OCL_CHECK(err,krnl_adder_stage.setArg(1, DATA_SIZE)); 

    // 设置 hbm_writer 参数
    uint32_t size = static_cast<uint32_t>(DATA_SIZE);
    OCL_CHECK(err, err = krnl_hbm_writer.setArg(0, buffer_output));      // gmem_addr
    OCL_CHECK(err, err = krnl_hbm_writer.setArg(1, size));        // gmem_size

    // 数据迁移 input buffer 到 device
    cl::Event write_event;
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_input}, 0 /* 0 means from host*/, nullptr, &write_event));


    // 启动内核（按顺序）
    std::vector<cl::Event> eventVec;
    eventVec.push_back(write_event);
    OCL_CHECK(err, err = q.enqueueTask(krnl_input_stage, &eventVec));
    OCL_CHECK(err, err = q.enqueueTask(krnl_adder_stage, &eventVec));
    OCL_CHECK(err, err = q.enqueueTask(krnl_hbm_writer, &eventVec));

    // 轮询中断状态
    /*while (true) {
        uint32_t interrupt = read_interrupt_status(q, ctrl_buf);
        int count = 0;

        if (interrupt & 0x1) {
            std::cout << "[HOST] Interrupt detected! Pausing input and adder..." << std::endl;

            // 等待中断清除
            while (interrupt & 0x1) {
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
                if (++count > 100) {
                    std::cout << "[HOST] Timeout waiting for interrupt to clear." << std::endl;
                    break;
                }
                interrupt = read_interrupt_status(q, ctrl_buf);
            }

            if (count <= 100) {
                std::cout << "[HOST] Interrupt cleared. Restarting input and adder..." << std::endl;
                q.enqueueTask(krnl_input_stage);
                q.enqueueTask(krnl_adder_stage);
            } else {
                std::cout << "[HOST] Timeout occurred. Exiting..." << std::endl;
                break;
            }
        }
    }*/
    OCL_CHECK(err, err = q.finish());

    // 从 HBM 读取数据回主机
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_output}, CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q.finish());

    // 验证结果
    int match = 0;
    for (int i = 0; i < DATA_SIZE; i++) {
        if (source_hw_results[i] != source_sw_results[i]) {
            std::cout << "Error: Result mismatch" << std::endl;
            std::cout << "i = " << i << " CPU result = " << source_sw_results[i]
                      << " Device result = " << source_hw_results[i] << std::endl;
            match = 1;
            break;
        }
    }

    std::cout << "TEST " << (match ? "FAILED" : "PASSED") << std::endl;
    return (match ? EXIT_FAILURE : EXIT_SUCCESS);
}