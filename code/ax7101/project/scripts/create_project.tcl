set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set project_name AX7101_DUAL_DATASET_UDP
set project_file [file join $project_root ${project_name}.xpr]

if {[llength [get_projects -quiet]] != 0} {
    close_project
}

create_project $project_name $project_root -part xc7a100tfgg484-2 -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property ip_output_repo [file join $project_root ip] [current_project]

set rtl_files [lsort [glob -nocomplain [file join $project_root src *.v]]]
if {[llength $rtl_files] == 0} {
    error "No RTL sources found under [file join $project_root src]"
}
add_files -fileset sources_1 -norecurse $rtl_files
set camera_ip_files [list \
    [file join $project_root ip camera afifo_16i_64o_512 \
        afifo_16i_64o_512.xci] \
    [file join $project_root ip camera afifo_64i_16o_128 \
        afifo_64i_16o_128.xci] \
    [file join $project_root ip camera video_pll video_pll.xci]]
foreach camera_ip $camera_ip_files {
    if {![file exists $camera_ip]} {
        error "Missing camera IP: $camera_ip"
    }
}
add_files -fileset sources_1 -norecurse $camera_ip_files
upgrade_ip -quiet [get_ips {
    afifo_16i_64o_512 afifo_64i_16o_128 video_pll
}]
generate_target all [get_ips {
    afifo_16i_64o_512 afifo_64i_16o_128 video_pll
}]
add_files -fileset constrs_1 -norecurse \
    [file join $project_root constraints ax7101_dataset.xdc]
set_property top ax7101_dataset_top [get_filesets sources_1]

set sim_files [lsort [glob -nocomplain [file join $project_root sim *.sv]]]
if {[llength $sim_files] != 0} {
    add_files -fileset sim_1 -norecurse $sim_files
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top tb_dataset_udp_loopback [get_filesets sim_1]
}

file mkdir [file join $project_root ip]

proc create_or_add_ila {project_root module_name properties} {
    set xci [file join $project_root ip $module_name ${module_name}.xci]
    if {[file exists $xci]} {
        add_files -fileset sources_1 -norecurse $xci
    } else {
        create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
            -module_name $module_name -dir [file join $project_root ip]
    }
    set_property -dict $properties [get_ips $module_name]
    generate_target all [get_ips $module_name]
}

proc create_or_add_vio {project_root module_name properties} {
    set xci [file join $project_root ip $module_name ${module_name}.xci]
    if {[file exists $xci]} {
        add_files -fileset sources_1 -norecurse $xci
    } else {
        create_ip -name vio -vendor xilinx.com -library ip -version 3.0 \
            -module_name $module_name -dir [file join $project_root ip]
    }
    set_property -dict $properties [get_ips $module_name]
    generate_target all [get_ips $module_name]
}

set ila_common [list \
    CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_EN_STRG_QUAL {0} \
    CONFIG.C_ADV_TRIGGER {false}]

create_or_add_ila $project_root ila_dataset_rx [concat $ila_common [list \
    CONFIG.C_NUM_OF_PROBES {20} \
    CONFIG.C_PROBE0_WIDTH {2} \
    CONFIG.C_PROBE1_WIDTH {32} \
    CONFIG.C_PROBE2_WIDTH {32} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE6_WIDTH {32} \
    CONFIG.C_PROBE7_WIDTH {32} \
    CONFIG.C_PROBE8_WIDTH {32} \
    CONFIG.C_PROBE9_WIDTH {32} \
    CONFIG.C_PROBE10_WIDTH {32} \
    CONFIG.C_PROBE11_WIDTH {32} \
    CONFIG.C_PROBE12_WIDTH {32} \
    CONFIG.C_PROBE13_WIDTH {32} \
    CONFIG.C_PROBE14_WIDTH {32} \
    CONFIG.C_PROBE15_WIDTH {32} \
    CONFIG.C_PROBE16_WIDTH {32} \
    CONFIG.C_PROBE17_WIDTH {32} \
    CONFIG.C_PROBE18_WIDTH {32} \
    CONFIG.C_PROBE19_WIDTH {192}]]

create_or_add_ila $project_root ila_dataset_tx [concat $ila_common [list \
    CONFIG.C_NUM_OF_PROBES {8} \
    CONFIG.C_PROBE0_WIDTH {2} \
    CONFIG.C_PROBE1_WIDTH {32} \
    CONFIG.C_PROBE2_WIDTH {32} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE6_WIDTH {32} \
    CONFIG.C_PROBE7_WIDTH {4}]]

create_or_add_ila $project_root ila_dataset_mem [concat $ila_common [list \
    CONFIG.C_NUM_OF_PROBES {6} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {2} \
    CONFIG.C_PROBE2_WIDTH {32} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32}]]

create_or_add_ila $project_root ila_camera [concat $ila_common [list \
    CONFIG.C_NUM_OF_PROBES {24} \
    CONFIG.C_PROBE0_WIDTH {2} \
    CONFIG.C_PROBE1_WIDTH {32} \
    CONFIG.C_PROBE2_WIDTH {32} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE6_WIDTH {32} \
    CONFIG.C_PROBE7_WIDTH {32} \
    CONFIG.C_PROBE8_WIDTH {32} \
    CONFIG.C_PROBE9_WIDTH {32} \
    CONFIG.C_PROBE10_WIDTH {32} \
    CONFIG.C_PROBE11_WIDTH {32} \
    CONFIG.C_PROBE12_WIDTH {32} \
    CONFIG.C_PROBE13_WIDTH {32} \
    CONFIG.C_PROBE14_WIDTH {32} \
    CONFIG.C_PROBE15_WIDTH {32} \
    CONFIG.C_PROBE16_WIDTH {32} \
    CONFIG.C_PROBE17_WIDTH {32} \
    CONFIG.C_PROBE18_WIDTH {32} \
    CONFIG.C_PROBE19_WIDTH {192} \
    CONFIG.C_PROBE20_WIDTH {32} \
    CONFIG.C_PROBE21_WIDTH {32} \
    CONFIG.C_PROBE22_WIDTH {32} \
    CONFIG.C_PROBE23_WIDTH {32}]]

create_or_add_vio $project_root vio_port4_mode [list \
    CONFIG.C_NUM_PROBE_IN {2} \
    CONFIG.C_NUM_PROBE_OUT {1} \
    CONFIG.C_PROBE_IN0_WIDTH {1} \
    CONFIG.C_PROBE_IN1_WIDTH {32} \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x0}]

source [file join $script_dir create_memory_subsystem.tcl]

set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "PROJECT_FILE=$project_file"
puts "TOP=ax7101_dataset_top"
puts "PART=[get_property PART [current_project]]"
close_project
