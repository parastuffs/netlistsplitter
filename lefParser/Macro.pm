#!/usr/bin/perl -w
package Macro;

use strict;
use warnings;

sub new {
		#my $class = shift;
		#my $args = (@_);
		my ($class, $args) = @_; 
		my $self = {
			name => $args->{name}, 
			pins =>  [@_] , 
			dirs =>  [@_] , 
		} ;
		
		$self->{pins}=();
		$self->{dirs}=();
    bless $self, $class;
    return $self;
}


sub get_name {
    my $self = shift;
    my $name = $self->{name};
    return $name;
}

sub get_pins {		
		my $self = shift; 
		return @{ $self->{pins} }; 
}

sub get_dirs {		
		my $self = shift; 
		return @{ $self->{dirs} }; 
}

sub set_pins {
        my ( $Macro, @Pins ) = @_;
        $Macro->{pins} = \@Pins;
}

sub set_dirs {
        my ( $Macro, @dirs ) = @_;
        $Macro->{dirs} = \@dirs;
}
#
#sub MacroName {
#  my ( $self, $MacroName ) = @_;
#  $self->{_MacroName} = $MacroName if defined($MacroName);
#  return $self->{_MacroName};
#}
#
#sub getMacroName {
#	my $self = shift;
##	return $self ->{macro_name};
#return $self->{_MacroName};
#}
##
#sub setMacroName {
#    my ( $self, $MacroName ) = @_;
#    $self->{_MacroName} = $MacroName if defined($MacroName);
#    return $self->{_MacroName};
#}
#
#sub getMacroPins {
#	my $self = shift;
#	return $self ->{_MacroPins};
#}
##
######################################################################
#### Package return
1;
__END__

#
#my $file = 'main_EUV_6T.lef';
#open my $info, $file or die "Could not open $file: $!";
#
#my $macrostr     = "MACRO";
#my $pinstr       = "PIN";
#my $directionstr = "DIRECTION";
#
#
#
#my $card = PlayingCard->new("Ace","Spades");
#
#
#while( my $line = <$info>)  {   
#    #print $line;    
#		if ($line =~ /\Q$macrostr\E/) {
#			my @answer = split(' ', $line);
#			print "MACRO : ", $answer[1], "\n";
#		}
#		if ($line =~ /\Q$pinstr\E/) {
#			my @answer = split(' ', $line);
#			print "PIN : ", $answer[1], " -> ";
#		}
#		if ($line =~ /\Q$directionstr\E/) {
#			my @answer = split(' ', $line);
#			print "DIRECTION : ", $answer[1], "\n";
#		}
#}
#close $info;
