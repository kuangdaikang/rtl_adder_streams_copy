# Copyright (C) 2019-2021 Xilinx, Inc
# Licensed under the Apache License, Version 2.0

if { $::argc != 5 } {
    puts "ERROR: Program \"$::argv0\" requires 4 arguments!\n"
    puts "Usage: $::argv0 <xoname> <krnl_name> <target> <xpfm_path> <device>\n"
    exit
}

# 获取参数
set xo_pathname  [lindex $::argv 0]
set krnl_name    [lindex $::argv 1]
set target       [lindex $::argv 2]
set xpfm_path    [lindex $::argv 3]
set device       [lindex $::argv 4]

# 设置路径
set ip_dir "./src/ip/${krnl_name}"
file mkdir "${ip_dir}/xgui"
set prj_dir "./_x/${krnl_name}_prj"

# 创建临时 Vivado 工程
create_project -force ${krnl_name}_prj ${prj_dir} -part xcvu37p-fsvh2892-2L-e
add_files "${ip_dir}/src/hbm_writer.v"
add_files "${ip_dir}/src/hbm_writer_dual_axi.v"
add_files "${ip_dir}/src/hbm_writer_control_s_axi.v"

set_property top ${krnl_name} [current_fileset]

# IP 打包
ipx::package_project -root_dir ${ip_dir} -vendor xilinx.com -library user -taxonomy /KernelIP -set_current true

# 设置 control 接口为 ap_ctrl_hs
set ctrl_intf [ipx::get_bus_interfaces control -of_objects [ipx::current_core]]
set_property interface_mode master $ctrl_intf
set_property abstraction_type_vlnv xilinx.com:interface:acc_handshake_rtl:1.0 $ctrl_intf
set_property bus_type_vlnv xilinx.com:interface:acc_handshake:1.0 $ctrl_intf


set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
puts "KERNEL_TYPE: [get_property sdx_kernel_type [ipx::current_core]]"
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]

# 删除旧的 XO 文件
if {[file exists "${krnl_name}.xo"]} {
    file delete -force "${krnl_name}.xo"
}

# 打包 XO 文件
package_xo -xo_path "${krnl_name}.xo" \
           -kernel_name ${krnl_name} \
           -ip_directory ${ip_dir} \
           -ctrl_protocol ap_ctrl_hs
# 拷贝到目标路径
set xo_path [file join [pwd] ${xo_pathname}]
if {[file exists "${krnl_name}.xo"]} {
    file copy -force "${krnl_name}.xo" ${xo_path}
} else {
    puts "ERROR: ${krnl_name}.xo does not exist!\n"
    exit 1
}
