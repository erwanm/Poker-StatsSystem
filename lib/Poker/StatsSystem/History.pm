package Poker::StatsSystem::History;

use 5.006;
use strict;
use warnings;
use Carp;
use MIME::QuotedPrint qw/decode_qp/;
use Text::Iconv; 
use Log::Log4perl;
use Data::Dumper;
use Storable;

=head1 NAME

Poker::StatsSystem::History

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

my %defaultOptions = (  );

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Poker::StatsSystem::History;

    my $foo = Poker::StatsSystem->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new()

=cut

sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{hands} = {};
	$self->{tournaments} = {};
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__);
	bless($self, $class);
	return $self;
}



=head2 function2 loadFromFile($filename)

$filename contains the full history in the Data::Dumper format, as a hash { hands, tournaments }

=cut

sub loadFromFile {
	my $self = shift;
	my $filename = shift;
	my $log = $self->{logger};
	my $data = retrieve($filename)  or $log->logconfess("Can not retrieve previous data from '$filename'.");
	$log->logconfess("Error: data read from '$filename' does not contain 'hands'") if (!defined($data->{hands}));	
	$log->logconfess("Error: data read from '$filename' does not contain 'tournaments'") if (!defined($data->{tournaments}));
	$self->{hands} = $data->{hands};
	$self->{tournaments} = $data->{tournaments};
}



=head2 function2 loadFromFileOrWarn($filename)

$filename contains the full history in the Data::Dumper format, as a hash { hands, tournaments }

=cut

sub loadFromFileOrWarn {
	my $self = shift;
	my $filename = shift;
	if ( -e $filename ) {
		$self->loadFromFile($filename);
	} else {
		$self->{logger}->logwarn("Warning: no existing data in repository '$filename'");
	}
}

=head2 function2 saveToFile($filename)

$filename will contain the full history in the Data::Dumper format, as a hash { hands, tournaments }

=cut

sub saveToFile {
	my $self = shift;
	my $filename = shift;
	my $saveACopyAsTextFilename = shift;
	my $log = $self->{logger};
	store({ "hands" => $self->{hands} , "tournaments" => $self->{tournaments}	}, $filename);
	if (defined($saveACopyAsTextFilename)) {
		open(FILE, ">", $saveACopyAsTextFilename) or $self->{logger}->logconfess("Can not open '$saveACopyAsTextFilename' for writing");
		print FILE Dumper({ "hands" => $self->{hands} , "tournaments" => $self->{tournaments}	});
		close(FILE);
	}
}

=head2 function2 addTournament($tournament)


=cut

sub addTournament {
	my $self = shift;
	my $tournament = shift;
	my $log = $self->{logger};
	my $previousVersion = $self->{tournaments}->{$tournament->{id}};
	if (defined($previousVersion)) {
		my ($date, $time) = ($previousVersion->{startDate}, $previousVersion->{startTime});
		$log->logconfess("Error: tournament with same id, different date (bug?): ".$tournament->{id}.", $date,$time vs. ".$tournament->{startDate}.",".$tournament->{startTime}) if ($date ne $tournament->{startDate}); 
		$log->logconfess("Error: tournament with same id, different time (bug?): ".$tournament->{id}.", $date,$time vs. ".$tournament->{startDate}.",".$tournament->{startTime}) if ($time ne $tournament->{startTime}); 
		# otherwise simply a copy, skip silently
	} else {
		# TODO possibly other initializations/checks?
		$self->{tournaments}->{$tournament->{id}} = $tournament;
	}
}



=head2 existsTournament($id)

=cut

sub existsTournament {
	my $self = shift;
	my $tourneyId = shift;
	return defined($self->{tournaments}->{$tourneyId});
}



=head2 function2 addHand($Hand)


=cut

sub addHand {
	my $self = shift;
	my $hand = shift;
	my $log = $self->{logger};
	my $previousVersion = $self->{hands}->{$hand->{id}};
	if (defined($previousVersion)) {
		$log->debug("Hand $hand->{id} already recorded");
		my ($date, $time) = ($previousVersion->{startDate}, $previousVersion->{startTime});
		$log->logconfess("Error: hand with same id, different date (bug?): ".$hand->{id}.", $date,$time vs. ".$hand->{startDate}.",".$hand->{startTime}) if ($date ne $hand->{startDate}); 
		$log->logconfess("Error: hand with same id, different time (bug?): ".$hand->{id}.", $date,$time vs. ".$hand->{startDate}.",".$hand->{startTime}) if ($time ne $hand->{startTime}); 
		# otherwise simply a copy, skip silently
	} else {
		$log->debug("Adding hand $hand->{id}");
		# TODO possibly other initializations/checks?
		$self->{hands}->{$hand->{id}} = $hand;
	}
}



=head2 existsHand($id)

=cut

sub existsHand {
	my $self = shift;
	my $handId = shift;
	return defined($self->{hands}->{$handId});
}



=head2 addTournaments(@$data)

=cut

sub addTournaments {
	my $self = shift;
	my $tournaments = shift;
	foreach (@$tournaments) {
		$self->addTournament($_);
	}
}



=head2 addTournaments(@$data)

=cut

sub addHands {
	my $self = shift;
	my $hands = shift;
	foreach (@$hands) {
		$self->addHand($_);
	}
}



=head2 nbTournaments()

=cut

sub nbTournaments {
	my $self = shift;
	return scalar(keys(%{$self->{tournaments}}));
}


=head2 nbHands()

=cut

sub nbHands {
	my $self = shift;
	return scalar(keys(%{$self->{hands}}));
}



sub getAllHands {
    my $self = shift;
    return $self->{hands};
}


sub getAllTournaments {
    my $self = shift;
    return $self->{tournaments};
}


=head1 AUTHOR

Erwan Moreau, C<< <erwan.more at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-poker-statssystem at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Poker-StatsSystem>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Poker::StatsSystem


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Poker-StatsSystem>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Poker-StatsSystem>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Poker-StatsSystem>

=item * Search CPAN

L<http://search.cpan.org/dist/Poker-StatsSystem/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Erwan Moreau.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Poker::StatsSystem
