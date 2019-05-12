#!/usr/bin/perl

use strict;
use warnings;
use Poker::StatsSystem::PokerStarsParser;
use Poker::StatsSystem::History;
use Poker::StatsSystem::ProgressPrinter;
use Carp;
use Data::Dumper;
use Log::Log4perl;
use Getopt::Std;


my $progNamePrefix = "export-tournaments-tsv";
my $progname = $progNamePrefix.".pl";
my $defaultLogLevel = "INFO";
my $defaultLogFilename = "$progNamePrefix.log";
use Poker::StatsSystem qw/$repositoryEnvVarName $historyFilename @possibleLogLevels/;

my @fields = ( 'startDate', 'startTime', 'currency', 'buyInMinusRake', 'rake', 'nbPlayers', 'myPosition');


sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <output.tsv>\n";
	print $fh "  Reads a Poker::StatsSystem repository and exports the tournaments to a TSV\n";
	print $fh "  file.\n";
	print $fh "  The location of the repository is determined as follows:\n";
	print $fh "    1. if option -r is set, use it.\n";
	print $fh "    2. if the environment variable \$$repositoryEnvVarName is set, use it.\n";
	print $fh "    3. otherwise use the current directory.\n";
	print $fh "\n";
	print $fh "  Options:\n";
	print $fh "     -h print this help message\n";
	print $fh "     -l <log config file | Log level> specify either a Log4Perl config file\n";
	print $fh "        or a log level (".join(",", @possibleLogLevels).")\n";
	print $fh "     -L <Log output file> log filename (useless if a log config file is given).\n";
	print $fh "     -r <path repository> set the location of the repository to use.\n";
	print $fh "     -n do not print header row.\n"; 
	print $fh "\n"; 
}






# PARSING OPTIONS
my %opt;
getopts('hl:L:r:n', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
# init log
Poker::StatsSystem::initLog($opt{l} || $defaultLogLevel, $opt{L} || $defaultLogFilename); # LOG INITIALIZED
my $logger = Log::Log4perl->get_logger(__PACKAGE__);
$logger->debug("Initializing parameters");
usage($STDERR) && exit 1 if (scalar(@ARGV) == 0);
my %params;
if (defined($opt{r})) {
	$params{repository} = $opt{r};
} elsif (defined($ENV{$repositoryEnvVarName})) {
	$params{repository} = $ENV{$repositoryEnvVarName};
} else {
	$params{repository} = ".";
}
my $printHeader = defined($opt{n}) ? 0 : 1;
my $outputFilename = $ARGV[0];

my $data = Poker::StatsSystem::History->new();
$data->loadFromFileOrWarn("$params{repository}/$historyFilename");
print "After loading data: nb hands ; tournaments = ".$data->nbHands()." ; ".$data->nbTournaments()."\n";
my $tournamentsMap = $data->getAllTournaments();

open(FILE, ">", $outputFilename) or  die "Can not open '$outputFilename' for writing";
print FILE join("\t", @fields)."\n" if ($printHeader);
foreach my $tourneyData (values %$tournamentsMap) {
    my @row;
    foreach my $field (@fields) {
	push(@row, $tourneyData->{$field});
    }
    print FILE join("\t", @row)."\n";
}
close(FILE);
