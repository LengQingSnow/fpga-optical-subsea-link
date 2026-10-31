set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set mig_prj [file join $project_root ip ddr3 mig_b.prj]

if {![file exists $mig_prj]} {
    error "Missing board-verified MIG configuration: $mig_prj"
}

set existing_bd [get_files -quiet */memory_subsystem.bd]
if {[llength $existing_bd] != 0} {
    remove_files $existing_bd
    file delete -force [file dirname $existing_bd]
}
set generated_bd_dir [file join $project_root \
    [get_property NAME [current_project]].gen sources_1 bd memory_subsystem]
if {[file exists $generated_bd_dir]} {
    file delete -force $generated_bd_dir
}

create_bd_design memory_subsystem

create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 ddr3
set_property -dict [list \
    CONFIG.BOARD_MIG_PARAM {Custom} \
    CONFIG.MIG_DONT_TOUCH_PARAM {Custom} \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.XML_INPUT_FILE $mig_prj \
] [get_bd_cells ddr3]

create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag_axi
set_property -dict [list \
    CONFIG.PROTOCOL {0} \
    CONFIG.M_AXI_ADDR_WIDTH {32} \
    CONFIG.M_AXI_DATA_WIDTH {64} \
    CONFIG.M_AXI_ID_WIDTH {1} \
    CONFIG.M_HAS_BURST {1} \
    CONFIG.RD_TXN_QUEUE_LENGTH {1} \
    CONFIG.WR_TXN_QUEUE_LENGTH {1} \
] [get_bd_cells jtag_axi]

create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 mem_sc
set_property -dict [list \
    CONFIG.NUM_SI {3} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_CLKS {1} \
    CONFIG.HAS_ARESETN {1} \
] [get_bd_cells mem_sc]

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 reset_not
set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
] [get_bd_cells reset_not]

connect_bd_intf_net [get_bd_intf_pins jtag_axi/M_AXI] \
                    [get_bd_intf_pins mem_sc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins mem_sc/M00_AXI] \
                    [get_bd_intf_pins ddr3/S_AXI]

set scheduler_port [create_bd_intf_port -mode Slave \
    -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_SCHED]
set_property -dict [list \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {64} \
    CONFIG.ID_WIDTH {1} \
    CONFIG.HAS_BURST {1} \
    CONFIG.HAS_LOCK {1} \
    CONFIG.HAS_CACHE {1} \
    CONFIG.HAS_PROT {1} \
    CONFIG.HAS_QOS {1} \
] $scheduler_port
connect_bd_intf_net $scheduler_port [get_bd_intf_pins mem_sc/S01_AXI]

set camera_port [create_bd_intf_port -mode Slave \
    -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_CAMERA]
set_property -dict [list \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {64} \
    CONFIG.ID_WIDTH {1} \
    CONFIG.HAS_BURST {1} \
    CONFIG.HAS_LOCK {1} \
    CONFIG.HAS_CACHE {1} \
    CONFIG.HAS_PROT {1} \
    CONFIG.HAS_QOS {1} \
] $camera_port
connect_bd_intf_net $camera_port [get_bd_intf_pins mem_sc/S02_AXI]

connect_bd_net [get_bd_pins ddr3/ui_clk] \
    [get_bd_pins jtag_axi/aclk] \
    [get_bd_pins mem_sc/aclk]
connect_bd_net [get_bd_pins ddr3/ui_clk_sync_rst] \
    [get_bd_pins reset_not/Op1]
connect_bd_net [get_bd_pins reset_not/Res] \
    [get_bd_pins ddr3/aresetn] \
    [get_bd_pins jtag_axi/aresetn] \
    [get_bd_pins mem_sc/aresetn]

make_bd_intf_pins_external [get_bd_intf_pins ddr3/DDR3]
set_property name DDR3 [get_bd_intf_ports DDR3_0]

set sys_clk_port [create_bd_port -dir I -type clk sys_clk_i]
set_property CONFIG.FREQ_HZ 200000000 $sys_clk_port
connect_bd_net $sys_clk_port [get_bd_pins ddr3/sys_clk_i]

set sys_rst_port [create_bd_port -dir I -type rst sys_rst_n]
set_property CONFIG.POLARITY ACTIVE_LOW $sys_rst_port
connect_bd_net $sys_rst_port [get_bd_pins ddr3/sys_rst]

set ui_clk_port [create_bd_port -dir O -type clk ui_clk]
connect_bd_net $ui_clk_port [get_bd_pins ddr3/ui_clk]
set ui_clock_domain [get_property CONFIG.CLK_DOMAIN \
    [get_bd_pins ddr3/ui_clk]]
set_property CONFIG.CLK_DOMAIN $ui_clock_domain $scheduler_port
set_property CONFIG.CLK_DOMAIN $ui_clock_domain $camera_port
set_property CONFIG.ASSOCIATED_BUSIF {S_AXI_SCHED:S_AXI_CAMERA} $ui_clk_port
set ui_rst_port [create_bd_port -dir O -type rst ui_clk_sync_rst]
set_property CONFIG.POLARITY ACTIVE_HIGH $ui_rst_port
connect_bd_net $ui_rst_port [get_bd_pins ddr3/ui_clk_sync_rst]
set calib_port [create_bd_port -dir O init_calib_complete]
connect_bd_net $calib_port [get_bd_pins ddr3/init_calib_complete]

assign_bd_address -offset 0x00000000 -range 0x40000000 \
    -target_address_space [get_bd_addr_spaces jtag_axi/Data] \
    [get_bd_addr_segs ddr3/memmap/memaddr] -force
assign_bd_address -offset 0x00000000 -range 0x40000000 \
    -target_address_space [get_bd_addr_spaces S_AXI_SCHED] \
    [get_bd_addr_segs ddr3/memmap/memaddr] -force
assign_bd_address -offset 0x00000000 -range 0x40000000 \
    -target_address_space [get_bd_addr_spaces S_AXI_CAMERA] \
    [get_bd_addr_segs ddr3/memmap/memaddr] -force
validate_bd_design
save_bd_design

set bd_file [get_files -quiet */memory_subsystem.bd]
generate_target all $bd_file
set wrapper_files [make_wrapper -files $bd_file -top]
add_files -fileset sources_1 -norecurse $wrapper_files

puts "MEMORY_SUBSYSTEM_BD=$bd_file"
