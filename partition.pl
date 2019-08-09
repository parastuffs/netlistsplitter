#!/usr/bin/perl -w
use 5.010;
use strict;
use Test::More;
use Verilog::Netlist;
use lib './lefParser';
# use Macro;
use lib './lefParser';
use LEF;
use strict;use Data::Dumper;

print "*******************************************\n";
print "Splitting netlist\n";
print "*******************************************\n";

# Setup options so files can be found
use Verilog::Getopt;
my $opt = new Verilog::Getopt;
$opt->parameter( "+incdir+verilog", "-y","verilog",);

# Prepare netlist
my $nl =  new Verilog::Netlist (options => $opt, link_read_nonfatal=>1,);
my $nl_Top = new Verilog::Netlist (options => $opt, link_read_nonfatal=>1,);
my $nl_Bot = new Verilog::Netlist (options => $opt, link_read_nonfatal=>1,);

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
my $root=("prt_spc");
my @VerilogFiles=("./$root/spc_flat_m.v");
my $path_to_file = ("./$root/spc.prt");
my $TopModuleName=("spc");

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
chomp(my @InstancesToMoveIn = <$handle>);
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

print "===>";
print " Reading netlits\n";

foreach my $file (@VerilogFiles) {
    $nl->read_file (filename=>$file);
    $nl_Bot->read_file (filename=>$file);
}
$nl->link();            # Read in any sub-modules
#$nl->lint();           # Optional, see docs; probably not wanted
$nl->exit_if_error();
print "<=== Done !\n";

# Find top module in src netlist
print "===>";
print " Searching Top module\n";
my $TopModule=$nl->find_module($TopModuleName);
if (defined $TopModule) {
    printf("Found top module %s\n", $TopModuleName);
    print "<=== Done !\n";
    } 
else {printf("Could't find top module %s\n", $TopModuleName);exit;}

# Populate hash with net-cell associations
LinkNetCells();

# Create top module in top die 
my $TopDie_TopMod = CreateNewModule($nl_Top,'TopDie',@fl);

# Rename the top module in bot die 
my $BotDie_TopMod=$nl_Bot->find_module($TopModuleName);
if (! defined $TopModule) {print "Could't find top module in bot die:", $TopModuleName," \n"; exit;}
    else
        {
        printf("Renaming top module of the bottom die: %s\n", $TopModuleName);
        #$BotDie_TopMod->name='BotDie';
    }    

#foreach my $port ($TopModule->ports) {
##    print "Port: ", $port->name, " \n";
#    $port->dump;
#}

#*****************************************************************************************************************
# ----->
# Create Top die from scratch and
# for all instances that we need to move 

print "===>";
print "Splitting: \n";
print "...\n\n";
my $indent="   ";

#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
foreach my $inst (@InstancesToMove) 
{
    print $indent x 0, "Searching instance:", $inst, "\n";
    my $foundInst=$TopModule->find_cell($inst);
    if (! defined $foundInst) {print "ERROR: can't find instance", $inst, "<-\n";}
    else {
            print $indent x 1, "Found instance:", $foundInst->name, "<-\n";
            # Add this cell to TopDie netlist
            AddCell($TopDie_TopMod, $foundInst, @fl);
            DeleteCell($BotDie_TopMod, $foundInst, @fl);

            # Go through all pins of this instance 
                foreach my $pin ($foundInst->pins) 
                {
                    # Get pin direction
                    # my $thisPinDirection=$pin->direction;
                    print $indent x 2,"Pin:", $pin->name,"<-\n";
                    
                    # Get net(s) connected to this pin
                    foreach my $pinselect ($pin->pinselects)
                    {
                        print $indent x 3, "Net:",$pinselect->netname, "<-\n";

                        #my $tmp=$pinselect->netname;
                        #$tmp=~ s/\{//g;
                        #$tmp=~ s/\}//g;
                        #$tmp=~ s/\[([^\[\]]|(?0))*]//g;
                        #my @answer = split(',', $tmp);
                        #foreach (@answer) {print "$_\n";}

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
                            print $indent x 4, "Is top-level port:", $foundPort->name,"<-\n";
                            # If found, check if it has been already added
                            my $portInTop=$TopDie_TopMod->find_port($foundPort->name); 
                            if (defined $portInTop) 
                                {print $indent x 5, "Port: ", $foundPort->name,"<- already added, skipping\n";}
                                else
                                {
                                # if not add port the Top die with same direction as in src netlist
                                my $newPort=$TopDie_TopMod->new_port(name=>$foundPort->name,
                                                    # direction is the same as top
                                                    direction=>$foundPort->direction,
                                                    data_type=>$foundPort->data_type,
                                                    array=>$foundPort->array,
                                                    module=>$TopDie_TopMod->name
                                                    );
                                print $indent x 5, "Port: ", $foundPort->name," with dir:",$foundPort->direction," added to TopDie\n";
                                
                                # ... and to the Bottom die, we need to add 2 pins
                                # one with same direction and same name
                                # one with opposite direction so that we feedthrough
                                
                                # This is first pin 
                                # Since copy this one exists already 

                                # This is the second pin with oposite direction
                                my $otherDieDirection="none";
                                if ($foundPort->direction eq "in") { $otherDieDirection="output"; }
                                if ($foundPort->direction eq "out") { $otherDieDirection="input"; }
                               
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
                                                    module=>$TopDie_TopMod->name
                                                    );
                                print $indent x 5, "Port: ",$otherDiePortName, " with dir:",$otherDieDirection," added to Bot die\n";
                                }
                        }
                                                
                        #=======================================
                        # CASE 2
                        # Net is a wire  
                        my $foundNet=$TopModule->find_net($netNameOnly);
                        my $isBus=0;
                        my $netIs3D=0;
                       
                        if (defined $foundNet) {
                            print $indent x 4, "Net is top-level wire:", $foundNet->name, "<-\n"; 
                            if ( defined $foundNet->msb ) {
                                $isBus=1;
                                print $indent x 5, " MSB:", $foundNet->msb, " LSB:", $foundNet->lsb, "<-\n";
                                }
                                else {
                                    $isBus=0;
                                }
                            if ($isBus == 0) {
                                #print Dumper($foundNet);
                                $netIs3D = isNet3D($foundNet->name, \@InstancesToMove_clean);
                           
                                if ($netIs3D == 0)  
                                # This is a local 2D wire    
                                {
                                    print $indent x 6, "Net: ", $foundNet->name," is 2D \n";
                                    
                                    # Check if it has been already added
                                    my $netInTop=$TopDie_TopMod->find_port($netNameOnly); 
                                    if (defined $netInTop) 
                                        {print $indent x 7, "Wire already added, skipping: ", $netNameOnly," \n";}
                                    else
                                    {
                                            my $newNet=$TopDie_TopMod->new_net(name=>$netNameOnly,
                                                        array=>$foundNet->array,
                                                        data_type=>$foundNet->data_type,
                                                        module=>$TopDie_TopMod->name
                                                        );
                                        print $indent x 7, "Wire (2D): ", $netNameOnly," added to Top die\n";
                                    }
                                }
                                else 
                                # This is a 3D net
                                {
                                    print $indent x 6, "Net: ", $netNameOnly," is 3D \n";
                                       
                                    # Check if this net has been already added
                                    my $portInTop2=$TopDie_TopMod->find_port($netNameOnly); 
                                    if (defined $portInTop2) 
                                        {print $indent x 7, "Port already added, skipping: ", $netNameOnly," \n";}
                                    else
                                    # if not look for the LEF file to discover the direction
                                    {
                                        print  $indent x 8, "Inst. name: ",$foundInst->name," Module name: ",$foundInst->submodname, " Pin:", $pin->name, "\n";
                                        my $macroTofind = $foundInst->submodname;
                                        my $pinTofind   = $pin->name;
                                        my $pindir = $LEF->find_pindir($macroTofind,$pinTofind);
                                        # only lower case  
                                        my $pindir_lc= lc $pindir;
                                        
                                        print $indent x 8,"Macro: ", $macroTofind, " with ", " Pin: ", $pinTofind," Pindir: ", $pindir_lc, " \n ";
                                       
                                       #----------------------------------------------------------------
                                       # Add ports                                                      |
                                       #                                                                |
                                        my $newPort=$TopDie_TopMod->new_port(name=>$netNameOnly,
                                                            direction=>$pindir_lc,
                                                            data_type=>$foundNet->data_type,
                                                            #array=>$foundPort->array,
                                                            module=>$TopDie_TopMod->name
                                                    );
                                        print $indent x 7, "3D wire port: ", $netNameOnly," added to Top die\n";
                                
                                        # ... and to the Bottom die, with opposite direction
                                        my $otherDieDirection="none";
                                        if ($pindir_lc eq "input") { $otherDieDirection="output";}
                                        if ($pindir_lc eq "output") { $otherDieDirection="input";}
                                        
                                        my $newPort_Bot=$BotDie_TopMod->new_port(name=>$netNameOnly,
                                                            direction=>$otherDieDirection,
                                                            data_type=>$foundNet->data_type,
                                                            #array=>$foundPort->array,
                                                            module=>$TopDie_TopMod->name
                                                            );
                                        print $indent x 7, "Port: ", $netNameOnly," added to Bot die\n";
                                        
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
                                    print $indent x 6, "Bus: ", $netNameOnly," is 2D \n";
                                    
                                    # Check if it has been already added
                                    my $netInTop=$TopDie_TopMod->find_port($netNameOnly); 
                                    if (defined $netInTop) 
                                        {print $indent x 7, "Bus already added, skipping: ", $netNameOnly," \n";}
                                    else
                                    {
                                            my $newNet=$TopDie_TopMod->new_net(name=>$netNameOnly,
                                                        array=>$foundNet->array,
                                                        data_type=>$foundNet->data_type,
                                                        module=>$TopDie_TopMod->name
                                                        );
                                        print $indent x 7, "2D local bus:", $netNameOnly," added to Top die\n";
                                    }
                                }
                                else 
                                # This is a 3D bus
                                {
                                    print $indent x 6, "Net: ", $netNameOnly," is 3D \n";
                                       
                                    # Check if this net has been already added
                                    my $portInTop2=$TopDie_TopMod->find_port($netNameOnly); 
                                    if (defined $portInTop2) 
                                        {print $indent x 7, "Port already added, skipping: ", $netNameOnly," \n";}
                                    else
                                    # if not look for the LEF file to discover the direction
                                    {
                                        my $macroTofind = $foundInst->submodname;
                                        my $pinTofind   = $pin->name;
                                        my $pindir = $LEF->find_pindir($macroTofind,$pinTofind);
                                        my $pindir_lc = lc $pindir;

                                        print $indent x 8, "Macro: ", $macroTofind, " with ", " Pin: ", $pinTofind, " Pindir: ", $pindir_lc, " \n ";
                                        
                                        # Top die 
                                        my $newPort=$TopDie_TopMod->new_port(name=>$netNameOnly,
                                                    # direction is the same as top
                                                    direction=>$pindir_lc,
                                                    data_type=>$foundNet->data_type,
                                                    module=>$TopDie_TopMod->name
                                                    );
                                    
                                        print $indent x 7, "3D bus port: ", $netNameOnly," added to Top die\n";

                                        # This is the second pin with oposite direction
                                        my $otherDieDirection="none";
                                        if ($pindir_lc eq "input")  { $otherDieDirection="output"; }
                                        if ($pindir_lc eq "output") { $otherDieDirection="input"; }
                                    
                                        # This is a feedcthough so it has a different name
                                        my $newPort_Bot=$BotDie_TopMod->new_port(
                                                            name=>$netNameOnly,
                                                            direction=>$otherDieDirection,
                                                            data_type=>$foundNet->data_type,
                                                            module=>$TopDie_TopMod->name
                                                            );
                                        print $indent x 7, "3D bus port: ",$netNameOnly, " with dir:",$otherDieDirection," added to Bot die\n";
                                    }
                                }
                            }
                        }
            }
        
        }
    }
}
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

print "<=== Done !\n \n";
#
# Write netlists
print "===> \n";
print "Write netlists: \n";
write_nl($nl_Top,"./$root/Top.v");
write_nl($nl_Bot,"./$root/Bot.v");
print "<=== Done ! \n";

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

if (! defined $foundCell) {print "Could not delete cell:", $cell->name," \n";}
    else
        {
            $foundCell->delete;
            print "Deleted cell: ",$cell->name, " \n";
        }
}

#=============================================================================================
sub AddCell {
my $module = shift;
my $cell   = shift;
my $fl     = shift;

my $cellAdded=$module->new_cell(
                            name=>$cell->name, 
                            submodname=>$cell->submodname, 
                            _pins=>$cell->_pins,
                            @fl);
if (! defined $cellAdded) {print "Could not add cell:", $cell->name," \n";}
else
    {
    print "\n";
    print "Cell added: ", $cellAdded->name, " \n";
    }
}

#=============================================================================================
sub isNet3D {
    my $netToFind = shift;
    my ($InstancesToMove) = @_;
    
    my @ConnectedCells;
    my $Is3DNet=0;
    my $cellName=""; 
    
    print $indent x 6, "Net: ", $netToFind, " is connected to cells:\n";
    
    # # Look through all cells, pins, pinselects & netnames
    # foreach my $cell ($TopModule->cells) {
    #     #my $foundCell=$TopModule->find_cell($cell);
    #     foreach my $pin ($cell->pins) {
    #         foreach my $pinselect ($pin->pinselects) {
    #             if ($pinselect->netname eq $netToFind) {
    #                 # strings may contain special characters & spaces ! clean up
    #                 $cellName=$cell->name;
    #                 $cellName=~ s/\s//g;                 
    #                 my $tmp= quotemeta $cellName;

    #                 # Put in the array
    #                 push @ConnectedCells, $tmp;
    #                 #debug
    #                 print $indent x 7, "cell: ", $tmp, "___\n";
    #              }
    #         }
    #     }
    # }
    foreach my $cellName (@{$hashNetCell{$netToFind}}) {
        $cellName=~ s/\s//g;                 
        my $tmp= quotemeta $cellName;

        # Put in the array
        push @ConnectedCells, $tmp;
        #debug
        print $indent x 7, "cell: ", $tmp, "___\n";
    }

    
    # Compare cells of the net and those that should move
    my $count=0;
    OUTER : # loop label for last
    foreach my $cell (@ConnectedCells) {
        foreach my $cellToMove (@$InstancesToMove) {
            if ($cell eq $cellToMove) { 
                #print $indent x 7, "Equal: cell on net: ", $cell, " , & cell to move: ", $cellToMove, "\n";
                $count=$count+1; 
                }
                else {
                    print $indent x 7, "Diff.: cell on net: ", $cell, " , & cell to move: ", $cellToMove, "\n";
                    # single cell on another die will cause 
                    # this net to become 3D net
                    # saves computational time
                    last OUTER;
                }
            }
        }
        
    # Finally figure out if it is a 2D net
    my $arraySize = @ConnectedCells;
    print $indent x 7,"Count:",$count," Array size:",$arraySize,"\n";
    if ($count == $arraySize) { # all cells are on the top die
        $Is3DNet=0;
        print $indent x 6, "Is 2D net\n";
        } # if not it is a 3D net
        else {
            $Is3DNet=1;
            print $indent x 6, "Is 3D net\n";
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