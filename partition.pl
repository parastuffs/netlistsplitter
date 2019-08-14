#!/usr/bin/perl -w
use 5.010;
use strict;
use warnings;
# use diagnostics;
use Test::More;
# use lib '.';
use Verilog::Netlist;
use lib './lefParser';
use LEF;
use strict;use Data::Dumper;
use File::Log;

my $log = File::Log->new({
  debug           => 3,                   # Set the debug level
  logFileName     => 'splitterlog.log',   # define the log filename
  logFileMode     => '>',                 # '>>' Append or '>' overwrite
  dateTimeStamp   => 1,                   # Timestamp log data entries
  stderrRedirect  => 1,                   # Redirect STDERR to the log file
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

## iN7 
#my $root=("spc_iN7");
#my @VerilogFiles=("./$root/spc_flat_m.v");
#my $path_to_file = ("./$root/spc.prt");
#my $TopModuleName=("spc");

#my $root=("prt_spc_NoBuffers");
#my @VerilogFiles=("./$root/spc_NoBuffers.v");
#my $path_to_file = ("./$root/spc.prt");
#my $TopModuleName=("spc");

my $root=("prt_exu");
my @VerilogFiles=("./$root/exu_flat_m.v");
my $path_to_file = ("./$root/exu.prt");
my $TopModuleName=("exu");
#------------------------------------------------------------------------

#***************************************************************************
# Parse LEF file 
# Read LEF to get pin directions of macros 
my $LEF = LEF->new({name => "all",
                    file_name => "LEF/all.lef",
                   });

# Open file, get data & build internal data structures
$LEF->parse_LEF();

#***************************************************************************
# Process partition file  
# Get the list of instances to move on another die 

open my $handle, '<', $path_to_file;
my @InstancesToMoveIn;
my @lines = <$handle>;
foreach my $line (@lines){
    chomp $line;
    my @linesplit = split(' ', $line);
    if ($linesplit[1] == '1') {
        push(@InstancesToMoveIn, $linesplit[0]);
    }
}
close $handle;

my @InstancesToMove;
my @InstancesToMove_clean;

# Clean from nasty characters
foreach my $cellToMove (@InstancesToMoveIn) {
    push @InstancesToMove, $cellToMove;
    $cellToMove=~ s/\s//g;
    my $tmp = quotemeta $cellToMove;
    push @InstancesToMove_clean, $tmp;
}

#***************************************************************************
# Process NETLIST  
# Netlist should be flat and in a single file 

$log->msg(2, "===>");
$log->msg(2, " Reading netlits");

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

# Populate hash with net-cell associations
LinkNetCells();

# Create top module in top die 
my $TopDie_TopMod = CreateNewModule($nl_Top,'TopDie',@fl);

# Create top module in toplevel
my $TopLevel_TopMod = CreateNewModule($nl_toplevel, 'TopLevel', @fl);
$nl_Bot->link();

# Rename the top module in bot die 
my $BotDie_TopMod=$nl_Bot->find_module($TopModuleName);
if (! defined $TopModule) {$log->msg(2, "Could't find top module in bot die: $TopModuleName"); exit;}
    else
        {
        $log->msg(2, "Renaming top module of the bottom die: $TopModuleName");
        # $BotDie_TopMod->name='BotDie';
    }    

# foreach my $port ($TopModule->ports) {
#     my $portName = $port->name;
#    $log->msg(3, "Port: $portName");
#    # $port->dump;
# }


my $topdiecell = $TopLevel_TopMod->new_cell(name=>"top_die",
                        netlist=>$nl_toplevel,
                        submod=>$TopDie_TopMod,
                        submodname=>$TopDie_TopMod->name);

my $botdiecell = $TopLevel_TopMod->new_cell(name=>"bot_die",
                        netlist=>$nl_toplevel,
                        submod=>$BotDie_TopMod,
                        submodname=>$BotDie_TopMod->name);

# Copy ports from bottom die into toplevel.
foreach my $port ($TopModule->ports) {
    my $netname = $port->net->name;
    $log->msg(2, "netname in bottom port: $netname");
    $TopLevel_TopMod->new_port(data_type=>$port->data_type,
                            direction=>$port->direction,
                            module=>$TopLevel_TopMod,
                            name=>$port->name,
                            net=>$port->net,
                            array=>$port->array);
    # At the same time, copy linked net.
    my $botnet = $port->net;
    # my $tmpvar = $port->direction;
    # $log->msg(2, "bite: $tmpvar");
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

#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
foreach my $inst (@InstancesToMove) 
{
    $log->msg(2, "Searching instance: $inst");
    my $foundInst=$TopModule->find_cell($inst);
    if (! defined $foundInst) {$log->msg(5, "ERROR: can't find instance $inst <-");}
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

                        #my $tmp=$pinselect->netname;
                        #$tmp=~ s/\{//g;
                        #$tmp=~ s/\}//g;
                        #$tmp=~ s/\[([^\[\]]|(?0))*]//g;
                        #my @answer = split(',', $tmp);
                        #foreach (@answer) {$log->msg(5, "$_");}

                        my $netNameOnly = $pinselect->netname;
                        # Get rid of brackets if bus (array)
                        $netNameOnly=~ s/\[([^\[\]]|(?0))*]//g;
                        
                        #=======================================
                        # CASE 1
                        # Net is connected to a top-level port of the src netlist
                        # We look for the name only 
                        my $foundPort=$TopModule->find_port($netNameOnly);
                        if (defined $foundPort) 
                        {
                            my $foundPortName = $foundPort->name;
                            $log->msg(5, "$indent $indent $indent $indent Is top-level port: $foundPortName <-");
                            # If found, check if it has been already added
                            my $portInTop=$TopDie_TopMod->find_port($foundPortName); 
                            if (defined $portInTop) 
                                {
                                    $log->msg(5, "$indent $indent $indent $indent $indent Port: $foundPortName <- already added, skipping");}
                                else
                                {
                                # if not add port the Top die with same direction as in src netlist
                                my $newPort=$TopDie_TopMod->new_port(name=>$foundPort->name,
                                                    # direction is the same as top
                                                    direction=>$foundPort->direction,
                                                    data_type=>$foundPort->data_type,
                                                    array=>$foundPort->array,
                                                    module=>$TopDie_TopMod->name,
                                                    net=>$foundPort->net
                                                    );
                                my $foundPortDirection = $foundPort->direction;
                                $log->msg(5, "$indent $indent $indent $indent $indent Port: $foundPortName with dir: $foundPortDirection added to TopDie");
                                
                                # ... and to the Bottom die, we need to add 2 pins
                                # one with same direction and same name
                                # one with opposite direction so that we feedthrough
                                
                                # This is first pin 
                                # Since copy this one exists already

                                # This is the second pin with oposite direction
                                my $otherDieDirection="none";
                                if ($foundPort->direction eq "in") { $otherDieDirection="out"; }
                                if ($foundPort->direction eq "out") { $otherDieDirection="in"; }
                               
                                # This is a feedcthough so it has a different name
                                my $otherDiePortName=$foundPort->name;
                                $otherDiePortName="ft_$otherDiePortName";
                                my $newPort_Bot=$BotDie_TopMod->new_port(
                                                    #name=>$foundPort->name,
                                                    name=>$otherDiePortName,
                                                    #direction=>$foundPort->direction,
                                                    direction=>$otherDieDirection,
                                                    data_type=>$foundPort->data_type,
                                                    array=>$foundPort->array,
                                                    module=>$TopDie_TopMod->name,
                                                    net=>$foundPort->net
                                                    );
                                $log->msg(5, "$indent $indent $indent $indent $indent Port: $otherDiePortName with dir: $otherDieDirection added to Bot die");
                                }
                        }
                                                
                        #=======================================
                        # CASE 2
                        # Net is a wire  
                        my $foundNet=$TopModule->find_net($netNameOnly);
                        my $isBus=0;
                        my $netIs3D=0;
                       
                        if (defined $foundNet) {
                            my $foundNetName = $foundNet->name;
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
                                #$log->msg(5, Dumper($foundNet));
                                $netIs3D = isNet3D($foundNet->name, \@InstancesToMove_clean);
                           
                                if ($netIs3D == 0)  
                                # This is a local 2D wire    
                                {
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent Net: $foundNetName is 2D ");
                                    
                                    # Check if it has been already added
                                    my $netInTop=$TopDie_TopMod->find_port($netNameOnly); 
                                    if (defined $netInTop) 
                                        {$log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Wire already added, skipping: $netNameOnly ");}
                                    else
                                    {
                                            my $newNet=$TopDie_TopMod->new_net(name=>$netNameOnly,
                                                        array=>$foundNet->array,
                                                        data_type=>$foundNet->data_type,
                                                        module=>$TopDie_TopMod->name
                                                        );
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Wire (2D): $netNameOnly added to Top die");
                                    }
                                }
                                else 
                                # This is a 3D net
                                {
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent Net: $netNameOnly is 3D ");
                                       
                                    # Check if this net has been already added
                                    my $portInTop2=$TopDie_TopMod->find_port($netNameOnly); 
                                    if (defined $portInTop2) 
                                        {$log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Port already added, skipping: $netNameOnly ");}
                                    else
                                    # if not look for the LEF file to discover the direction
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
                                                            module=>$TopDie_TopMod->name,
                                                            net=>$foundNet
                                                    );
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent 3D wire port: $netNameOnly added to Top die");
                                
                                        # ... and to the Bottom die, with opposite direction
                                        my $otherDieDirection="none";
                                        if ($pindir_lc eq "input") { $otherDieDirection="output";}
                                        if ($pindir_lc eq "output") { $otherDieDirection="input";}
                                        
                                        my $newPort_Bot=$BotDie_TopMod->new_port(name=>$netNameOnly,
                                                            direction=>$otherDieDirection,
                                                            data_type=>$foundNet->data_type,
                                                            #array=>$foundPort->array,
                                                            module=>$TopDie_TopMod->name,
                                                            net=>$foundNet
                                                            );
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Port: $netNameOnly added to Bot die");
                                        $TopLevel_TopMod->new_net(name=>$netNameOnly,
                                                                data_type=>"",#wire
                                                                module=>$TopLevel_TopMod->name,
                                                                comment=>"// 3D net"
                                                                );
                                        
                                    }
                                }
                            }
                            else{
                            
                            # ---------------
                            # this is a bus
                                my $cnt = 0;
                                my $busIs3D = 0;
                                foreach my $busWire ($foundNet->lsb .. $foundNet->msb) {
                                    my $fullNetName = "$netNameOnly\[$busWire\]";
                                    
                                    # Check if this wire of the bus is 3D or not
                                    $netIs3D = isNet3D($fullNetName, \@InstancesToMove_clean);
                                    if ($netIs3D == 0) {
                                        # count to see if all nets are 2D
                                        $cnt = $cnt + 1; 
                                        } 
                                }
                                
                                if (($foundNet->msb - $foundNet->lsb) == $cnt) { $busIs3D = 0; }
                                    else { $busIs3D = 1; }

                                if ($busIs3D == 0)  
                                # This is a local 2D bus    
                                {
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent Bus: $netNameOnly is 2D bus");
                                    
                                    # Check if it has been already added
                                    my $netInTop=$TopDie_TopMod->find_port($netNameOnly); 
                                    if (defined $netInTop) 
                                        {$log->msg(5, "$indent $indent $indent $indent $indent $indent $indent Bus already added, skipping: $netNameOnly ");}
                                    else
                                    {
                                            my $newNet=$TopDie_TopMod->new_net(name=>$netNameOnly,
                                                        array=>$foundNet->array,
                                                        data_type=>$foundNet->data_type,
                                                        module=>$TopDie_TopMod->name
                                                        );
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent 2D local bus: $netNameOnly added to Top die");
                                    }
                                }
                                else 
                                # This is a 3D bus
                                {
                                    $log->msg(5, "$indent $indent $indent $indent $indent $indent Net: $netNameOnly is 3D bus");
                                       
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
                                                    module=>$TopDie_TopMod->name,
                                                    net=>$foundNet
                                                    );
                                    
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent 3D bus port: $netNameOnly added to Top die");

                                        # This is the second pin with oposite direction
                                        my $otherDieDirection="none";
                                        if ($pindir_lc eq "input")  { $otherDieDirection="output"; }
                                        if ($pindir_lc eq "output") { $otherDieDirection="input"; }
                                    
                                        # This is a feedthrough so it has a different name
                                        my $newPort_Bot=$BotDie_TopMod->new_port(
                                                            name=>$netNameOnly,
                                                            direction=>$otherDieDirection,
                                                            data_type=>$foundNet->data_type,
                                                            module=>$TopDie_TopMod->name,
                                                            net=>$foundNet
                                                            );
                                        $log->msg(5, "$indent $indent $indent $indent $indent $indent $indent 3D bus port: $netNameOnly with dir: $otherDieDirection added to Bot die");

                                        $TopLevel_TopMod->new_net(
                                                            name=>$netNameOnly,
                                                            data_type=>$foundNet->data_type,
                                                            module=>$TopLevel_TopMod->name,
                                                            comment=>"// 3D bus"
                                                            );
                                    }
                                }
                            }
                        }
            }
        
        }
    }
}
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

$log->msg(2, "<=== Done ! ");

$log->msg(2, "Creating pins in top and bottom instanciations in toplevel.");

foreach my $port ($BotDie_TopMod->ports){
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
    $nl_toplevel->link();
}

foreach my $port ($TopDie_TopMod->ports){
    my $portName = $port->name;
    my $portNet = $port->net;
    my $pinselect = new Verilog::Netlist::PinSelection($portNet->name, $portNet->msb, $portNet->lsb);
    my @pinselectArr = ($pinselect);
    $topdiecell->new_pin(
                    cell=>$topdiecell,
                    module=>$TopDie_TopMod,
                    name=>$port->name,
                    nets=>$port->net,
                    portname=>$port->name,
                    port=>$port,
                    netlist=>$nl_toplevel,
                    _pinselects=>\@pinselectArr
                    );
    $nl_toplevel->link();
}
#
# Write netlists
$log->msg(2, "===> ");
$log->msg(2, "Write netlists: ");
write_nl($nl_Top,"./$root/Top.v");
write_nl($nl_Bot,"./$root/Bot.v");
write_nl($nl_toplevel,"./$root/toplevel.v");
$log->msg(2, "<=== Done ! ");

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
            $log->msg(2, "Deleted cell: $cellName ");
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
    $log->msg(2, "Cell added: $cellAddedName ");
    $log->msg(3, "Submodname: $submodname");
    }
}

#=============================================================================================
sub isNet3D {
    my $netToFind = shift;
    my ($InstancesToMove) = @_;
    
    my @ConnectedCells;
    my $Is3DNet=0;
    my $cellName=""; 
    
    $log->msg(4, "$indent $indent $indent $indent $indent $indent Net: $netToFind is connected to cells:");
    
    foreach my $cellName (@{$hashNetCell{$netToFind}}) {
        $cellName=~ s/\s//g;                 
        my $tmp= quotemeta $cellName;

        # Put in the array
        push @ConnectedCells, $tmp;
        #debug
        $log->msg(4, "$indent $indent $indent $indent $indent $indent $indent cell: $tmp ___");
    }

    
    # Compare cells of the net and those that should move
    my $count=0;
    OUTER : # loop label for last
    foreach my $cell (@ConnectedCells) {
        foreach my $cellToMove (@$InstancesToMove) {
            if ($cell eq $cellToMove) { 
                #$log->msg(2, $indent x 7, "Equal: cell on net: ", $cell, " , & cell to move: ", $cellToMove, "");
                $count=$count+1; 
                }
                else {
                    $log->msg(4, "$indent $indent $indent $indent $indent $indent $indent Diff. cell on net: $cell, & cell to move: $cellToMove");
                    # single cell on another die will cause 
                    # this net to become 3D net
                    # saves computational time
                    last OUTER;
                }
            }
        }
        
    # Finally figure out if it is a 2D net
    my $arraySize = @ConnectedCells;
    # $log->msg(2, "$indent $indent $indent $indent $indent $indent $indent Count: $count Array size: $arraySize ");
    if ($count == $arraySize) { # all cells are on the top die
        $Is3DNet=0;
        $log->msg(4, "$indent $indent $indent $indent $indent $indent Is 2D net");
        } # if not it is a 3D net
        else {
            $Is3DNet=1;
            $log->msg(4, "$indent $indent $indent $indent $indent $indent Is 3D net");
        }
    return ($Is3DNet);
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
    
    # Preapre file to write 
    $nl->link;
    my $fh = IO::File->new($file_name, "w") or die "%Error: $! creating dump file,";
    print $fh $nl->verilog_text;
    $fh->close;
}

#=============================================================================================
sub LinkNetCells {
    # First add all the nets as keys into the hash
    foreach my $net ($TopModule->nets) {
        $hashNetCell{$net} = ();
    }

    # Then, for each net, find all its cells and add their name into its array.
    foreach my $cell ($TopModule->cells) {
        foreach my $pin ($cell->pins) {
            foreach my $pinselect ($pin->pinselects) {
                push @{$hashNetCell{$pinselect->netname}}, $cell->name;
            }
        }
    }
}