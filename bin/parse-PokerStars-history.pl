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


my $progNamePrefix = "parse-PokerStars-history";
my $progname = $progNamePrefix.".pl";
my $defaultLogLevel = "INFO";
my $defaultLogFilename = "$progNamePrefix.log";
use Poker::StatsSystem qw/$repositoryEnvVarName $historyFilename @possibleLogLevels/;


sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <pathname1> [<pathname2> ...]\n";
	print $fh "  Reads every file or directory <pathnameX> supplied, parses the content\n";
	print $fh "  as a summary of a PokerStars game (hands or tournament), and writes the\n";
	print $fh "  content to a Poker::StatsSystem repository (adding to the existing data if\n";
	print $fh "  any).\n";
	print $fh "  <pathnameX> can be either a file or a directory; in the latter case, all\n";
	print $fh "  files in the directory will be processed.\n";
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
	print $fh "     -m parse file(s) as Mbox email format.\n";
	print $fh "     -q Quiet mode (do not print progress information to stdout).\n";
	print $fh "     -r <path repository> set the location of the repository to use.\n";
	print $fh "     -t <filename> saves a copy of the repository as a text file (for debugging)\n"; 
	print $fh "\n"; 
	print $fh "\n"; 
}



sub processFile {
	my $filename = shift;
	my $parser = shift;
	my $data = shift;
	my $params = shift;
	my $no = shift;
	my $nb = shift;
	my $subProgress = shift;
	my $log = shift;
	$log->debug("Processing $filename");
	my $progressPrinter;
	if ($params->{printProgress}) {
		$progressPrinter = Poker::StatsSystem::ProgressPrinter->new({ prefix => "$no/$nb: "});
		$progressPrinter->notifyProgress($subProgress) if ($subProgress < 1);
	}
	if ($params->{parseAsMbox}) {
		$log->trace("mbox = TRUE");
		$parser->parseHistoryMailbox($data, ($subProgress < 1)?undef:$progressPrinter, $filename);
	} else {
		$log->trace("mbox = FALSE");
		$parser->parseHistoryFiles($data, ($subProgress < 1)?undef:$progressPrinter, $filename);
	}
	$progressPrinter->done() if (defined($progressPrinter) && ($no == $nb) && ($subProgress == 1)); 
}



# PARSING OPTIONS
my %opt;
getopts('hl:L:mqr:t:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
# init log
Poker::StatsSystem::initLog($opt{l} || $defaultLogLevel, $opt{L} || $defaultLogFilename); # LOG INITIALIZED
my $logger = Log::Log4perl->get_logger(__PACKAGE__);
$logger->debug("Initializing parameters");
usage($STDERR) && exit 1 if (scalar(@ARGV) == 0);
my %params;
$params{printProgress} = !defined($opt{q});
$params{parseAsMbox} = defined($opt{m});
if (defined($opt{r})) {
	$params{repository} = $opt{r};
} elsif (defined($ENV{$repositoryEnvVarName})) {
	$params{repository} = $ENV{$repositoryEnvVarName};
} else {
	$params{repository} = ".";
}
my $asText;
$asText = $opt{t};



my $parser = Poker::StatsSystem::PokerStarsParser->new();
my $data = Poker::StatsSystem::History->new();
$data->loadFromFileOrWarn("$params{repository}/$historyFilename");
print "After loading previous data: nb hands ; tournaments = ".$data->nbHands()." ; ".$data->nbTournaments()."\n";
my $no=1;
my $nb = scalar(@ARGV);
while (my $entry = shift) { # iterates @ARGV
	if (-d $entry) {
		my @files = glob("$entry/*");
		my $noFile = 1;
		my $nbFiles = scalar(@files);
		while (my $f = shift @files) {
#			print "FILE='$f'\n";
			processFile($f, $parser, $data, \%params, $no, $nb, $noFile/$nbFiles, $logger);
			$noFile++;
		}
	} else {
		processFile( $entry , $parser, $data, \%params, $no, $nb, 1, $logger);
	}
	$no++;
}
print "After adding new data: nb hands ; tournaments = ".$data->nbHands()." ; ".$data->nbTournaments()."\n";
$data->saveToFile("$params{repository}/$historyFilename", $asText);

