#!/usr/bin/perl -w
package LEF;

use strict;
use warnings;
use Macro;
use Data::Dumper;
 
sub new {
	my ($class, $args) = @_; 
	my $self = {
		name      => $args->{name},
		file_name => $args->{file_name}, 
		lef_data  => undef,
		macros    => [@_],
	};

	bless $self, $class;
return $self;
}
	
sub dump_LEF {
	my $self = shift;
	my @macros = @{$self->{macros}};
	print "LEF name: ", $self->{name} , " \n";
	
	foreach my $macro (@macros) 
	{
		print "Macro name: ", $macro->{name} , " \n";
		my @pins = @{$macro->{pins}};
		my @dirs = @{$macro->{dirs}};
		my $i = 0;
		foreach my $pin (@pins) 
		{	
            print "Pin : $pin"; 
            if( length($dirs[$i]) ) {
			    print " Dir: $dirs[$i] \n";
                } else {
                print " Dir: No dir \n";
                }
			$i=$i+1;
		}
	}	
	# Brut force debug
	#print Dumper(@data);		
}

sub parse_LEF {
my $self = shift;

# Open file and get the data
open $self->{lef_data}, $self->{file_name} 
	or die "Could not open $self->{file_name}: $!";
my $data = $self->{lef_data};

# Clean the array
@{$self->{macros}}=();

# Set some string constants
my $macrostr     = "MACRO";
my $pinstr       = "PIN";
my $dirstr       = "DIRECTION";
my $endstr       = "END";
my $usestr       = "USE";
# Set some variables
my $macro_name   ;
my $pin_name     ;
my $pin_dir      ;
my @pins         =();
my @dirs         =();

while( my $line = <$data>)  
	{    
		if ($line =~ /\Q$macrostr\E/) {
			my @answer     = split(' ', $line);
			$macro_name = $answer[1];
			# Clean this area every time new macro is found
			@pins=();
			@dirs=();
		}
		if ($line =~ /\Q$pinstr\E/) {
			my @answer = split(' ', $line);
			$pin_name = $answer[1];
            $pin_dir  = "None";      # some pins don't have direction, default value
		}
		if ($line =~ /\Q$dirstr\E/) {
			my @answer = split(' ', $line);
			# add direction to list of directions
			$pin_dir = $answer[1];
		} 
		
        if ($line =~ /\Q$endstr\E/) {
			my @answer = split(' ', $line);
			my $end = $answer[1];
			# Check if this is END
			if ( (defined $end) ) {
				# If END for PIN
				if ($end eq $pin_name) {
			        push (@pins, $pin_name);
			        push (@dirs, $pin_dir);
                }
				# If END for MACRO
				if ($end eq $macro_name) {
			        # Debug
			        #print "--> MACRO : ", $macro_name, "\n";
                    #print " --> Pins", @pins, "\n" , " DIR: ", @dirs, "\n";
					
                    # Create new macro 
					my $new_Macro = Macro->new({name => $macro_name,
														});
					# Provide data for the macro 
                    $new_Macro->set_pins(@pins);
                    $new_Macro->set_dirs(@dirs);
					
                    push (@{$self->{macros}}, $new_Macro);						
				}
			}
		}
	}
}

sub find_macro {
	my $self = shift;
	my $macroTofind = $_[0];
	my @macros = @{$self->{macros}};
	my $macrofound = undef;
	
	print "Searching macro: ", $macroTofind , " \n";
	
	foreach my $macro (@macros) 
	{
		if ( $macro->{name} eq $macroTofind )
		{$macrofound = $macro;}
	}	
	if ( ! defined $macrofound ) {die "Could not find macro: $macroTofind ... quitting!";}
	else {return $macrofound;}
}

sub find_pindir {
	my $self = shift;
	my $macroTofind = $_[0];
	my $pinTofind = $_[1];

	my @macros = @{$self->{macros}};
	
	my $macro = $self->find_macro($macroTofind);
	
	my @pins = @{$macro->{pins}};
	my @dirs = @{$macro->{dirs}};
	
	my $i = 0;
	foreach my $pin (@{$macro->{pins}}) 
	{
        my $pinNameOnly = $pin;
        # Get rid of the bus 
        $pinNameOnly =~ s/\[([^\[\]]|(?0))*]//g;
		
        if ( $pinNameOnly eq $pinTofind )
			{return $dirs[$i];}
		$i=$i+1;
	}	
}
######################################################################
#### Package return
1;
__END__
