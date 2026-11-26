set_param general.maxThreads 4

set partNum xc7s50csga324-1
set_part $partNum

set outputDir obj
file mkdir $outputDir

set files [glob -nocomplain -directory $outputDir *]

if {[llength $files] != 0} {
    puts "Deleting contents of $outputDir"
    foreach f $files {
        set tail [file tail $f]
        if {$tail ne "vivado.log" && $tail ne "vivado.jou"} {
            file delete -force $f
        }
    }
} else {
    puts "$outputDir is empty"
}

proc find_files_recursive {dir pattern} {

    set result {}

    if {![file isdirectory $dir]} {
        return $result
    }

    foreach file [glob -nocomplain -directory $dir *] {

        if {[file isdirectory $file]} {

            lappend result {*}[find_files_recursive $file $pattern]

        } elseif {[string match $pattern [file tail $file]]} {

            lappend result $file

        }
    }

    return $result
}

set sources_sv [lsort [find_files_recursive ./hdl *.sv]]

puts "=========================================="
puts "SystemVerilog Sources:"
puts "=========================================="

foreach file $sources_sv {
    puts "  $file"
}

if {[llength $sources_sv] > 0} {
    read_verilog -sv $sources_sv
} else {
    error "No SystemVerilog files found in ./hdl"
}

set sources_v [lsort [find_files_recursive ./hdl *.v]]

puts "=========================================="
puts "Verilog Sources:"
puts "=========================================="

foreach file $sources_v {
    puts "  $file"
}

if {[llength $sources_v] > 0} {
    read_verilog $sources_v
}

set sources_xdc [lsort [find_files_recursive ./xdc *.xdc]]

puts "=========================================="
puts "Constraint Files:"
puts "=========================================="

foreach file $sources_xdc {
    puts "  $file"
}

if {[llength $sources_xdc] > 0} {
    read_xdc $sources_xdc
} else {
    puts "WARNING: No XDC constraint files found."
}

set sources_mem [concat \
    [find_files_recursive ./data *.mem] \
    [find_files_recursive ./mem *.mem] \
]

set sources_mem [lsort -unique $sources_mem]

puts "=========================================="
puts "Memory Files:"
puts "=========================================="

foreach file $sources_mem {
    puts "  $file"
}

if {[llength $sources_mem] > 0} {
    read_mem $sources_mem
}

set sources_ip [glob -nocomplain -directory ./ip -tails *]

puts "=========================================="
puts "IP Sources:"
puts "=========================================="

foreach ip_source $sources_ip {

    if {[file isdirectory ./ip/$ip_source]} {

        set ip_file ./ip/$ip_source/$ip_source.xci

        if {[file exists $ip_file]} {
            puts "  $ip_file"
            read_ip $ip_file
        }
    }
}

if {[llength [get_ips -quiet]] > 0} {

    upgrade_ip [get_ips]

    generate_target all [get_ips]

    synth_ip [get_ips]
}

puts "=========================================="
puts "Starting Synthesis"
puts "=========================================="

synth_design -top top_level -part $partNum -verbose

report_timing_summary \
    -delay_type min_max \
    -report_unconstrained \
    -check_timing_verbose \
    -max_paths 100 \
    -file $outputDir/post_synth_timing_summary.rpt

report_timing \
    -delay_type max \
    -slack_lesser_than 0.0 \
    -max_paths 10000 \
    -nworst 100 \
    -sort_by slack \
    -input_pins \
    -routable_nets \
    -file $outputDir/post_synth_timing_setup.rpt

report_timing \
    -delay_type min \
    -slack_lesser_than 0.0 \
    -max_paths 10000 \
    -nworst 100 \
    -sort_by slack \
    -input_pins \
    -routable_nets \
    -file $outputDir/post_synth_timing_hold.rpt

report_utilization \
    -file $outputDir/post_synth_util.rpt

report_utilization \
    -file $outputDir/post_synth_util_hierarchical.rpt \
    -hierarchical \
    -hierarchical_depth 4 \
    -hierarchical_min_primitive_count 0

check_timing \
    -verbose \
    -file $outputDir/post_synth_check_timing.rpt

report_clocks \
    -file $outputDir/post_synth_clocks.rpt

report_clock_networks \
    -file $outputDir/post_synth_clock_networks.rpt

report_clock_interaction \
    -delay_type min_max \
    -significant_digits 3 \
    -file $outputDir/post_synth_clock_interaction.rpt

report_cdc \
    -details \
    -file $outputDir/post_synth_cdc.rpt

report_methodology \
    -file $outputDir/post_synth_methodology.rpt

report_drc \
    -file $outputDir/post_synth_drc.rpt

report_high_fanout_nets \
    -timing \
    -load_types \
    -max_nets 50 \
    -file $outputDir/post_synth_high_fanout.rpt

report_control_sets \
    -verbose \
    -file $outputDir/post_synth_control_sets.rpt

puts "=========================================="
puts "Starting Optimization and Placement"
puts "=========================================="

opt_design

place_design

set worst_setup_path [get_timing_paths -max_paths 1 -nworst 1 -setup]
if {[llength $worst_setup_path] > 0 && [get_property SLACK $worst_setup_path] < 0} {

    puts "Found setup timing violations => running physical optimization"

    phys_opt_design
}

report_clock_utilization \
    -file $outputDir/post_place_clock_util.rpt

report_utilization \
    -file $outputDir/post_place_util_hierarchical.rpt \
    -hierarchical \
    -hierarchical_depth 4 \
    -hierarchical_min_primitive_count 0

report_utilization \
    -file $outputDir/post_place_util.rpt

report_timing_summary \
    -delay_type min_max \
    -report_unconstrained \
    -check_timing_verbose \
    -max_paths 100 \
    -file $outputDir/post_place_timing_summary.rpt

report_timing \
    -delay_type max \
    -slack_lesser_than 0.0 \
    -max_paths 10000 \
    -nworst 100 \
    -sort_by slack \
    -input_pins \
    -routable_nets \
    -file $outputDir/post_place_timing_setup.rpt

report_timing \
    -delay_type min \
    -slack_lesser_than 0.0 \
    -max_paths 10000 \
    -nworst 100 \
    -sort_by slack \
    -input_pins \
    -routable_nets \
    -file $outputDir/post_place_timing_hold.rpt

report_io \
    -file $outputDir/post_place_io.rpt

report_control_sets \
    -verbose \
    -file $outputDir/post_place_control_sets.rpt

report_design_analysis \
    -congestion \
    -timing \
    -complexity \
    -file $outputDir/post_place_design_analysis.rpt

puts "=========================================="
puts "Starting Routing"
puts "=========================================="

route_design -directive Explore

report_route_status \
    -file $outputDir/post_route_status.rpt

report_utilization \
    -file $outputDir/post_route_util.rpt

report_utilization \
    -file $outputDir/post_route_util_hierarchical.rpt \
    -hierarchical \
    -hierarchical_depth 4 \
    -hierarchical_min_primitive_count 0

report_timing_summary \
    -delay_type min_max \
    -report_unconstrained \
    -check_timing_verbose \
    -max_paths 100 \
    -warn_on_violation \
    -file $outputDir/post_route_timing_summary.rpt

report_timing \
    -delay_type max \
    -slack_lesser_than 0.0 \
    -max_paths 10000 \
    -nworst 100 \
    -sort_by slack \
    -input_pins \
    -routable_nets \
    -file $outputDir/post_route_timing_setup.rpt

report_timing \
    -delay_type min \
    -slack_lesser_than 0.0 \
    -max_paths 10000 \
    -nworst 100 \
    -sort_by slack \
    -input_pins \
    -routable_nets \
    -file $outputDir/post_route_timing_hold.rpt

report_pulse_width \
    -all_violators \
    -file $outputDir/post_route_pulse_width.rpt

report_clock_utilization \
    -file $outputDir/post_route_clock_util.rpt

report_clock_interaction \
    -delay_type min_max \
    -significant_digits 3 \
    -file $outputDir/post_route_clock_interaction.rpt

report_cdc \
    -details \
    -file $outputDir/post_route_cdc.rpt

report_power \
    -file $outputDir/post_route_power.rpt

report_drc \
    -file $outputDir/post_route_drc.rpt

report_methodology \
    -file $outputDir/post_route_methodology.rpt

report_io \
    -file $outputDir/post_route_io.rpt

report_ram_utilization \
    -detail \
    -file $outputDir/post_route_ram_util.rpt

report_design_analysis \
    -congestion \
    -timing \
    -complexity \
    -file $outputDir/post_route_design_analysis.rpt

report_datasheet \
    -file $outputDir/post_route_datasheet.rpt

report_exceptions \
    -file $outputDir/post_route_exceptions.rpt

puts "=========================================="
puts "Generating Bitstream"
puts "=========================================="

write_bitstream -force $outputDir/final.bit

write_debug_probes -force $outputDir/final.ltx

puts "=========================================="
puts "BUILD COMPLETE"
puts "Bitstream: $outputDir/final.bit"
puts "Debug Probes: $outputDir/final.ltx"
puts "=========================================="

foreach log_file {vivado.log vivado.jou} {
    if {[file exists $log_file]} {
        set src_path [file normalize $log_file]
        set dst_path [file normalize [file join $outputDir $log_file]]
        if {$src_path ne $dst_path} {
            file copy -force $src_path $dst_path
        }
    }
}