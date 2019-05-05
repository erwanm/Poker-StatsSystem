package Poker::StatsSystem;

use 5.006;
use strict;
use warnings;
use POSIX;
use base 'Exporter';

=head1 NAME

Poker::StatsSystem - The great new Poker::StatsSystem!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Poker::StatsSystem;

    my $foo = Poker::StatsSystem->new();
    ...

=head1 EXPORT

=cut 


our @EXPORT_OK = qw/$repositoryEnvVarName $historyFilename @possibleLogLevels $foldCode $checkCode $callCode $betCode $raiseCode @rounds %codeRound/;

our $repositoryEnvVarName = "POKER_STATS_SYSTEM";
our $historyFilename = "history.dat";
our @possibleLogLevels = qw/TRACE DEBUG INFO WARN ERROR FATAL OFF/;
our ($foldCode, $checkCode, $callCode, $betCode, $raiseCode) = qw/1 2 3 4 5/;
our @rounds = qw/preflop flop turn river/;
our %codeRound = ("preflop"=>0, "flop"=>1, "turn"=>2, "river"=>3);


=head1 SUBROUTINES/METHODS

=head2 createDefaultLogConfig($filename, $logLevel)

creates a simple log configuration for log4perl, usable with Log::Log4perl->init($config)

=cut

sub createDefaultLogConfig {
	my ($filename, $logLevel) = @_;
	my $config = qq(
   		log4perl.rootLogger              = $logLevel, LOG1
   		log4perl.rootLogger.Threshold = OFF
   		log4perl.appender.LOG1           = Log::Log4perl::Appender::File
   		log4perl.appender.LOG1.filename  = $filename
   		log4perl.appender.LOG1.mode      = write
   		log4perl.appender.LOG1.utf8      = 1
   		log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
   		log4perl.appender.LOG1.layout.ConversionPattern = [%r] %d %p %m\t in %M (%F %L)%n
	);
	return \$config;
}

=head2 initLog($logConfigFileOrLevel, $logFilename)

initializes a log4perl object in the following way: if $logConfigFileOrLevel is a log level, then uses the
default config (directed to $logFilename), otherwise $logConfigFileOrLevel is supposed to be the log4perl
config file to be used.

=cut

sub initLog {
	my ($logConfigFileOrLevel, $logFilename) = @_;
  	my $logLevel = undef;
#  	if (defined($logParam)) {
	if (grep(/^$logConfigFileOrLevel/, @possibleLogLevels)) {
		Log::Log4perl->init(createDefaultLogConfig($logFilename, $logConfigFileOrLevel));
	} else {
		Log::Log4perl->init($logConfigFileOrLevel);
	}
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
