package Poker::StatsSystem::ProgressPrinter;

use 5.006;
use strict;
use warnings;
use POSIX;
use base 'Exporter';
use IO::Handle;

=head1 NAME

Poker::StatsSystem::ProgressPrinter

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS


=head1 EXPORT

=cut 

my %defaultOptions = ( progressBarLength => 20 ,
					   progressBarChar => "#" ,
					   prefix => "",
					   alwaysUpdate => 0
					   );


our @EXPORT_OK = qw//;


=head1 SUBROUTINES/METHODS

=head2 new($params)


=cut

sub new {
	my ($class, $params) = @_;
	my $self = $params;
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{total} = 1; # default
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__);
	$self->{currentNb} = 0;
	bless($self, $class);
	return $self;
}



=head2 setTotal($total)

=cut

sub setTotal {
	my $self = shift;
	$self->{total} = shift;
}


=head2 notifyProgress($value)

=cut 

sub notifyProgress {
	my $self = shift;
	my $value = shift;
	my $total = $self->{total};
	$self->{logger}->trace("progress parameters: $value ; $total");
	my $progressInside = $self->{progressBarLength} - 2;
	my $nb = floor($value * $progressInside / $total);
	if ($self->{alwaysUpdate} || ($nb > $self->{currentNb})) {
		my $bar = "[".$self->{progressBarChar} x $nb." " x ($progressInside-$nb)."]";
		$self->{logger}->trace("progress details: prefix='$self->{prefix}' ; length='$self->{progressBarLength}' ; progressInside=$progressInside ; nb=$nb");
		printf("%s%5.1f%%  %s\r", $self->{prefix}, $value*100/$total, $bar);
		STDOUT->flush();
		$self->{currentNb} = $nb;
	}
}



sub done {
	my $self = shift;
	print "\n";
}


1;
