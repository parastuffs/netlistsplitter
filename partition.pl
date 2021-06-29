#!/usr/bin/perl -w
# use 5.010;
use strict;
use warnings;
no warnings 'uninitialized';
# use diagnostics;
use Test::More;
# use lib '.';
use Verilog::Netlist;
use lib './lefParser';
use LEF;
use Data::Dumper;
use File::Log;
use Data::Dumper;
use Term::ProgressBar;


# DEFAULT: Split fanout in top
my $SPLIT_SOURCE = 0;
foreach my $argIdx (0 .. scalar @ARGV) {
    if ($ARGV[$argIdx] eq "--help") {
        print 'Usage: ${0} [OPTION]

  --help            Print this help
  --split-source    Split fanout in bottom die
';
        exit;
    }
    elsif ($ARGV[$argIdx] eq "--split-source") {
        $SPLIT_SOURCE = 1;
    }
}

my $log = File::Log->new({
  debug           => 5,                   # Set the debug level
  logFileName     => 'splitterlog.log',   # define the log filename
  logFileMode     => '>',                 # '>>' Append or '>' overwrite
  dateTimeStamp   => 1,                   # Timestamp log data entries
  stderrRedirect  => 0,                   # Redirect STDERR to the log file
  defaultFile     => 1,                   # Use the log file as the default filehandle
  logFileDateTime => 1,                   # Timestamp the log filename
  appName         => 'netlistsplitter',   # The name of the application
  PIDstamp        => 0,                   # Stamp the log data with the Process ID
  storeExpText    => 1,                   # Store internally all exp text
  msgprepend      => '',                  # Text to prepend to each message
  say             => 1,                   # msg() and exp() methode act like the perl6 say
                                          #  command (default off) requested by Aaleem Jiwa
                                          #  however it might be better to just use the say()
                                          #  method
});

# print STDOUT "test";

$log->msg(2, "*******************************************");
$log->msg(2, "Splitting netlist");
$log->msg(2, "*******************************************");

# Setup options so files can be found
use Verilog::Getopt;
my $opt = new Verilog::Getopt;
$opt->parameter( "+incdir+verilog", "-y","verilog",);

# Prepare netlist
my $nl =  new Verilog::Netlist (options => $opt, link_read_nonfatal=>1,);
my $nl_Top = new Verilog::Netlist (options => $opt, link_read_nonfatal=>1,);
my $nl_Bot = new Verilog::Netlist (options => $opt, link_read_nonfatal=>1,);
my $nl_toplevel = new Verilog::Netlist (options => $opt, link_read_nonfatal=>1,);

my @fl = (filename=>'partition.pl', lineno=>0);

# Prepare nets-cells hash
my %hashNetCell;

# hash of 3D nets names.
my %nets3D;

# hash of feedthrough nets names.
my %netsFT;

# hash of 3D nets to split at the source
my %netsSplitSource; # {net_name => (source_instance, sink_1, sink_2, ..., sink_n)}

# Input data: netlist and partition 
#my @VerilogFiles=("./verilog/tmp.v");
#my $TopModuleName=("BotDie");
##my @InstancesToMove=("o_reg_15_", "o_reg_14_", "o_reg_13_", "o_reg_12_", "o_reg_11_", "toto", "U57", "U20");
#my @InstancesToMove=("o_reg_15_", "o_reg_14_", "o_reg_13_", "exu1_irf");

#my @VerilogFiles=("./verilog/spc_flat_m_simplified_01.v");
#my $TopModuleName=("spc");
#my $path_to_file = ("./spc_Die1.prt");
#open my $handle, '<', $path_to_file;
#chomp(my @InstancesToMove = <$handle>);
#close $handle;

#my @VerilogFiles=("./verilog/l2t_flat_m_simplified_01.v");
#my $path_to_file = ("./l2t_Die1_1.prt");

#my @VerilogFiles=("./verilog/l2t_flat_m.v");
#my $path_to_file = ("./l2t_Die1_2.prt");

#------------------------------------------------------------------------
# L2T  
#------------------------------------------------------------------------
# Normal 
#my $root=("prt_l2t");
#my @VerilogFiles=("./$root/l2t_flat_m.v");
#my $path_to_file = ("./$root/l2t.prt");
##my $path_to_file = ("./$root/l2t_1.prt");
#my $TopModuleName=("l2t");

## NoBuffers
#my $root=("prt_l2t_NoBuffers");
#my @VerilogFiles=("./$root/l2t_NoBuffers.v");
#my $path_to_file = ("./$root/l2t.prt");
#my $TopModuleName=("l2t");
#------------------------------------------------------------------------

#------------------------------------------------------------------------
# L2B  
#------------------------------------------------------------------------
#my $root=("prt_l2b");
#my @VerilogFiles=("./$root/l2b_flat_m.v");
#my $path_to_file = ("./$root/l2b.prt");
#my $TopModuleName=("l2b");
#------------------------------------------------------------------------

#------------------------------------------------------------------------
# SPC Core 
#------------------------------------------------------------------------
# my $root=("prt_spc");
# my @VerilogFiles=("./$root/spc_flat_m.v");
# my $path_to_file = ("./$root/spc.prt");
# my $TopModuleName=("spc");

# # ArmM0
# my $root=("armM0");
# my @VerilogFiles=("./$root/ArmM0.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("ArmM0");
# my $lefpath=("./$root/gsclib045_lvt_macro.lef");

# # ArmM0 -Test spaces
# my $root=("armM0_test_spaces");
# my @VerilogFiles=("./$root/ArmM0.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("ArmM0");
# my $lefpath=("./$root/gsclib045_lvt_macro.lef");

# ArmM0 MAXCUT
# my $root=("armM0_maxcut");
# my @VerilogFiles=("./$root/ArmM0.v");
# my $path_to_file = ("./$root/circut_01_NoWires_area.hgr.part");
# my $TopModuleName=("ArmM0");
# my $lefpath=("./$root/gsclib045_lvt_macro.lef");

# msp430 QFLOW mincut
# my $root=("msp430");
# my @VerilogFiles=("./$root/openMSP430.rtl.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("openMSP430");
# my $lefpath=("./$root/osu018_stdcells.lef");

# # prt_OpenPiton_l2
# my $root=("netlistsplitter-master/netlistsplitter-master/prt_OpenPiton_l2");
# my @VerilogFiles=("./$root/l2_flat_m.v");
# my $path_to_file = ("./$root/l2.prt");
# my $TopModuleName=("l2");
# my $lefpath=("./$root/allOpenPiton.lef");

# # LDPC iN7 2020
# my $root=("ldpc-2020");
# my @VerilogFiles=("./$root/ldpc_routed.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("ldpc");
# my $lefpath=("./$root/iN7.lef");

# # LDPC iN7 2020
# my $root=("2020_pinFixed");
# my @VerilogFiles=("./$root/ldpc_routed.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("ldpc");
# my $lefpath=("./$root/iN7.lef");

# # SPC iN7 2020
# my $root=("SPC-2020");
# my @VerilogFiles=("./$root/spc.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("spc");
# my $lefpath=("./$root/iN7ALL.lef");

# # SPC iN7 2020 MoL
# my $root=("SPC-2020_MoL");
# my @VerilogFiles=("./$root/spc.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("spc");
# my $lefpath=("./$root/iN7ALL.lef");

# # SPC iN7 2020 LoL gate-level
# my $root=("SPC-2020_LoL_gate-level");
# my @VerilogFiles=("./$root/spc.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("spc");
# my $lefpath=("./$root/iN7ALL.lef");
# # my $lefpath=("./$root/iN7ALL.lef");

# # SPC iN7 2020 LoL gate-level
# my $root=("SPC-2020_metal-clustering_4");
# my @VerilogFiles=("./$root/spc.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("spc");
# my $lefpath=("./$root/iN7ALL.lef");

# # BoomCore iN7 2020 1-ML
# my $root=("boomcore-2020_1-ML");
# my @VerilogFiles=("./$root/BoomCore_WithBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("BoomCore");
# my $lefpath=("./$root/iN7ALL.lef");

# # BoomCore iN7 2020 2-ML
# my $root=("boomcore-2020_2-ML");
# my @VerilogFiles=("./$root/BoomCore_WithBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("BoomCore");
# my $lefpath=("./$root/iN7ALL.lef");

# # BoomCore iN7 2020 3-ML
# my $root=("boomcore-2020_3-ML");
# my @VerilogFiles=("./$root/BoomCore_WithBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("BoomCore");
# my $lefpath=("./$root/iN7ALL.lef");

# # BoomCore iN7 2020 4-ML
# my $root=("boomcore-2020_4-ML");
# my @VerilogFiles=("./$root/BoomCore_WithBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("BoomCore");
# my $lefpath=("./$root/iN7ALL.lef");

# # BoomCore iN7 2020 5-ML
# my $root=("boomcore-2020_5-ML");
# my @VerilogFiles=("./$root/BoomCore_WithBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("BoomCore");
# my $lefpath=("./$root/iN7ALL.lef");

# # BoomCore iN7 2020 6-ML
# my $root=("boomcore-2020_6-ML");
# my @VerilogFiles=("./$root/BoomCore_WithBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("BoomCore");
# my $lefpath=("./$root/iN7ALL.lef");

# # BoomCore iN7 2020 gate-level
# my $root=("boomcore-2020_gate-level");
# my @VerilogFiles=("./$root/BoomCore_WithBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("BoomCore");
# my $lefpath=("./$root/iN7ALL.lef");

# # BoomCore iN7 2020 gate-level, post-place, buffer-less
# my $root=("MemPool-Group-MoL");
# my @VerilogFiles=("./$root/group_flat.v");
# my $path_to_file = ("./$root/Mempool-Group_pure-MoL_metis_01_NoWires_area.hgr.part_striped.txt");
# my $TopModuleName=("group");
# my $lefpath=("./$root/iN3_ALL.lef");

# # SPC iN7 2020 LoL block-level
# my $root=("SPC-2020_LoL_block-level");
# my @VerilogFiles=("./$root/spc.v");
# my $path_to_file = ("./$root/metis_04_1-TotLength_area.hgr.part");
# my $TopModuleName=("spc");
# my $lefpath=("./$root/iN7ALL.lef");

# # MemPool Group in3 MoL 
# my $root=("MemPool-Group-MoL");
# my @VerilogFiles=("./$root/group_noBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("group");
# my $lefpath=("./$root/iN3_ALL.lef");

# # MemPool Group in3 MoL 
# my $root=("MemPool-Group-LoL");
# my @VerilogFiles=("./$root/group_noBuffers.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("group");
# my $lefpath=("./$root/iN3_ALL.lef");

# # MemPool Tile in3 MoL 
# my $root=("MemPool-Tile-MoL");
# my @VerilogFiles=("./$root/tile_noBuff.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
# my $TopModuleName=("tile");
# my $lefpath=("./$root/iN3_ALL.lef");

# # MemPool Tile in3 LoL 
# my $root=("MemPool-Tile-LoL");
# my @VerilogFiles=("./$root/tile_noBuff.v");
# my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part_escaped");
# my $TopModuleName=("tile");
# my $lefpath=("./$root/iN3_ALL.lef");

# ARMm0 testing fanout on bottom
my $root=("armM0_fanout-bot");
my @VerilogFiles=("./$root/ArmM0.v");
my $path_to_file = ("./$root/metis_01_NoWires_area.hgr.part");
my $TopModuleName=("ArmM0");
my $lefpath=("./$root/gsclib045_lvt_macro.lef");

## iN7 
#my $root=("spc_iN7");
#my @VerilogFiles=("./$root/spc_flat_m.v");
#my $path_to_file = ("./$root/spc.prt");
#my $TopModuleName=("spc");

#my $root=("prt_spc_NoBuffers");
#my @VerilogFiles=("./$root/spc_NoBuffers.v");
#my $path_to_file = ("./$root/spc.prt");
#my $TopModuleName=("spc");

# my $root=("prt_exu");
# my @VerilogFiles=("./$root/exu_flat_m.v");
# my $path_to_file = ("./$root/exu.prt");
# my $TopModuleName=("exu");
#------------------------------------------------------------------------


my $skippedNets = 0;

#***************************************************************************
# Parse LEF file 
# Read LEF to get pin directions of macros 
my $LEF = LEF->new({name => "all",
                    file_name => $lefpath,
                   });

# Open file, get data & build internal data structures
$LEF->parse_LEF();

#***************************************************************************
# Process partition file  
# Get the list of instances to move on another die 

open my $handle, '<', $path_to_file or die "Could not open '$path_to_file'";
my @InstancesToMoveIn;
my @lines = <$handle>;

my $progress = Term::ProgressBar->new({ count => scalar @lines,
                                        name => "Reading instances to move",
                                        ETA => "linear",
                                        silent => 0});
foreach my $line (@lines){
    $progress->update();
    chomp $line;
    my @linesplit = split(' ', $line);
    if ($linesplit[1] == '1') {
        push(@InstancesToMoveIn, $linesplit[0]);
    }
}
close $handle;

my @InstancesToMove;
my @InstancesToMove_clean;

$progress = Term::ProgressBar->new({ count => scalar @InstancesToMoveIn,
                                        name => "Creating instances hash",
                                        ETA => "linear",
                                        silent => 0});
# Clean from nasty characters
foreach my $cellToMove (@InstancesToMoveIn) {
    $progress->update();
    push @InstancesToMove, $cellToMove;
    $cellToMove=~ s/\s//g;
    my $tmp = quotemeta $cellToMove;
    push @InstancesToMove_clean, $tmp;
}

# Create hash to easily search for instances to move in 3D nets candidates
my %InstancesToMove_hash = map { $_ => 1 } @InstancesToMove_clean;

#***************************************************************************
# Process NETLIST  
# Netlist should be flat and in a single file 

$log->msg(2, "===>");
$log->msg(2, " Reading netlist");

foreach my $file (@VerilogFiles) {
    $nl->read_file (filename=>$file);
    $nl_Bot->read_file (filename=>$file);
}
$nl->link();            # Read in any sub-modules
#$nl->lint();           # Optional, see docs; probably not wanted
$nl->exit_if_error();
$log->msg(2, "<=== Done !");

# Find top module in src netlist
$log->msg(2, "===>");
$log->msg(2, " Searching Top module");
my $TopModule=$nl->find_module($TopModuleName);
if (defined $TopModule) {
    $log->msg(2, "Found top module $TopModuleName");
    $log->msg(2, "<=== Done !");
    } 
else {$log->msg(2, "Could't find top module $TopModuleName");exit;}

# Create top module in top die
$log->msg(2, "Create top module in top die...");
my $TopDie_TopMod = CreateNewModule($nl_Top,'TopDie',@fl);

# Create top module in toplevel
$log->msg(2, "Create top module in toplevel...");
my $TopLevel_TopMod = CreateNewModule($nl_toplevel, 'TopLevel', @fl);

$log->msg(2, "Refresh netlist linkage...");
$nl_Bot->link();

# Rename the top module in bot die 
my $BotDie_TopMod=$nl_Bot->find_module($TopModuleName);
if (! defined $TopModule) {$log->msg(2, "Could't find top module in bot die: $TopModuleName"); exit;}
    else
        {
        # $log->msg(2, "Renaming top module of the bottom die: $TopModuleName");
        # $BotDie_TopMod->name='BotDie';
    }

$log->msg(2, "Splitting buses...");
splitBuses($BotDie_TopMod);
$nl_Bot->link();
splitBuses($TopModule);
$nl->link();

# Populate hash with net-cell associations
LinkNetCells();

my $topdiecell = $TopLevel_TopMod->new_cell(name=>"top_die",
                        netlist=>$nl_toplevel,
                        submod=>$TopDie_TopMod,
                        submodname=>$TopDie_TopMod->name);

my $botdiecell = $TopLevel_TopMod->new_cell(name=>"bot_die",
                        netlist=>$nl_toplevel,
                        submod=>$BotDie_TopMod,
                        submodname=>$BotDie_TopMod->name);

$progress = Term::ProgressBar->new({ count => scalar $TopModule->ports,
                                        name => "Creating ports in Top",
                                        ETA => "linear",
                                        silent => 0});
# Copy ports from bottom die into toplevel.
foreach my $port ($TopModule->ports) {
    $progress->update();
    my $netname = $port->net->name;
    $log->msg(5, "netname in bottom port: $netname");
    $TopLevel_TopMod->new_port(data_type=>$port->data_type,
                            direction=>$port->direction,
                            module=>$TopLevel_TopMod,
                            name=>$port->name,
                            net=>$port->net,
                            array=>$port->array);
    # At the same time, copy linked net.
    my $botnet = $port->net;
    $TopLevel_TopMod->new_net(array=>$botnet->array,
                        data_type=>$botnet->data_type,
                        module=>$TopLevel_TopMod,
                        lsb=>$botnet->lsb,
                        msb=>$botnet->msb,
                        name=>$botnet->name,
                        net_type=>$botnet->net_type,
                        value=>$botnet->value,
                        width=>$botnet->width,
                        port=>$port
                        );
}

# Resolves references between the different modules.
$nl_toplevel->link();
$nl_Top->link();
$nl_Bot->link();




#*****************************************************************************************************************
# ----->
# Create Top die from scratch and
# for all instances that we need to move 

$log->msg(2, "===>");
$log->msg(2, "Splitting: ");
$log->msg(2, "...");
my $indent="   ";

# List of input feedthroughs to top die.
my @ft_in = ();

# Hash of assignement pairs
my %assignements; # {lhs => rhs}

# Progress bar init
$progress = Term::ProgressBar->new({ count => scalar @InstancesToMove,
                                        name => "Moving instances",
                                        ETA => "linear",
                                        silent => 0});

#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
my %newports;
foreach my $inst (@InstancesToMove) 
{
    $progress->update();
    $log->msg(5, "Searching instance: $inst");
    my $foundInst=$TopModule->find_cell($inst);
    $foundInst=~ s/\\//g; # Remove extra escaping characters
    if (! defined $foundInst) {$log->msg(1, "ERROR: can't find instance $inst <-"); exit 1;}
    else {
        my $foundInstName = $foundInst->name;
        $log->msg(5, "$indent Found instance: $foundInstName <-");
        # Add this cell to TopDie netlist
        AddCell($TopDie_TopMod, $foundInst, @fl);
        DeleteCell($BotDie_TopMod, $foundInst, @fl);

        # Go through all pins of this instance 
        foreach my $pin ($foundInst->pins) 
        {
            # Get pin direction
            # my $thisPinDirection=$pin->direction;
            my $pinName = $pin->name;
            $log->msg(5, "$indent $indent Pin: $pinName <-");
            
            # Get net(s) connected to this pin
            foreach my $pinselect ($pin->pinselects)
            {
                my $pinselectNetname = $pinselect->netname;
                $log->msg(5, "$indent $indent $indent Net: $pinselectNetname <-");

                my $isConcatenation; # undef is false

                if($pinselectNetname =~ m/^\{.*\}$/){
                    $isConcatenation = 1;
                    $log->msg(5, "This net is actually a concatenation");
                    # If this is a concatenation, we should analyse each net separately, and treat them as we would the other nets (3D, bus, wire, local, etc.).
                    # However, the handling differs when tackling the pin. There, we should reconcatenate the nets (feedthrough or not depending on the case) before setting them to the pin. This can be done through a @pinselects array.
                    # This should be necessary only for the cells pins, not the port of whatever.
                }
                $pinselectNetname =~ s/(^\{)|(\}$)//g;
                my @netnames = split(',',   $pinselectNetname);
                

                foreach my $netcompletename (@netnames){

                    my $netNameOnly = $netcompletename;
                    # Get rid of brackets if bus (array)
                    $netNameOnly=~ s/\[([^\[\]]|(?0))*]$//g; # Only remove the ending brackets. There might be some *inside* the net name, but those are part of its name and should not be removed.
                    
                    #=======================================
                    # CASE 1
                    # Net is connected to a top-level port of the src netlist
                    # We look for the name only 
                    # => Feedthrough, but not a 3D net.
                    my $foundPort=$TopModule->find_port($netNameOnly);
                    my $newportname = undef;

                    # If net name is escaped, i.e. starts with \
                    if($netNameOnly =~ m/^\\/) {
                        $netNameOnly =~ s/ $//g;
                        $newportname = $netNameOnly.'_ft_toplevel ';
                    }
                    else {
                        $newportname = $netNameOnly.'_ft_toplevel';
                    }
                    # Is this net from a split bus?
                    my $isBusSplit = 0;
                    # If it was not found, it might be because the net has had its name changed when splitting the buses at the begining.
                    # As the ports share the same name with those buses, the net we are looking for might still actually be connected to a port, but not sharing the same name anymore.
                    if (!defined $foundPort) {
                        my $netNameOnlyUnsplit = $netNameOnly;
                        # Remove the leading '\' first.
                        $netNameOnlyUnsplit =~ s/\\//;
                        # Then remove the appended '_wire'. The brackets [] have been removed in $netNameOnly.
                        $netNameOnlyUnsplit =~ s/_wire $//;
                        # Finaly, look again.
                        $log->msg(5, "Did not find port '$netNameOnly', looking for '$netNameOnlyUnsplit'");
                        $foundPort=$TopModule->find_port($netNameOnlyUnsplit);
                        $newportname = $netcompletename;
                        $newportname =~ s/ $//;
                        $newportname = $newportname.'_ft_toplevel ';
                        $isBusSplit = 1;
                    }
                    if (defined $foundPort) 
                    {
                        my $foundPortName = $foundPort->name;
                        $log->msg(5, "$indent $indent $indent $indent Is top-level port: $foundPortName <-");
                        my $ft_net;
                        # If found, check if it has been already added
                        my $portInTop=$TopDie_TopMod->find_port($foundPortName); 
                        if (defined $portInTop) 
                            {
                                $log->msg(5, "$indent $indent $indent $indent $indent Port: $foundPortName <- already added, skipping");}
                            else
                            {
                            # if not add port the Top die with same direction as in src netlist
                            my $direction = $foundPort->direction;
                            my $foundPortDirection = $foundPort->direction;
                            my $lsb = $foundPort->net->lsb;
                            my $msb = $foundPort->net->msb;
                            my $ftNetDataType = $foundPort->net->data_type;
                            # Unset the datatype if it's a bus split. This removes the [xx:yy] statement between 'wire' and its name.
                            if ($isBusSplit) {
                                $ftNetDataType = "";
                            }
                            # Create a feedthrough net
                            # my $newportname = $foundPort->name."_ft_toplevel";
                            $ft_net = $TopLevel_TopMod->new_net(array=>$foundPort->net->array,
                                                            data_type=>$ftNetDataType,
                                                            module=>$TopLevel_TopMod,
                                                            # lsb=>$lsb, # I don't want to have buses passed fed through at the moment. If I have problems later, this might be a place where to look. Omiting the lsb=> and msb=> lines removes the [xx:yy] statement from the net connected to a pin in a module.
                                                            # msb=>$msb,
                                                            name=>$newportname,
                                                            net_type=>"wire", # ft net on toplevel is just a wire
                                                            value=>$foundPort->net->value,
                                                            width=>$foundPort->net->width
                                                            );
                            my $newPort=$TopDie_TopMod->new_port(name=>$newportname,
                                                # direction is the same as top
                                                direction=>$foundPort->direction,
                                                data_type=>$foundPort->data_type,
                                                array=>$foundPort->array,
                                                module=>$TopDie_TopMod->name,
                                                net=>$ft_net
                                                );
                            $TopDie_TopMod->new_net(name=>$newportname,
                                            array=>$ft_net->array,
                                            data_type=>$ft_net->data_type,
                                            module=>$TopDie_TopMod,
                                            port=>$newPort
                                            );
                            # $TopDie_TopMod->link(); # Comment to speedup
                            $log->msg(5, "$indent $indent $indent $indent $indent Port: $newportname with dir: $foundPortDirection added to TopDie");
                            push(@ft_in, $foundPort->name);
                            $netsFT{$foundPort->name} = 1;

                            # my $tmpnetname = $newPort->net->name;
                            # print STDOUT "mouette $tmpnetname\n";

                            $log->msg(5, "Adding $foundPortName and its new port to the hash newports.");

                            $newports{$foundPortName} = $newPort;

                            
                            # ... and to the Bottom die, we need to add 2 pins
                            # one with same direction and same name
                            # one with opposite direction so that we feedthrough

                            my $otherDieDirection="none";

                            my $netdirection;
                            my $ftnetdirection;
                            # Input going to top die, in bottom we need 1. an output feedthrough and 2. an input regular.
                            if ($direction eq "in") { 
                                $otherDieDirection="out";
                                $netdirection = "input";
                                $ftnetdirection = "output";
                            }
                            # Output going to top die, in bottom we need 1. an input feedthrough and 2. an output regular.
                            if ($direction eq "out") {
                                $otherDieDirection="in";
                                $netdirection = "output";
                                $ftnetdirection = "input";
                            }
                           
                            # Feedthrough port, other direction
                            # my $otherDiePortName=$foundPort->name."_ft_toplevel";
                            my $otherDiePortName=$newportname;
                            my $botnetft = $BotDie_TopMod->new_net(array=>$ft_net->array,
                                                            data_type=>$ft_net->data_type,
                                                            module=>$BotDie_TopMod,
                                                            # lsb=>$lsb,
                                                            # msb=>$msb,
                                                            name=>$ft_net->name,
                                                            net_type=>$ftnetdirection,
                                                            value=>$ft_net->value,
                                                            width=>$ft_net->width
                                                            );
                            $BotDie_TopMod->new_port(
                                                name=>$otherDiePortName,
                                                direction=>$otherDieDirection,
                                                data_type=>$foundPort->data_type,
                                                array=>$foundPort->array,
                                                module=>$TopDie_TopMod->name,
                                                net=>$botnetft
                                                );
                            # Regular port, same direction, regular net
                            my $botnet = $BotDie_TopMod->new_net(array=>$foundPort->net->array,
                                                            data_type=>$foundPort->net->data_type,
                                                            module=>$BotDie_TopMod,
                                                            lsb=>$lsb,
                                                            msb=>$msb,
                                                            name=>$foundPort->net->name,
                                                            net_type=>$netdirection,
                                                            value=>$foundPort->net->value,
                                                            width=>$foundPort->net->width
                                                            );
                            # The name of the port on the bottom die, incoming the net from the toplevel.
                            my $regularPortName = $newportname;
                            $regularPortName =~ s/_ft_toplevel//;
                            # If not a bus split.
                            # If the net we are feeding through is from a split bus, we don't need to add a port with its name as the bus will already be there.
                            if (not($isBusSplit)) {
                                $BotDie_TopMod->new_port(
                                                    # name=>$foundPort->name,
                                                    name=>$regularPortName,
                                                    direction=>$foundPort->direction,
                                                    data_type=>$foundPort->data_type,
                                                    array=>$foundPort->array,
                                                    module=>$TopDie_TopMod->name,
                                                    net=>$botnet
                                                    );
                            }
                            # $BotDie_TopMod->link(); # Comment to speedup
                            # print STDOUT "mouette ".$tmpport->
                            my $botnetname = $botnet->name;
                            $log->msg(5, "$indent $indent $indent $indent $indent Port: $otherDiePortName with dir: $otherDieDirection added to Bot die as a feedthrough, with net named '$botnetname'");
                            $log->msg(5, "$indent $indent $indent $indent $indent Port: $foundPortName with dir: $otherDieDirection added to Bot die");
                            # $nl_Bot->link();

                            # Catch net number in botftnet
                            # Instead of 
                            #   assign HADDR = \HADDR_wire[23]_ft_toplevel ;
                            # I want
                            #   assign HADDR[23] = \HADDR_wire[23]_ft_toplevel ;
                            my $botftnetBit = "";
                            if ($isBusSplit) {
                                $botftnetBit = $botnetft->name;
                                $botftnetBit =~ s/.*(\[\d+\]).*/$1/;
                            }
                            my $botnetName = $botnet->name.$botftnetBit;
                            # Assign ft = input;
                            if ($direction eq "in") { 
                                $assignements{$botnetft->name} = $botnetName;
                            }
                            # Assign output = ft;
                            if ($direction eq "out") {
                                $assignements{$botnetName} = $botnetft->name;
                            }
                        }
                        my $foundNet=$TopModule->find_net($netNameOnly);
                        # if (defined $foundNet) {
                        #     $foundNet->delete;
                        # }

                        last
                    }
                                            
                    #=======================================
                    # CASE 2
                    # Net is a wire, meaning no corresponding port on toplevel netlist.
                    # Maybe we should find the net name '$netcompletename' instead of '$netNameOnly'
                    # Let's look into BotDie_TopMod instead of TopModule
                    $log->msg(5, "$indent $indent $indent $indent Looking for '$netcompletename' or '$netNameOnly'");
                    my $foundNet=$BotDie_TopMod->find_net($netcompletename);
                    if (!defined $foundNet) {
                        if (my @matches = $netcompletename =~ /\[(\d+)\]/g) { # For some reason, the regex must be catched in an array for all matches to be scanned and not just the first one.
                            my $busWire = $+; # Catch the *last* matching result
                            my $netNameOnlyStripped = $netNameOnly;
                            $netNameOnlyStripped =~ s/ $//g;# Remove trailing space that would end up in the middle of the final name.
                            $netNameOnlyStripped =~ s/^\\//g;# Remove heading \ that is added anyway
                            $netcompletename = "\\${netNameOnlyStripped}_wire[${busWire}] ";
                            $log->msg(5, "$indent $indent $indent $indent Actually looking for '$netcompletename' now");
                            $foundNet = $BotDie_TopMod->find_net($netcompletename);
                        }
                        if (!defined $foundNet) {
                            $foundNet=$BotDie_TopMod->find_net($netNameOnly);
                        }
                    }
                    my $isBus=0;
                    my $netIs3D=0;
                   
                    if (defined $foundNet) {
                        my $foundNetName = $foundNet->name;
                        $netNameOnly = $foundNetName;
                        $log->msg(5, "$indent $indent $indent $indent Net is top-level wire: $foundNetName <-"); 
                        if ( defined $foundNet->msb ) {
                            $isBus=1;
                            my $foundNetMSB = $foundNet->msb;
                            my $foundNetLSB = $foundNet->lsb;
                            $log->msg(5, "$indent $indent $indent $indent $indent MSB: $foundNetMSB LSB: $foundNetLSB <-");
                            }
                            else {
                                $isBus=0;
                            }
                        if ($isBus == 0) {
                            $netIs3D = isNet3D($foundNet->name, \@InstancesToMove_clean);
                       
                            if ($netIs3D == 0)  
                            # This is a local 2D wire    
                            {
                                $log->msg(5, "$indent $indent $indent $indent $indent $indent Net: $foundNetName is 2D ");
                                
                                # Check if it has been already added
                                my $netInTop=$TopDie_TopMod->find_port($netNameOnly); 
                                if (defined $netInTop) {
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Wire already added, skipping: $netNameOnly ");
                                }
                                else
                                {
                                    my $newNet=$TopDie_TopMod->new_net(name=>$netNameOnly,
                                                array=>$foundNet->array,
                                                data_type=>$foundNet->data_type,
                                                module=>$TopDie_TopMod
                                                );
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Wire (2D): $netNameOnly added to Top die");
                                }
                            }
                            else 
                            # This is a 3D net
                            {
                                $log->msg(5, "$indent $indent $indent $indent $indent $indent Net: $netNameOnly is 3D ");

                                if ($SPLIT_SOURCE) {
                                    my @netInstances = ();
                                    if (pinDirection($foundInst, $pin) eq "output") {
                                        my $instName = $foundInst->name;
                                        push(@netInstances, $instName);
                                        $log->msg(5, "$instName is a source, here are its sinks in BOT:");
                                        foreach my $cellName (@{$hashNetCell{$foundNet->name}}) {
                                            if(!exists($InstancesToMove_hash{$cellName})) {
                                                # Skip the one already added
                                                if ($cellName ne $instName) {
                                                    $log->msg(5, "$cellName");
                                                    push(@netInstances, $cellName);
                                                }

                                            }
                                            else {
                                                $log->msg(5, "$cellName is on TOP");
                                            }

                                        }
                                        # netsSplitSource is a hash (%), we access its content using $netsSplitSource{$key}.
                                        # To assign an array to an entry, we need bracket [] around the actual hash reference (@).
                                        $netsSplitSource{$foundNet->name} = [@netInstances];
                                    }
                                }

                                # Split sink, classic implementation
                                else {
                                   
                                    # Check if this net has been already added
                                    my $portInTop2=$TopDie_TopMod->find_port($netNameOnly); 
                                    if (defined $portInTop2) {
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Port already added, skipping: $netNameOnly ");
                                        $skippedNets += 1;
                                    }
                                    else
                                    # if not, look in the LEF file to discover the direction
                                    {
                                        my $foundInstName = $foundInst->name;
                                        my $foundInstSubmodname = $foundInst->submodname;
                                        my $pinName = $pin->name;
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent $indent Inst. name:  $foundInstName Module name: $foundInstSubmodname Pin: $pinName ");
                                        my $macroTofind = $foundInst->submodname;
                                        my $pinTofind   = $pin->name;
                                        my $pindir = $LEF->find_pindir($macroTofind,$pinTofind);
                                        # only lower case  
                                        my $pindir_lc= lc $pindir;
                                        
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent $indent Macro: $macroTofind with Pin: $pinTofind Pindir: $pindir_lc  ");
                                       
                                       #----------------------------------------------------------------
                                       # Add ports                                                      |
                                       #                                                                |
                                        my $newPort=$TopDie_TopMod->new_port(name=>$netNameOnly,
                                                            direction=>$pindir_lc,
                                                            data_type=>$foundNet->data_type,
                                                            #array=>$foundPort->array,
                                                            module=>$TopDie_TopMod,
                                                            net=>$foundNet
                                                    );
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent 3D wire port: $netNameOnly added to Top die");
                                        $TopDie_TopMod->new_net(name=>$netNameOnly,
                                                        array=>$foundNet->array,
                                                        data_type=>$foundNet->data_type,
                                                        module=>$TopDie_TopMod,
                                                        port=>$newPort
                                                        );
                                        # $TopDie_TopMod->link();

                                        $log->msg(5, "Adding $netNameOnly and its new port to the hash newports. (3D net)");
                                        $newports{$netNameOnly} = $newPort;
                                
                                        # ... and to the Bottom die, with opposite direction
                                        my $otherDieDirection="none";
                                        if ($pindir_lc eq "input") { $otherDieDirection="output";}
                                        if ($pindir_lc eq "output") { $otherDieDirection="input";}
                                        
                                        my $newPort_Bot=$BotDie_TopMod->new_port(name=>$netNameOnly,
                                                            direction=>$otherDieDirection,
                                                            data_type=>$foundNet->data_type,
                                                            #array=>$foundPort->array,
                                                            module=>$TopDie_TopMod,
                                                            net=>$foundNet
                                                            );
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Port: $netNameOnly added to Bot die");
                                        $BotDie_TopMod->new_net(name=>$netNameOnly,
                                                        array=>$foundNet->array,
                                                        data_type=>$foundNet->data_type,
                                                        module=>$BotDie_TopMod,
                                                        port=>$newPort_Bot
                                                        );
                                        $TopLevel_TopMod->new_net(name=>$netNameOnly,
                                                                data_type=>"",#wire
                                                                module=>$TopLevel_TopMod,
                                                                comment=>"// 3D net"
                                                                );
                                        
                                    }
                                }
                            }
                        }
                        else{
                        # ---------------
                        # this is a bus
                            my $cnt = 0;
                            my $busIs3D = 0;
                            foreach my $busWire ($foundNet->lsb .. $foundNet->msb) {
                                # my $fullNetName = "$netNameOnly\[$busWire\]";
                                # Testing an alternative to not skip 3D wires in buses:
                                my $netNameOnlyStripped = $netNameOnly;
                                $netNameOnlyStripped =~ s/ $//g;
                                $netNameOnlyStripped =~ s/^\\//g;
                                my $fullNetName = "\\${netNameOnlyStripped}_wire\[$busWire\] ";
                                
                                # Check if this wire of the bus is 3D or not
                                $netIs3D = isNet3D($fullNetName, \@InstancesToMove_clean);
                                if ($netIs3D == 0) {
                                    # count to see if all nets are 2D
                                    $cnt = $cnt + 1; 
                                } 
                            }
                            
                            if (($foundNet->msb - $foundNet->lsb) + 1 == $cnt) { $busIs3D = 0; }
                                else { $busIs3D = 1; }

                            if ($busIs3D == 0)  
                            # This is a local 2D bus    
                            {
                                $log->msg(5, "$indent $indent $indent $indent $indent $indent Bus: $netNameOnly is 2D bus");
                                
                                # Check if it has been already added
                                my $netInTop=$TopDie_TopMod->find_port($netNameOnly); 
                                if (defined $netInTop) {
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Bus already added, skipping: $netNameOnly ");
                                }
                                else
                                {
                                        my $newNet=$TopDie_TopMod->new_net(name=>$netNameOnly,
                                                    array=>$foundNet->array,
                                                    data_type=>$foundNet->data_type,
                                                    module=>$TopDie_TopMod
                                                    );
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent 2D local bus: $netNameOnly added to Top die");
                                }
                            }
                            else 
                            # This is a 3D bus
                            {
                                $log->msg(5, "$indent $indent $indent $indent $indent $indent Net: $netNameOnly is 3D bus");
                                pinDirection($foundInst, $pin);
                                   
                                # Check if this net has been already added
                                my $portInTop2=$TopDie_TopMod->find_port($netNameOnly); 
                                if (defined $portInTop2) 
                                    {$log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Port already added, skipping: $netNameOnly ");}
                                else
                                # if not look for the LEF file to discover the direction
                                {
                                    my $macroTofind = $foundInst->submodname;
                                    my $pinTofind   = $pin->name;
                                    my $pindir = $LEF->find_pindir($macroTofind,$pinTofind);
                                    my $pindir_lc = lc $pindir;

                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent $indent Macro: $macroTofind with  Pin: $pinTofind Pindir: $pindir_lc  ");
                                    
                                    # Top die 
                                    my $newPort=$TopDie_TopMod->new_port(name=>$netNameOnly,
                                                # direction is the same as top
                                                direction=>$pindir_lc,
                                                data_type=>$foundNet->data_type,
                                                module=>$TopDie_TopMod,
                                                net=>$foundNet
                                                );
                                    $TopDie_TopMod->new_net(name=>$netNameOnly,
                                                    array=>$foundNet->array,
                                                    data_type=>$foundNet->data_type,
                                                    module=>$TopDie_TopMod,
                                                    port=>$newPort
                                                    );
                                    # $TopDie_TopMod->link();
                                    $log->msg(5, "Adding $netNameOnly and its new port to the hash newports. (3D bus)");
                                    $newports{$netNameOnly} = $newPort;
                                
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent 3D bus port: $netNameOnly added to Top die");

                                    # This is the second pin with opposite direction
                                    my $otherDieDirection="none";
                                    if ($pindir_lc eq "input")  { $otherDieDirection="output"; }
                                    if ($pindir_lc eq "output") { $otherDieDirection="input"; }
                                
                                    # This is a feedthrough so it has a different name
                                    my $newPort_Bot=$BotDie_TopMod->new_port(
                                                        name=>$netNameOnly,
                                                        direction=>$otherDieDirection,
                                                        data_type=>$foundNet->data_type,
                                                        module=>$TopDie_TopMod,
                                                        net=>$foundNet
                                                        );
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent 3D bus port: $netNameOnly with dir: $otherDieDirection added to Bot die");
                                    $BotDie_TopMod->new_net(name=>$netNameOnly,
                                                    array=>$foundNet->array,
                                                    data_type=>$foundNet->data_type,
                                                    module=>$BotDie_TopMod,
                                                    port=>$newPort_Bot
                                                    );

                                    $TopLevel_TopMod->new_net(
                                                        name=>$netNameOnly,
                                                        data_type=>$foundNet->data_type,
                                                        module=>$TopLevel_TopMod,
                                                        comment=>"// 3D bus"
                                                        );
                                }
                            }
                        }
                    }
                    else {
                        $log->msg(1, "ERROR: $netNameOnly was not found in the top  module when looking for '$netcompletename', even though it's connecting cells in there, in particular $inst on pin $pinName");
                        if($netNameOnly =~ m/\d'b\d/) {
                            $log->msg(1, "Seems like it's a constant though, so I guess it's alright.");
                        }
                        else {
                            exit 1;
                        }
                    }
                        
                }
            }
        }
    }
}


#########################
# Managing 3D split nets
#########################
foreach my $key (keys %netsSplitSource) {
    # log->msg(5, "In net, we have:");
    print STDOUT "coucou $key\n";
    $log->msg(5, "$netsSplitSource{$key}[0]");
    # $#{ $netsSplitSource{$key} } is the size of the array at key $key inside the hash %netsSplitSource
    for my $i ( 0 .. $#{ $netsSplitSource{$key} } ) {
        # This is a source
        if ($i == 0) {
            $log->msg(5, "Source: $netsSplitSource{$key}[$i], nothing to do here.");
        }
        # This is a sink
        else {
            $log->msg(5, "Sink: $netsSplitSource{$key}[$i]");
            # Get net object reference from its name.
            # The net still lies in the *bottom* die module, as it was not create in the topdie module.
            my $net = $BotDie_TopMod->find_net($key);

            # Create new net name
            my $newNetName = $net->name;
            if ($newNetName =~ /\s$/) {
                $newNetName =~ s/\s$//;
                $newNetName .= "_split${i} ";
            }
            else {
                $newNetName .= "_split${i}";
            }

            # Create a new net in TOP
            my $newNetTop = $TopDie_TopMod->new_net(
                            name=>$newNetName,
                            array=>$net->array,
                            data_type=>$net->data_type,
                            module=>$TopDie_TopMod,
                            net_type=>"output",
                            comment=>"// Split net");

            # Create output port in TOP with new net
            my $newPortTop = $TopDie_TopMod->new_port(
                            name=>$newNetName,
                            direction=>"output",
                            data_type=>$net->data_type,
                            module=>$TopDie_TopMod,
                            net=>$newNetTop);

            # Assign new net to old net (or the opposite, don't remember)
            $TopDie_TopMod->new_contassign(
                            keyword=>"assign",
                            lhs=>$newNetName,# New
                            rhs=>$net->name, # Old
                            module=>$TopDie_TopMod
                            );

            # Create an input port in BOT with new net
            my $newNetBot = $BotDie_TopMod->new_net(
                            name=>$newNetName,
                            array=>$net->array,
                            data_type=>$net->data_type,
                            module=>$BotDie_TopMod,
                            net_type=>"input",# Need to specify the type as the port is not created yet.
                            comment=>"// Split net");
            my $newPortBot = $BotDie_TopMod->new_port(
                            name=>$newNetName,
                            direction=>"input",
                            data_type=>$net->data_type,
                            module=>$BotDie_TopMod,
                            # Ref to the new net. Actually matters, as it's the net referenced when instanciating the module instance. In fact, it should have the same name as the toplevel connecting wire.
                            net=>$newNetBot);
            

            # Find the sink pin connected to the old net
            my $botCell = $BotDie_TopMod->find_cell($netsSplitSource{$key}[$i]);
            if (defined $botCell) {
                print STDOUT "Found sink cell on the bottom: $botCell\n";
            }
            else {
                print STDOUT "Did not find the sink cell on the bottom, there might be a problem.\n";
            }
            # foreach my $c ($BotDie_TopMod->cells) {
            #     my $cellname = $c->name;
            #     print STDOUT "'$cellname'\n";
            # }
            

            # Change its netselection to the new net
            foreach my $pin (values %{$botCell->_pins}) {
                foreach my $pinselect ($pin->pinselects) {
                    # Get the raw name of the net connected to the pin
                    my $pinselectnetname = $pinselect->netname;
                    print STDOUT "pinselectnetname: $pinselectnetname\n";
                    my $isConcat = 0;
                    my $replace = 0;
                    # Check if the net is a concatenation, i.e. surrounded with {}
                    if ($pinselectnetname =~ /\{.*\}/) {
                        $pinselectnetname =~ s/(^\{)|(\}$)//g;
                        $isConcat = 1;
                    }
                    # Split at the ','. If not a concatenation, changes nothing.
                    my @netnames = split(',',   $pinselectnetname);
                    my @newNetNames = ();
                    foreach my $netname (@netnames) {
                        # If the net has the name of the old one, change it and mark the pin to be replaced.
                        if ($netname eq $net->name) {
                            push @newNetNames, $newNetName;
                            $replace = 1;
                        }
                        else {
                            push @newNetNames, $netname;
                        }
                    }
                    # Rejoin the nets in case of a concatenation.
                    my $newPinselectName = join(",", @newNetNames);
                    $newPinselectName = "\{${newPinselectName}\}" if $isConcat;
                    # If marked for replacement, delete the old pin and create a new one, in that order.
                    if ($replace) {
                        my @pinselectArr = ();
                        my $pinselect = new Verilog::Netlist::PinSelection($newPinselectName);
                        push @pinselectArr, $pinselect;
                        my $pinName = $pin->name;
                        $pin->delete;
                        $botCell->new_pin(
                                    cell=>$botCell,
                                    module=>$BotDie_TopMod,
                                    name=>$pinName,
                                    portname=>$pinName,
                                    netlist=>$nl_Bot,
                                    _pinselects=>\@pinselectArr
                                    );
                    }
                }
            }

            # Create a wire in toplevel with new net
            my $toplevelNet = $TopLevel_TopMod->new_net(
                            array=>$net->array,
                            data_type=>$net->data_type,
                            module=>$TopLevel_TopMod,
                            name=>$newNetName,
                            comment=>"//3D net"
                            );
        }
    }

}



$progress = Term::ProgressBar->new({ count => scalar $TopDie_TopMod->cells,
                                        name => "Replacing pins",
                                        ETA => "linear",
                                        silent => 0});
foreach my $cell ($TopDie_TopMod->cells) {
    $progress->update();
    foreach my $pin (values %{$cell->_pins}) {
        my $dbg_str = 0;
        # if ($pin->name eq "be_i") {
        if ($cell->name eq "i_tile_i_snitch_icache_i_lookup_valid_q_reg") {
            $dbg_str = 1;
        }
        $log->msg(5, "Inside cell i_tile_i_snitch_icache_i_lookup_valid_q_reg") if $dbg_str;
        foreach my $pinselect ($pin->pinselects) {
            # If at least one net connected to the pin is of the renamed port, change the pin.
            my $isConcat = 0;
            my $pinselectnetname = $pinselect->netname;
            $log->msg(5, "pinselectnetname = '$pinselectnetname'") if $dbg_str;

            # If this pin is connected to a concatenation
            if ($pinselectnetname =~ /\{.*\}/) {
                $pinselectnetname =~ s/(^\{)|(\}$)//g;
                $isConcat = 1;
            }
            my @netnames = split(',',   $pinselectnetname);
            my @newNetNames = ();
            if ($isConcat) {
                $log->msg(5, "This is a concatenation, get to work.") if $dbg_str;
                foreach my $net (@netnames) {
                    my $fullBusWireName = $net;
                    my $newNetName = $net;
                    $log->msg(5, "net name = '$net'") if $dbg_str;
                    if (my @matches = $net =~ /\[(\d+)\]/g) {
                        my $busWire = $+;
                        $fullBusWireName =~ s/\[([^\[\]]|(?0))*]$//g; # Only remove the ending brackets. There might be some *inside* the net name, but those are part of its name and should not be removed.
                        $fullBusWireName =~ s/^\\//g;
                        $fullBusWireName =~ s/ $//g;
                        $log->msg(5, "stripped fullBusWireName = '$fullBusWireName'") if $dbg_str;
                        # If this net is actually already a bus wire, don't append the "_wire" part a second time.
                        if ($fullBusWireName =~ /_wire $/) {
                            $fullBusWireName = $net;
                            $log->msg(5, "already a bus wire, back to the original") if $dbg_str;
                        }
                        else {
                            my $netNameOnlyStripped = $fullBusWireName;
                            $netNameOnlyStripped =~ s/ $//g;
                            $fullBusWireName = "\\${netNameOnlyStripped}_wire[${busWire}] ";
                        }
                        $log->msg(5, "fullBusWireName = '$fullBusWireName'") if $dbg_str;
                    }
                    my $newPort = $newports{$net};
                    if (!defined $newPort) {
                        $log->msg(5, "Did not find a port with '$net'") if $dbg_str;
                        $newPort = $newports{$fullBusWireName};
                    }
                    if (defined $newPort) {
                        $log->msg(5, "Found a port with '$fullBusWireName'") if $dbg_str;
                        my $newNet = $newPort->net;
                        $newNetName = $newNet->name;
                    }
                    push @newNetNames, $fullBusWireName;
                }
                # Once we are done scanning the concatenation, merge the update and create a new pin.
                my $pinname = $pin->name;
                $pin->delete; # If this fails, maybe a link() is missing somewhere.
                # New name for the concatenation
                my $newPinselectName = join(",", @newNetNames);
                $newPinselectName = "\{${newPinselectName}\}";
                $log->msg(5, "New badass concatenation name: '$newPinselectName'") if $dbg_str;

                my $pinselect = new Verilog::Netlist::PinSelection($newPinselectName);
                my @pinselectArr = ();
                push @pinselectArr, $pinselect;
                my $newpin = $cell->new_pin(
                                    cell=>$cell,
                                    module=>$TopDie_TopMod,
                                    name=>$pinname,
                                    # nets=>$ft_net, # this should be done through link()
                                    portname=>$pinname,
                                    # port=>$newPort,
                                    netlist=>$nl_Top,
                                    _pinselects=>\@pinselectArr
                                    );
                # $TopDie_TopMod->link(); # comment to speedup
                my $newpinname = $newpin->name;
                $log->msg(5, "New pin name: $newpinname connected to $newPinselectName");
            }
            # Not a concatenation
            else {
                $pinselectnetname =~ s/\[([^\[\]]|(?0))*]//g;
                my $fullBusWireName = "";
                if ($pinselect->netname =~ /\[(\d+)\]/) {
                    my $busWire = $1;
                    my $pinselectnetnameStripped = $pinselectnetname;
                    $pinselectnetnameStripped =~ s/ $//g;
                    $pinselectnetnameStripped =~ s/^\\//g;
                    $fullBusWireName = "\\${pinselectnetnameStripped}_wire[${busWire}] ";
                    $log->msg(5, "fullBusWireName = '$fullBusWireName'") if $dbg_str;
                }
                my $newPort = $newports{$pinselectnetname};
                if (!defined $newPort) {
                    $log->msg(5, "Did not find a port with '$pinselectnetname'") if $dbg_str;
                    $newPort = $newports{$fullBusWireName};
                    if (defined $newPort) {
                        $log->msg(5, "Found a port with '$fullBusWireName'") if $dbg_str;
                        my $pinname = $pin->name;
                        # print STDOUT "Comparing $pinname and $oldportname\n";
                        # $log->msg(5, "About to delete pin $pinname because it was connected to $oldportname");
                        # Delete the old pin
                        # print STDOUT Dumper($pin);
                        $pin->delete; # If this fails, maybe a link() is missing somewhere.
                        # Create a new pin
                        my $ft_net = $newPort->net;

                        # Build the name of the net by extracting the possible bus range.
                        my $msb = $ft_net->msb;
                        my $lsb = $ft_net->lsb;
                        if ($pinselect->netname =~ m/\[(\d+):?([\d]*)\]/){
                            $msb = $1;
                            $lsb = $2;
                            # print STDOUT "It's a bus right there! msb: '$msb', lsb: '$lsb'\n";
                        }
                        if ($lsb eq ""){
                            $lsb = $msb;
                        }

                        my $ftnetname = $ft_net->name;
                        my $pinselect = new Verilog::Netlist::PinSelection($ft_net->name, $msb, $lsb);
                        my @pinselectArr = ();
                        push @pinselectArr, $pinselect;
                        my $newpin = $cell->new_pin(
                                            cell=>$cell,
                                            module=>$TopDie_TopMod,
                                            name=>$pinname,
                                            # nets=>$ft_net, # this should be done through link()
                                            portname=>$pinname,
                                            # port=>$newPort,
                                            netlist=>$nl_Top,
                                            _pinselects=>\@pinselectArr
                                            );
                        # $TopDie_TopMod->link(); # comment to speedup
                        my $newpinname = $newpin->name;
                        $log->msg(5, "New pin name: $newpinname connected to $ftnetname");
                        # Go on with the next pin.
                        last;
                    }
                }
                else {
                  # A port with the same name as the net exists, this might be a feedthrough.
                  my $portName = $newPort->name;
                  $log->msg(5, "Found port named '$portName' for netname '$pinselectnetname'");
                  if ($portName ne $pinselectnetname) {
                    # This is indeed a feedthrouhg, replace the net name connected to the pin with the name of the port.
                    $log->msg(5, "'$pinselectnetname' is a feedthrough previously called '$portName'");

                    my $pinname = $pin->name;
                    # Delete the old pin
                    $pin->delete; # If this fails, maybe a link() is missing somewhere.
                    # Create a new pin
                    my $ft_net = $newPort->net;

                    # Build the name of the net by extracting the possible bus range.
                    my $msb = $ft_net->msb;
                    my $lsb = $ft_net->lsb;
                    if ($pinselect->netname =~ m/\[(\d+):?([\d]*)\]/){
                        $msb = $1;
                        $lsb = $2;
                    }
                    if ($lsb eq ""){
                        $lsb = $msb;
                    }

                    my $ftnetname = $ft_net->name;
                    my $pinselect = new Verilog::Netlist::PinSelection($ft_net->name, $msb, $lsb);
                    my @pinselectArr = ();
                    push @pinselectArr, $pinselect;
                    my $newpin = $cell->new_pin(
                                        cell=>$cell,
                                        module=>$TopDie_TopMod,
                                        name=>$pinname,
                                        portname=>$pinname,
                                        netlist=>$nl_Top,
                                        _pinselects=>\@pinselectArr
                                        );
                    my $newpinname = $newpin->name;
                    $log->msg(5, "New pin name: $newpinname connected to $ftnetname");


                  }
                }
            }
        }  
    }
}
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

$log->msg(2, "<=== Done ! ");

$log->msg(2, "Creating pins in top and bottom instanciations in toplevel.");

$progress = Term::ProgressBar->new({ count => scalar $BotDie_TopMod->ports,
                                        name => "Toplevel: creating pins in bottom module",
                                        ETA => "linear",
                                        silent => 0});
foreach my $port ($BotDie_TopMod->ports){
    $progress->update();
    my $portName = $port->name;
    my $portNet = $port->net;
    my $pinselect = new Verilog::Netlist::PinSelection($portNet->name, $portNet->msb, $portNet->lsb);
    my @pinselectArr = ($pinselect);
    $botdiecell->new_pin(
                    cell=>$botdiecell,
                    module=>$BotDie_TopMod,
                    name=>$port->name,
                    nets=>$port->net,
                    portname=>$port->name,
                    port=>$port,
                    netlist=>$nl_toplevel,
                    _pinselects=>\@pinselectArr
                    );
}
$nl_toplevel->link();

$progress = Term::ProgressBar->new({ count => scalar $TopDie_TopMod->ports,
                                        name => "Toplevel: creating pins in top module",
                                        ETA => "linear",
                                        silent => 0});
foreach my $port ($TopDie_TopMod->ports){
    $progress->update();
    my $portName = $port->name;
    $log->msg(5, "Top die, working on port '$portName'");
    my $portNet = $port->net;
    my $pinselect = new Verilog::Netlist::PinSelection($portNet->name, $portNet->msb, $portNet->lsb);
    my @pinselectArr = ($pinselect);
    my $tmppin = $topdiecell->new_pin(
                    cell=>$topdiecell,
                    module=>$TopDie_TopMod,
                    name=>$port->name,
                    nets=>$port->net,
                    portname=>$port->name,
                    port=>$port,
                    netlist=>$nl_toplevel,
                    _pinselects=>\@pinselectArr
                    );
}
$nl_toplevel->link();

# Write assignements
foreach my $lhs (keys %assignements) {
    $BotDie_TopMod->new_contassign(keyword=>"assign",
                                lhs=>$lhs,
                                rhs=>$assignements{$lhs},
                                module=>$BotDie_TopMod
                                );
}
#
# Write netlists
$log->msg(2, "===> ");
$log->msg(2, "Write netlists: ");
write_nl($nl_Top,"./$root/Top.v");
write_nl($nl_Bot,"./$root/Bot.v");
write_nl($nl_toplevel,"./$root/toplevel.v");
$log->msg(2, "<=== Done! ");

my $numberOf3DNets = keys %nets3D;
my $numberOfFT = keys %netsFT;
$log->msg(2, "Congrats, you now have a 3D design with $numberOf3DNets 3D wires and $numberOfFT feedthroughs.");
$log->msg(3, "3D nets:");
foreach my $netname (keys %nets3D) {
    $log->msg(3, "$netname");
}
$log->msg(3, "Feedthroughs:");
foreach my $netname (keys %netsFT) {
    $log->msg(3, "$netname");
}

$log->msg(3, "Skipped 3D nets: $skippedNets.");

## Dump netlists 
#my $fh_Top = IO::File->new('./output/Top.dmp', "w") or die "%Error: $! creating Top dump file,";
#select $fh_Top;
#$nl_Top->dump;
#close $fh_Top;
#
#my $fh_org = IO::File->new('./output/Org.dmp', "w") or die "%Error: $! creating Original dump file,";
#select $fh_org;
#$nl->dump;
#close $fh_org;


#=============================================================================================
sub CreateNewModule {
    my $nl = shift;
    my $mod = shift;
    my $f = shift;
    
    $nl->new_module (   name=>$mod,
                        @fl);
}

#=============================================================================================
sub AddPortToModule {
my $nl   = shift;
my $mod  = shift;
my $port = shift;
my $f    = shift;
    
    $nl->mod ( name=>$port, 
                        @fl);
}

#=============================================================================================
sub DeleteCell {
my $module = shift;
my $cell = shift;
my $fl = shift;

my $foundCell=$module->find_cell($cell->name);
my $cellName = $cell->name;
if (! defined $foundCell) {$log->msg(2, "Could not delete cell: $cellName ");}
    else
        {
            $foundCell->delete;
            $log->msg(3, "Deleted cell: $cellName ");
        }
}

#=============================================================================================
sub AddCell {
my $module = shift;
my $cell   = shift;
my $fl     = shift;

my $submodname = $cell->submodname;

my $cellAdded=$module->new_cell(
                            name=>$cell->name,
                            submodname=>$cell->submodname,
                            _pins=>$cell->_pins,
                            @fl);
my $cellName = $cell->name;
if (! defined $cellAdded) {$log->msg(2, "Could not add cell: $cellName ");}
else
    {
    my $cellAddedName = $cellAdded->name;
    $log->msg(3, "Cell added: $cellAddedName ");
    $log->msg(3, "Submodname: $submodname");
    }
}

#=============================================================================================
sub isNet3D {
    my $netToFind = shift;
    my ($InstancesToMove) = @_;

    # my %InstancesToMove_tmp = map { $_ => 1 } @$InstancesToMove;
    
    my @ConnectedCells;
    my $Is3DNet=0;
    my $cellName=""; 
    
    $log->msg(4, "$indent $indent $indent $indent $indent $indent Net: $netToFind is connected to cells:");
    unless (exists $hashNetCell{$netToFind}) {
        $log->msg(4, "Net does not exist in hashNetCell!");
    }
    
    foreach my $cellName (@{$hashNetCell{$netToFind}}) {
        $cellName=~ s/\s//g;
        $cellName=~ s/\\//g; # Remove escaping characters
        my $tmp= quotemeta $cellName;

        # Put in the array
        push @ConnectedCells, $tmp;
        #debug
        $log->msg(4, "$indent $indent $indent $indent $indent $indent $indent cell: $tmp ___");
    }

    
    # Compare cells of the net and those that should move
    my $count=0;
    # OUTER : # loop label for last
    # foreach my $cell (@ConnectedCells) {
    #     foreach my $cellToMove (@$InstancesToMove) {
    #         if ($cell eq $cellToMove) { 
    #             #$log->msg(2, $indent x 7, "Equal: cell on net: ", $cell, " , & cell to move: ", $cellToMove, "");
    #             $count=$count+1; 
    #             }
    #             else {
    #                 $log->msg(4, "$indent $indent $indent $indent $indent $indent $indent Diff. cell on net: $cell, & cell to move: $cellToMove");
    #                 # single cell on another die will cause 
    #                 # this net to become 3D net
    #                 # saves computational time
    #                 last OUTER;
    #             }
    #         }
    #     }

    OUTER : # loop label for last
    foreach my $cell (@ConnectedCells) {
        if(!exists($InstancesToMove_hash{$cell})) {
            $count = $count+1;
            $Is3DNet = 1;
            # single cell on another die will cause 
            # this net to become 3D net
            # saves computational time
            last OUTER;
        }
        # else {
        #     # $log->msg(4, "$indent $indent $indent $indent $indent $indent $indent Diff. cell on net: $cell, & cell to move: $cellToMove");
        # }
    }

    if ($Is3DNet) {
        $log->msg(4, "$indent $indent $indent $indent $indent $indent Is 3D net");
        $nets3D{$netToFind} = 1;
    }
    else {
        $log->msg(4, "$indent $indent $indent $indent $indent $indent Is 2D net");
    }
        
    # # Finally figure out if it is a 2D net
    # my $arraySize = @ConnectedCells;
    # # $log->msg(2, "$indent $indent $indent $indent $indent $indent $indent Count: $count Array size: $arraySize ");
    # if ($count == $arraySize) { # all cells are on the top die
    #     $Is3DNet=0;
    #     $log->msg(4, "$indent $indent $indent $indent $indent $indent Is 2D net");
    #     } # if not it is a 3D net
    #     else {
    #         $Is3DNet=1;
    #         $log->msg(4, "$indent $indent $indent $indent $indent $indent Is 3D net");
    #     }
    return ($Is3DNet);
}


sub pinDirection {
    my $instance = shift;
    my $pin = shift;
    my $intsanceName = $instance->name;
    my $macroTofind = $instance->submodname;
    my $pinTofind   = $pin->name;
    my $pindir = $LEF->find_pindir($macroTofind,$pinTofind);
    # only lower case  
    my $pindir_lc= lc $pindir;
    $log->msg(5, "Instance $intsanceName of macro $macroTofind, on pin $pinTofind is of dir $pindir_lc");
    return $pindir_lc;
}

#=============================================================================================
sub dumpNetCells {
my $TopModule = shift;
my $netname   = shift;

my @NetCellNames;

# Get rid of brackets if array
my $netNameOnly = $netname;
$netNameOnly=~ s/\[([^\[\]]|(?0))*]//g;

foreach my $cell ($TopModule->cells) 
    {
    foreach my $pin ($cell->pins) 
        {
        foreach my $pinselect ($pin->pinselects) 
            {
            if ($pinselect->netname eq $netNameOnly) {
#                push @NetPinNames, $netNameOnly;
                push @NetCellNames, $cell->name;
                }
            }
        }
    }    
return (@NetCellNames);
}

#=============================================================================================
sub write_nl {
    my $nl = shift;
    my $file_name = shift;
    
    # Prepare file to write 
    $nl->link;
    my $fh = IO::File->new($file_name, "w") or die "%Error: $! creating dump file,";
    print $fh $nl->verilog_text;
    $fh->close;
}

#=============================================================================================
sub LinkNetCells {
    # First add all the nets as keys into the hash
    # This is probably dumb and useless. We create empty entries with keys that are actually objects. They are probably not used afterward.
    # foreach my $net ($TopModule->nets) {
    #     $hashNetCell{$net} = ();
    # }

    # Then, for each net, find all its cells and add their name into its array.
    foreach my $cell ($TopModule->cells) {
        foreach my $pin ($cell->pins) {
            foreach my $pinselect ($pin->pinselects) {
                my $netname = $pinselect->netname;
                # $netname =~ s/\s//g;
                my $cellname = $cell->name;
                push @{$hashNetCell{$netname}}, $cell->name;
                # $log->msg(3, "adding $cellname to $netname");
            }
        }
    }

    foreach my $net (keys %hashNetCell) {
        $log->msg(3, "=> In net '$net', we have:");
        foreach my $cell (@{$hashNetCell{$net}}) {
            $log->msg(3, "  -> '$cell'");
        }
    }

}

#=============================================================================================
# For each bus of width n in the design, create n wires that can be routed individually in 3D.
# This is to avoid having whole 3D buses when only a few wires in it should be.
sub splitBuses {

    my $module = shift;
    my $isBus = 0;

    my $progress = Term::ProgressBar->new({ count => scalar $module->nets,
                                        name => "Splitting bus",
                                        ETA => "linear",
                                        silent => 0});

    foreach my $net ($module->nets) {
        $progress->update();

        # If and MSB is defined for the net, this must be a bus.
        $isBus = 0;
        if (defined $net->msb) {
            $isBus = 1;
        }
        if ($isBus) {

            # Need a net_type to prepend to the name. One of wire, input or output.
            # The nettype of the split bus will always be a plain wire, the bus itself keeping the direction information.
            my $netType = "wire";

            for(my $i=$net->lsb;  $i<=$net->msb; $i++) {
                my $netNameStripped = $net->name;
                $netNameStripped =~ s/ $//g;
                $netNameStripped =~ s/^\\//g;
                my $netName = '\\'.$netNameStripped.'_wire['.$i.'] ';
                $log->msg(6, "Creating a new net called $netName");
                $module->new_net(width=>1,
                                module=>$net->module,
                                net_type=>$netType,
                                name=>$netName
                                );
                my $rhs = $net->name.'['.$i.']';
                $module->new_contassign(keyword=>"assign",
                                        lhs=>$netName,
                                        rhs=>$rhs,
                                        module=>$TopModule,
                                        netlist=>$nl_Bot
                                        );
            }
        }
    }
    foreach my $cell ($module->cells) {
        my $cellname = $cell->name;
        $log->msg(6, "Cell: $cellname");
        foreach my $pin ($cell->pins) {
            my $pinname = $pin->name;
            $log->msg(6, "Pin: $pinname");
            foreach my $pinselect ($pin->pinselects) {
                my $pinselectname = $pinselect->netname;
                # my $lsb = $pinselect->lsb; # Empty, thus useless
                # my $msb = $pinselect->msb; # Empty, thus useless
                $log->msg(6, "Pinselect: $pinselectname");
                # Get the lsb/msb if this is a bus such as imabus[2:0], where the msb is 2 and the lsb 0
                if ($pinselectname =~ m/(.*)\[(\d+):?(\d+)?\]$/) {
                    my $busName = $1;
                    my $msb = $2;
                    my $lsb = $3;
                    $log->msg(6, "Found my bus back! $busName, msb: '$msb', lsb: '$lsb'");
                    # Bus range, need to do a concatenation
                    if ($lsb ne '') {
                        $log->msg(6, "This bus has a range, we need to do a concatenation.");
                    }
                    else {
                        $lsb = $msb;
                    }
                    my $busnameStripped = $busName;
                    $busnameStripped =~ s/ $//g;
                    $busnameStripped =~ s/^\\//g;
                    my $pinselect = new Verilog::Netlist::PinSelection('\\'.$busnameStripped.'_wire['.$msb.'] ');
                    my @pinselectArr = ();
                    push @pinselectArr, $pinselect;
                    my $newpin = $cell->new_pin(
                                        cell=>$cell,
                                        module=>$module,
                                        name=>$pinname,
                                        portname=>$pinname,
                                        netlist=>$nl_Bot,
                                        _pinselects=>\@pinselectArr
                                        );
                    my $newpinname = $newpin->name;
                }
            }
        }
    }
}