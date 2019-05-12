package Poker::StatsSystem::PokerStarsParser;

use strict;
use warnings;
use Carp;
use Mail::Box::Manager;
use Log::Log4perl;
use Data::Dumper;
use POSIX;
use File::BOM qw/open_bom/;
use Poker::StatsSystem qw/$foldCode $checkCode $callCode $betCode $raiseCode @rounds %codeRound/;

=head1 NAME

Poker::StatsSystem::PokerStarsParser

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

# EM May 19 - changed BOM option to 0 as this seems to cause an error opening the file for ASCII files from PokerStars.EU
#             Assuming that this will cause an issue with previous files from PokerStars.FR?
#
#my %defaultOptions = ( "openAsUTF8WithBOM" => 1 );
my %defaultOptions = ( "openAsUTF8WithBOM" => 0 );

my $euroUTF8Code = undef;
my $euroUTF8CodeFiles = "\x{20AC}";
my $euroUTF8CodeEMail = "\xE2\x82\xAc";  # wasn't able to understand why this is necessary nor how to do this properly


=head1 SYNOPSIS



=head1 SUBROUTINES/METHODS

=head2 new()

=cut 

sub new {
	my ($class, $params) = @_;
	my $self;
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__);
	bless($self, $class);
	return $self;
}



=head2 parseHistoryFiles($historyData, $progressPrinter, @filenames)

=cut

sub parseHistoryFiles {
	my $self = shift;
	my $historyData = shift;
	my $progressPrinter = shift;
	my $log = $self->{logger};
	$euroUTF8Code = $euroUTF8CodeFiles;
	my $no = 0;
	$progressPrinter->setTotal(scalar(@_)) if (defined($progressPrinter));
	foreach my $filename (@_) {
	    $log->debug("Parsing file '$filename' (history contains ".$historyData->nbTournaments()." tournaments and ".$historyData->nbHands()." hands)");
		my $fh;
		if ($self->{openAsUTF8WithBOM}) {
			open_bom($fh, $filename, ) or $log->logconfess("Cannot open '$filename'.");
		} else {
			open($fh, '<:encoding(utf-8)', $filename) or $log->logconfess("Cannot open '$filename'.");
		}
		my @input = <$fh>; 
		close($fh);
		my $lineNo = 0;
		$filename =~ s@.*/@@;
		if ($filename =~ m/^TS/) {
			$self->parseTournaments(\@input, \$lineNo, $historyData);
		} elsif ($filename =~ m/^HH/) {
			$self->parseHands(\@input, \$lineNo, $historyData);
		} else {
			$log->logwarn("File '$filename' not recognized: filename should start either with 'HH' or 'TS'");
		}
		$no++;
		$progressPrinter->notifyProgress($no) if (defined($progressPrinter));
	}
}


=head2 parseHistoryMailbox($historyData, $progressPrinter, $filename)

=cut

sub parseHistoryMailbox {
	my $self = shift;
	my $historyData = shift;
	my $progressPrinter = shift;
	my $filename = shift;
	my $log = $self->{logger};
	$euroUTF8Code = $euroUTF8CodeEMail;
	my $mgr = Mail::Box::Manager->new();
	my $emailFolder = $mgr->open(folder => $filename, lock_type => 'NONE' ); # don't create a lock file <filename>.lock
	my ($no, $nb) = (0, scalar($emailFolder->messages()));
	$log->debug("$nb emails found in mbox file $filename");
	$progressPrinter->setTotal($nb) if (defined($progressPrinter));
	foreach my $msg ($emailFolder->messages()) { # all messages
	    my $lineNo = 0;
		if ($msg->subject() =~ m/^PokerStars Tournament History/) {
			$log->info("Parsing new tournament history email");
		    my $content = $msg->body()->encode(mime_type => 'text/plain', transfer_encoding => 'none', charset => 'utf-8')->lines(); # list ref
			$self->parseTournaments($content, \$lineNo, $historyData);
		} elsif ($msg->subject() =~ m/^PokerStars Hand History/) {
			$log->info("Parsing new hand history email");
		    my $content = $msg->body()->encode(mime_type => 'text/plain', transfer_encoding => 'none', charset => 'utf-8')->lines(); # list ref
			$self->parseHands($content, \$lineNo, $historyData);
		} else {
			$log->lowarn("Warning: email with subject '".$msg->subject()."' not taken into account.");
		}
		$no++;
		$progressPrinter->notifyProgress($no) if (defined($progressPrinter));
	}
	$emailFolder->close();
}



=head2 parseTournaments($input, $$lineNoRef, $historyData)

=cut

sub parseTournaments {
	my $self = shift;
	my $input = shift;
	my $lineNo = shift;
	my $historyData = shift;
	my $log = $self->{logger};
	
	my @tournaments;
	while (my $dataTournament = $self->parseTournament($input, $lineNo, $historyData)) {
	}
}



=head2 parseHands($input, $$lineNoRef, $historyData)

=cut

sub parseHands {
	my $self = shift;
	my $input = shift;
	my $lineNo = shift;
	my $historyData = shift;
	my $log = $self->{logger};
	
	my @hands;
	while (my $dataHand = $self->parseHand($input, $lineNo, $historyData)) {
	}
}



=head2 parseHand($@input, $lineNoRef, $history)

=cut

sub parseHand {
	my $self = shift;
	my $input = shift;
	my $lineNoRef = shift;
	my $history = shift;
	my $log = $self->{logger};
	my %res;
	#
	while (1) {
		my $line = $input->[$$lineNoRef];
		$line =~ s/^PokerStars Game/PokerStars Hand/ if ($$lineNoRef < scalar(@$input)); # old version "Game"
	    while (($$lineNoRef < scalar(@$input)) &&  !($line =~ m/^PokerStars Hand #\d+/))  { # skip until start of a hand
	    	$log->trace("Skipping line '$input->[$$lineNoRef]'");
	    	$line = $input->[++$$lineNoRef];
			$line =~ s/^PokerStars Game/PokerStars Hand/ if ($$lineNoRef < scalar(@$input)); # old version "Game"
	    }
	    if ($$lineNoRef < scalar(@$input)) { # if not end of data
			if ($line =~ m@^PokerStars Hand #(\d+): Tournament #\d+, @) { # sitngo or tourney
				$res{isTourney} = 1;
		    	# Match X is not mandatory (?)
		    	my ($buyIn, $remaining, $matchRound);
		    	($res{id}, $res{idTournament}, $buyIn, $res{gameType}, $remaining) = ($line =~ m@^PokerStars Hand #(\d+): Tournament #(\d+), (\S+) EUR (.+?) - (.+)\s*$@) or $log->logconfess("Error: Expected 'PokerStars Hand #X: Tournament #Y, €.....' instead of '$line'.");
#					    	print Dumper(\%res)."\n";
				($res{buyInMinusRake}, $res{rake}, $res{bountyBuyIn}) = ($buyIn =~ /$euroUTF8Code([0-9.]+)\+$euroUTF8Code([0-9.]+)(\+$euroUTF8Code[0-9.]+)?/); # TODO
				$res{bountyBuyIn} =~ s/^\+€([0-9.]+)$/$1/  if ($res{bountyBuyIn});
	    		($matchRound, $res{blindLevel}, $res{SB}, $res{BB}, $res{date}, $res{time}) = ( $remaining =~ m@(Match Round \S+, )?Level (\S+) \(([0-9.]+)/([0-9.]+)\) - (\S+) (\S+) CET@) or $log->logconfess("Error: Expected 'Match X, Level Y' instead of '$remaining'.");
	    		($res{round}) = ($matchRound =~ m/^Match Round (\w+)/) if ($matchRound);
			} else { # cash game
#				my ($pbm) =  ($line =~ m@^PokerStars Hand #\d+: .+? \((.+/.+) EUR\) - \S+ \S+\s*@) or $log->logconfess("Error: Expected 'PokerStars Hand #X: ....' instead of '$line'.");
#				die "$pbm" if ($pbm !~ m@$euroUTF8Code[0-9.]+/$euroUTF8Code[0-9.]+@);
		    	($res{id}, $res{gameType}, $res{SB}, $res{BB}, $res{date}, $res{time}) = ($line =~ m@^PokerStars Hand #(\d+): (.+?) \($euroUTF8Code([0-9.]+)/$euroUTF8Code([0-9.]+) EUR\) - (\S+) (\S+)\s*@) or $log->logconfess("Error: Expected 'PokerStars Hand #X: ....' instead of '$line'.");
				$res{isTourney} = 0;
			}
			if (defined($history) && ($history->existsHand($res{id}))) {
				$log->debug("Hand #$res{id} is already in the history, skipping.");
				$$lineNoRef++;
			} else {
				$log->debug("Hand #$res{id} is new, processing...");
				$self->parseHandPlayers($input, $lineNoRef, \%res);
				my $nbSeatsInvolvedNotAllIn = $self->parseHandBlinds($input, $lineNoRef, \%res);
				if (defined($res{CANCELLED})) {
					$log->debug("Hand $res{id} was cancelled.");
				} else {
					my $line = $self->parseHandGetNextLine($input, $lineNoRef, \%res);
					$log->logconfess("Expected '*** HOLE CARDS ***', found '$line' (id $res{id})") if ($line !~ m/^\*\*\* HOLE CARDS \*\*\*/);
					$line = $self->parseHandGetNextLine($input, $lineNoRef, \%res);
					($res{myName}, $res{holeCards}) = ($line =~ m/^Dealt to (.+) \[(\w\w \w\w)\]\s*$/) or $log->logconfess("Expected 'Dealt to XXX [YY YY]' but found '$line'");
					my $seatsInvolvedNotAllIn = $self->parseHandRound($input, $lineNoRef, \%res, $codeRound{"preflop"}) if ($nbSeatsInvolvedNotAllIn > 1); # if at least two players have a choice (i.e. are not allin)
					if (scalar(@$seatsInvolvedNotAllIn)>0) { # convention empty list if hand done
						$line = $self->parseHandGetNextLine($input, $lineNoRef, \%res);
						($res{board}->{$codeRound{"flop"}}) = ($line =~ m/^\*\*\* FLOP \*\*\* \[(.+)\]/) or $log->logconfess("Expected '*** FLOP *** ....', found '$line' (id $res{id})");
						$log->debug("Read flop = ".$res{board}->{$codeRound{"flop"}});
						$seatsInvolvedNotAllIn = $self->parseHandRound($input, $lineNoRef, \%res ,$codeRound{"flop"})  if (scalar(@$seatsInvolvedNotAllIn) > 1); # if at least two players have a choice (i.e. are not allin)
						if (scalar(@$seatsInvolvedNotAllIn)>0) { # convention empty list if hand done
							$line = $self->parseHandGetNextLine($input, $lineNoRef, \%res);
							($res{board}->{$codeRound{"turn"}}) = ($line =~ m/^\*\*\* TURN \*\*\* \[.+\] \[(..)\]/) or $log->logconfess("Expected '*** TURN *** ....', found '$line' (id $res{id})");
							$log->debug("Read turn = ".$res{board}->{$codeRound{"turn"}});
							$seatsInvolvedNotAllIn = $self->parseHandRound($input, $lineNoRef, \%res ,$codeRound{"flop"})  if (scalar(@$seatsInvolvedNotAllIn) > 1); # if at least two players have a choice (i.e. are not allin)
							if (scalar(@$seatsInvolvedNotAllIn)>0) { # convention empty list if hand done
								$line = $self->parseHandGetNextLine($input, $lineNoRef, \%res);
								($res{board}->{$codeRound{"river"}}) = ($line =~ m/^\*\*\* RIVER \*\*\* \[.+\] \[(..)\]/) or $log->logconfess("Expected '*** RIVER *** ....', found '$line' (id $res{id})");
								$log->debug("Read river = ".$res{board}->{$codeRound{"river"}});
								$line = $self->parseHandGetNextLine($input, $lineNoRef, \%res);
								$log->logconfess("Expected '*** SHOW DOWN ***', found '$line' (id $res{id})") if ($line !~ m/^\*\*\* SHOW DOWN \*\*\*$/);
								$self->parseShownDown($input, $lineNoRef, \%res);
							}
						}
					}
					
					# parse summary
								die "stop summary";
	
					$history->addHand(\%res);
					return \%res;
				}
	    	}
		} else {
			$log->debug("No more data, returning undef");
			return undef; # no more data
		}
	}
}


sub parseHandGetNextLine {
	my ($self, $input, $lineNoRef, $res) = @_;
	my $log= $self->{logger};
	while (1) {
	   	my $line = $input->[++$$lineNoRef];
	   	$log->logconfess("Error: end of data reached but expecting new line (line $$lineNoRef/".scalar(@$input).")") if (!defined($line));
    	$log->trace("Reading line '$line'");
	   	if ($line =~ m/joins the table at seat/) {
	    	$log->trace("case joining table");  # cash game
	   		my ($player, $seat) = ($line =~ m/^(.+) joins the table at seat #(\d+)/);
	   		$res->{misc}->{joiningTable}->{$player} = $seat;
	   	} elsif ($line =~ m/leaves the table/) {
	    	$log->trace("case leaving table");  # cash game
	   		my ($player) = ($line =~ m/^(.+) leaves the table/);
	   		$res->{misc}->{leavingTable}->{$player} = 1;
	   	} elsif ($line =~ m/will be allowed to play after the button/) {
	    	$log->trace("case waiting button"); # cash game
	   		my ($player) = ($line =~ m/^(.+) will be allowed to play after the button/);
	   		$res->{misc}->{waitingButton}->{$player} = 1;
	   	} elsif ($line =~ m/^Seat \d+: .+ \(($euroUTF8Code)?[0-9.]+ in chips\) out of hand \(moved from another table.*\)\s*$/) { # special case multi table tourneys
	    	$log->trace("case out of hand");    # cash game
	   		my ($player) = ($line =~ m/^Seat \d+: (.+) \(($euroUTF8Code)?[0-9.]+ in chips\) out of hand/);
   			$res->{misc}->{tourneyOutOfHand}->{$player} = 1;
   			return $line;
	   	} elsif ($line =~ m/was removed from the table for failing to post/) { #note: in this case the player was not in the "seats" list
	   		my ($player) = ($line =~ m/^(.+) was removed from the table for failing to post\s*$/);
	   		$res->{misc}->{failedToPost}->{$player} = 1;
	   	} elsif ($line =~ m/is connected\s*$/) { # both
	   		my ($player) = ($line =~ m/^(.+) is connected\s*$/);
	   		$res->{misc}->{reconnected}->{$player} = 1;
	   	} elsif ($line =~ m/is disconnected\s*$/) { # both
	   		my ($player) = ($line =~ m/^(.+) is disconnected\s*$/);
	   		$res->{misc}->{disconnected}->{$player} = 1;
	   	} elsif ($line =~ m/has timed out while being disconnected/) { # both
	   		my ($player) = ($line =~ m/^(.+) has timed out while being disconnected/);
	   		$res->{misc}->{timedOut}->{$player} = 1;
	   	} elsif ($line =~ m/has timed out/) { # both
	   		my ($player) = ($line =~ m/^(.+) has timed out/);
	   		$res->{misc}->{timedOut}->{$player} = 1;
	   	} elsif ($line =~ m/is sitting out\s*$/) { # both
	    	$log->trace("case sitting out");
	   		my ($player) = ($line =~ m/^(.+?):? is sitting out/);
	   		# 2 possibilities:
	   		if ($player =~ m/^Seat \d+: .+ \(($euroUTF8Code)?[0-9.]+ in chips\)/) { # line is like "Seat X: YYYY (ZZZ in chips) is sitting out"
	   			($player) = ($player =~ m/^Seat \d+: (.+) \(($euroUTF8Code)?[0-9.]+ in chips\)/);
	   			$res->{misc}->{sittingOut}->{$player} = 1;
	   			return $line;
	   		}  else { # otherwise it's "XXX is sitting out"
	   			$res->{misc}->{sittingOut}->{$player} = 1;
	   		}
	   	} elsif ($line =~ m/^(.+) said, ".*"\s*$/) { # both
	   		my ($player, $isObserver, $msg) = ($line =~ m/^(.+?)( \[observer\])? said, "(.*)"\s*$/);
#	   		print "DEBUG player=$player, isObserver='".defined($isObserver)."', msg='$msg'\n"; # also check observer(requires finishing parsing the hand) 
	   		$res->{chat} = [] if (!defined($res->{chat}));
	   		push(@{$res->{chat}}, [$player, $msg, defined($isObserver)]);
	   		$log->info('observer test') if (defined($isObserver));
	   	} elsif ($line =~ m/^Hand cancelled\s*$/) { # cash game (?)
	   		$res->{CANCELLED} = 1; 
	   	} else {
	   		$log->trace("case ELSE");
	   		return $line;
	   	}
   		$log->trace("going for next line");
	}	
}

sub parseHandPlayers {
	my ($self, $input, $lineNoRef, $res) = @_;
	my $log= $self->{logger};
	my $line = $self->parseHandGetNextLine($input, $lineNoRef, $res);
   	# if tournament, idGame = id tournament, idTable = table no ; otherwise (cash game) id game = name, id table = no (roman)  
	($res->{idTable}, $res->{nbPlayersMax}, $res->{button}) = ($line =~ m/^Table '([^']+)' (\d+)-max Seat #(\d+) is the button/) or $log->logconfess("Expected 'Table '<id table>' N-max Set #X is the button', found '$line' (id $res->{id})");
	if ($res->{isTourney}) {
		my $tmpIdT;
		($tmpIdT, $res->{idTourneyTable}) = ( $res->{idTable} =~ m/(\d+) (\d+)/) or $log->logconfess("Error: tourney identified; expected Table 'idTourney idSubTable' instead of '$line'");
		$log->logconfess("Error: id tournament=$res->{idTournament}, but in table id id=$tmpIdT (id $res->{id}).") if ($tmpIdT != $res->{idTournament});	
	}
	$line = $self->parseHandGetNextLine($input, $lineNoRef, $res);
  	my %players;
  	my @seats; # contains seats players names by seat no, only for active players
  			   # remark: in a tourney, a player is assumed always "active" (even if sitting out, they pay the blinds)
  	my $nbActivePlayers=0;
  	while ($line =~ m/^Seat \d+/) {
  		my ($seatNo, $player, $dummyEuro, $stack) = ($line =~ m/^Seat (\d+): (.+) \(($euroUTF8Code)?([0-9.]+) in chips\)/) or $log->logconfess("Expected 'Seat N: player XXX (Y in chips)' instead of '$line' (id $res->{id})");
  		$players{$player}->{seatNo} = $seatNo;
  		$players{$player}->{stackStart} = $stack; 		
  		$players{$player}->{stackEnd} = $stack; # stackEnd will be updated progressively
  		$players{$player}->{putInPot}->[$codeRound{"preflop"}] = 0;
  		if (!defined($res->{misc}->{tourneyOutOfHand}->{$player}) && ($res->{isTourney} || (!defined($res->{misc}->{sittingOut}->{$player})))) {
  			$seats[$seatNo] = $player;
  			$nbActivePlayers++; 
  		}
		$line = $self->parseHandGetNextLine($input, $lineNoRef, $res);
  	}
  	$res->{players} = \%players;
  	$res->{activePlayersSeats} = \@seats;
  	$res->{nbActivePlayers} = $nbActivePlayers;
}
  	
 sub parseHandBlinds { 	
	my ($self, $input, $lineNoRef, $res) = @_;
	my $log= $self->{logger};
	my $nbSeatsNotAllIn = $res->{nbActivePlayers};
	my $indexSB = ($res->{nbActivePlayers}==2)?0:1; # special case for heads up
	$res->{playerSB} = $res->{activePlayersSeats}->[$self->_nextActivePlayer($res->{button}, $res, $indexSB)];
	$res->{playerBB} = $res->{activePlayersSeats}->[$self->_nextActivePlayer($res->{button}, $res, $indexSB+1)];
	$log->debug("SB = '$res->{playerSB}' ; BB = '$res->{playerBB}'");
   	my $line = $input->[$$lineNoRef]; # has already been found
  	return 0 if (defined($res->{CANCELLED}));
  	my @playersAnte;
  	while ($line =~ m/posts the ante/) {
  		my ($player, $dummyEuro, $amountAnte) = ($line =~ m/([^:]+): posts the ante ($euroUTF8Code)?([0-9.]+)/) or $log->logconfess("Expected 'XXX: posts the ante YY' instead of '$line' (id $res->{id})");
  		push(@playersAnte, $player);
  		$res->{ante} = $amountAnte;
	  	$res->{pot} += $amountAnte;
  		$res->{putInPot}->[$codeRound{"preflop"}]->{$player} += $amountAnte;
  		$res->{players}->{$player}->{stackEnd} -= $amountAnte;
  		if ($res->{players}->{$player}->{stackEnd} == 0) {
  			$nbSeatsNotAllIn--;
  			$log->debug("Player $player is forced all-in with ante");
  		}
		$line = $self->parseHandGetNextLine($input, $lineNoRef, $res);
  	}
  	$res->{playersAnte} = \@playersAnte if (scalar(@playersAnte) > 0);
  	return 0 if (defined($res->{CANCELLED}));
  	$line = $self->parseOneBlind($input, $lineNoRef, $res, $line, "small", $res->{playerSB},\$nbSeatsNotAllIn); 
  	return 0 if (defined($res->{CANCELLED}));
  	$self->parseOneBlind($input, $lineNoRef, $res, $line, "big", $res->{playerBB},\$nbSeatsNotAllIn); # returns the previous line or undef, not used
  	return $nbSeatsNotAllIn;
}


sub parseOneBlind {
	my ($self, $input, $lineNoRef, $res, $currentLine, $smallOrBig, $expectedPlayer, $nbSeatsNotAllInRef) = @_;
	my $abbrev = ($smallOrBig eq "small") ? "SB" : "BB";
	my $log= $self->{logger};
	my $line;
	
  	my $stack = $res->{players}->{$res->{"player$abbrev"}}->{stackEnd}; 
  	if ($stack > 0) {  # no small blind line if SB player is all in already
  		my ($player, $dummyEuro, $amount) = ($currentLine =~ m/([^:]+): posts $smallOrBig blind ($euroUTF8Code)?([0-9.]+)/) or $log->logconfess("Expected 'XXX posts $smallOrBig blind YY', but found '$currentLine' (id $res->{id})");
  		$log->logconfess("Error: expected player '$expectedPlayer' at small blind but found player $player (id $res->{id})") if ($player ne  $expectedPlayer);
	  	$log->logconfess("Error: $smallOrBig blind amount differs: $res->{$abbrev} but $amount posted; stack for player $player: $stack (id $res->{id})") if (($amount != $res->{$abbrev}) && ($stack >= $res->{$abbrev}));
	  	$res->{pot} += $amount;
		$res->{putInPot}->[$codeRound{"preflop"}]->{$player} += $amount;
		$log->debug("Player $player pays $abbrev $amount");
		$res->{players}->{$player}->{stackEnd} -= $amount; 
  		if ($res->{players}->{$player}->{stackEnd} == 0) {
  			$$nbSeatsNotAllInRef--;
  			$log->debug("Player $player is forced all-in with $smallOrBig blind");
  		}
		$line = $self->parseHandGetNextLine($input, $lineNoRef, $res) if ($smallOrBig eq "small"); # inside the condition because if no SB the line is already the one for BB
  	} else {
  		return $currentLine;
  	}
}

sub _nextActivePlayer {
	my ($self, $current, $res, $index) = @_;
	my $log= $self->{logger};
	my $seats = $res->{activePlayersSeats};
	$log->debug("find $index th next active player after $current...");
	if ($index == 0) { # ok, this is tricky: two cases are needed because normally, the following loop is only intended to start from the
	                   # first active player including $current (i.e. if current is active same result, otherwise move to next). this is needed
	                   # in order to use the case index=0 (e.g. in parseHandRound "dynamic" loop condition). However there is a side-effect which
	                   # is due to the "defined(stoppedRound)" criterion: if the player has just folded then they re considered not active so the loop
	                   # below goes to next player, but the second loop will also go to next player, resulting in skipping the target player....
	                   # hence the two cases: if index==0 the sub resturns the FIRST active player (possibly the current one), and if index=N>0 it
	                   # returns the Nth active player found AFTER the current one.
		while (!defined($seats->[$current]) || defined($res->{players}->{$seats->[$current]}->{stoppedRound})) { # there is always one
			$log->trace("skipping seat $current (1)");
			$current = ($current+1 < scalar(@$seats))?$current+1:0;
		}
	} else {
		for (my $i=$index; $i >0; $i--) {
			$current++;
			while (!defined($seats->[$current]) || defined($res->{players}->{$seats->[$current]}->{stoppedRound})) { # there is always one
				$log->trace("skipping seat $current (2)");
				$current = ($current+1 < scalar(@$seats))?$current+1:0;
			}
			$log->debug("step $i: player[$current] = $seats->[$current]");
		}
	}
	return $current;
}


#
# returns a ref list containing players seats (still) involved and not allin.
# convention: if the hand is finished after this round (only one player involved) return the empty list
#
sub parseHandRound {
	my ($self, $input, $lineNoRef, $res, $roundId) = @_;
	my $log= $self->{logger};
	my $firstPlayerTalking = $self->_nextActivePlayer($res->{button},$res,1); 
	my $playerPrice = 0;
	my $actionNo = 0;
	my $nbAllIn=0;
	if ($roundId == $codeRound{"preflop"}) {
		$log->trace("preflop case");
		if ($res->{nbActivePlayers}==2) { # special case for heads up
			$firstPlayerTalking = $res->{button};
		} else {
			$firstPlayerTalking = $self->_nextActivePlayer($res->{button},$res,3); # standard UTG
		}
	 	$playerPrice = $res->{BB};
	}
	$log->debug("firstPlayer: activePlayers[$firstPlayerTalking] = '".$res->{activePlayersSeats}->[$firstPlayerTalking]."'");
	my @seatsInvolved;
	my @playerDone;
	for (my $current = $firstPlayerTalking ; !$playerDone[$current]; $current  = $self->_nextActivePlayer($current,$res,1) ) {
		push(@seatsInvolved, $current);
		$playerDone[$current]=1;
	} 
	my @seatsFoldedOrAllInThisRound;
	my @seatsCheckedOrCalledNotAllIn;
	my $lastBetOrRaiseSeat;
	my $current = shift(@seatsInvolved);
	while (defined($current)) {
#		for (my $current = $self->_nextActivePlayer($firstPlayerTalking, $res,0); !$playerDone[$current]; $current = $self->_nextActivePlayer($current, $res, 1)) {
		my $player = $res->{activePlayersSeats}->[$current];
		my $playerStack = $res->{players}->{$player}->{stackEnd};
		my $alreadyInPot = $res->{putInPot}->[$roundId]->{$player};
		$alreadyInPot -= $res->{ante} if (defined($res->{ante}) && $roundId == $codeRound{"preflop"}); # yeah, no very clean
		$alreadyInPot = 0 if (!defined($alreadyInPot));
		$log->debug("round $roundId, player $player (seat $current): stack=$playerStack");
		if (($roundId == $codeRound{"preflop"}) && (scalar(@seatsInvolved) == 0) && (scalar(@seatsCheckedOrCalledNotAllIn)==0)) {
			$log->trace("Special case BB player preflop after everyone folded or is all-in");
		} else {
			if ($playerStack == 0) { # if all-in (remark: this can normally happen only if this is the first iteration and a player was allin from a prevous round
				$nbAllIn++;
				$res->{players}->{$player}->{allIn} = $roundId if (!defined($res->{players}->{$player}->{allIn})); # normally only preflop if player is allin because of blind/ante (?)
			} else { # if not already  all-in
				if (!defined($lastBetOrRaiseSeat) || ($current != $lastBetOrRaiseSeat)) { # if not the last player who raised the price (if any)
					$log->trace("Player $player expected to speak");
					my ($amountPaid, $allIn, $newPlayerPrice, $dummyEuro, $actionCode) = (0, undef, $playerPrice, undef, undef);
					my $line = $self->parseHandGetNextLine($input, $lineNoRef, $res);
					my ($action, $amountInfo) =  ($line =~ m/^$player: ([a-z]+)(.+)?/) or $log->logconfess("Expected '$player: <action>' but found '$line' (id $res->{id})");
					if ($action eq "folds") {
						$actionCode = $foldCode;
						$res->{players}->{$player}->{stoppedRound} = $current;
						push(@seatsFoldedOrAllInThisRound, $current); 
					} elsif ($action eq "checks") {
						$actionCode = $checkCode;
					} elsif ($action eq "calls") {
						($dummyEuro, $amountPaid, $allIn) = ($amountInfo =~ m/^ ($euroUTF8Code)?([0-9.]+)( and is all-in)?\s*$/) or $log->logconfess("Expected ' €?<amount>' instead of '$amountInfo' in '$line' (id $res->{id})");
						$actionCode = $callCode;
					} elsif ($action eq "bets") {
						($dummyEuro, $amountPaid, $allIn) = ($amountInfo =~ m/^ ($euroUTF8Code)?([0-9.]+)( and is all-in)?\s*$/) or $log->logconfess("Expected ' €?<amount>' instead of '$amountInfo' in '$line' (id $res->{id})");
						$actionCode = $betCode;
						$newPlayerPrice = $amountPaid;
					} elsif ($action eq "raises") {
						my ($amountRaise, $totalAmount, $dummyEuro2);
						($dummyEuro, $amountRaise, $dummyEuro2, $totalAmount, $allIn) = ($amountInfo =~ m/^ ($euroUTF8Code)?([0-9.]+) to ($euroUTF8Code)?([0-9.]+)( and is all-in)?\s*$/) or $log->logconfess("Expected ' €?<amount> to €?<amount>' instead of '$amountInfo' in '$line' (id $res->{id})");
						$log->logconfess("Error: player '$player' raises $amountRaise to $totalAmount but previous price was $playerPrice (from '$line', id $res->{id})") if ($playerPrice + $amountRaise != $totalAmount);
						$log->logconfess("Error: player '$player' raises $amountPaid to $totalAmount but previously had put $alreadyInPot in pot (from '$line', id $res->{id})") if ($alreadyInPot > $amountRaise); # probably useless
						$amountPaid = $totalAmount - $alreadyInPot;
						$actionCode = $raiseCode;
						$newPlayerPrice = $totalAmount;
					} else {
							$log->Logconfess("Action not recognized '$action' in '$line' (id $res->{id})");
					}
					if ($actionCode != $foldCode) {
						$log->logconfess("Error: player '$player' pays $amountPaid but calculated stack is $playerStack (round $roundId, id $res->{id})") if ($playerStack < $amountPaid);
						$log->logconfess("Error: player '$player' pays $amountPaid but had put $alreadyInPot in pot and price to pay is $playerPrice (round $roundId, id $res->{id})") if (($actionCode != $raiseCode) && ($amountPaid+$alreadyInPot > $playerPrice));
						if (defined($allIn)) {
							$log->logconfess("Error: player '$player' pays $amountPaid and is all-in but calculated stack is $playerStack (round $roundId, id $res->{id})")  if ($playerStack != $amountPaid);
							push(@seatsFoldedOrAllInThisRound, $current);
							$res->{players}->{$player}->{allIn} = $roundId;
						} else {
							$log->logconfess("Error: player '$player' pays $amountPaid and is not all-in but had already put $alreadyInPot in pot and price to pay is $playerPrice (round $roundId, id $res->{id})") if (($actionCode != $raiseCode) && ($playerPrice != $amountPaid+$alreadyInPot));
						}
						if ($playerPrice < $newPlayerPrice) {
							$log->trace("PlayerPrice was $playerPrice and is now $newPlayerPrice");
							$playerPrice = $newPlayerPrice;
						}
						if (($actionCode == $checkCode) || ($actionCode == $callCode)) {
							push(@seatsCheckedOrCalledNotAllIn, $current) if (!defined($allIn));
						} else { # must be bet or raise
							push(@seatsInvolved, $lastBetOrRaiseSeat) if defined($lastBetOrRaiseSeat); # re-insert the last raiser 
							push(@seatsInvolved, @seatsCheckedOrCalledNotAllIn); # append the involved players after the current one (haven't spoken yet)
							$lastBetOrRaiseSeat = defined($allIn) ? undef : $current; # forget raiser if allin, otherwise store apart (doesn't have to play this round anymore if everyone checks) 
							@seatsCheckedOrCalledNotAllIn = ();
						}
					}
					$res->{moves}->[$roundId]->[$actionNo] = [$player, $actionCode, $amountPaid];
					$res->{putInPot}->[$roundId]->{$player} += $amountPaid;
					$res->{pot} += $amountPaid;
					$res->{players}->{$player}->{stackEnd} -= $amountPaid;
					$log->trace("end turn player $player paid $amountPaid, stack left is ".$res->{players}->{$player}->{stackEnd}."");
					$actionNo++;
				} #  endif not last raiser
				$log->trace("end player $player; playerPrice=$playerPrice, involved (left)=".join(",", @seatsInvolved)." seatsFoldedOrAllInThisRound=".join(",",@seatsFoldedOrAllInThisRound).", seatsCheckedOrCalledNotAllIn=".join(",",@seatsCheckedOrCalledNotAllIn).", lastBetOrRaiseSeat=".(defined($lastBetOrRaiseSeat)?$lastBetOrRaiseSeat:"UNDEF"));
			} # endif player not allin
		} 
		$current = shift(@seatsInvolved);
	} # end while (iteration over players)
	push(@seatsCheckedOrCalledNotAllIn, $lastBetOrRaiseSeat) if (defined($lastBetOrRaiseSeat)); # re-add the last raiser (if any) to the players still involved.
	# uncalled bets? fold or allin
	$self->parseHandBalanceRound($input, $lineNoRef, $res, $roundId, $playerPrice, \@seatsCheckedOrCalledNotAllIn, \@seatsFoldedOrAllInThisRound);
	if ((scalar(@seatsCheckedOrCalledNotAllIn)==1)  && ($nbAllIn==0)) {
		return []; # convention: if the hand is finished after this round (only one player involved) return the empty list
	} else {
		return \@seatsCheckedOrCalledNotAllIn;
	}
	
}



sub parseHandBalanceRound {
	my ($self, $input, $lineNoRef, $res, $roundId, $playerPrice, $playersStillInvolvedNotAllIn, $foldedOrAllInThisRound) = @_;

	my $log= $self->{logger};
	$log->debug("Balancing hand for round $roundId: playerPrice=$playerPrice, foldedOrAllInThisRound=".join(",",@$foldedOrAllInThisRound).", playersStillInvolvedNotAllIn=".join(",",@$playersStillInvolvedNotAllIn));
	my $minDiffWrtLeftOrAllIn = 0;

	if (scalar(@$playersStillInvolvedNotAllIn) == 1) { # there must be exatcly only one left if there is an uncalled bet (I think so...?)
		my $theOnlyPlayerLeft = $res->{activePlayersSeats}->[$playersStillInvolvedNotAllIn->[0]];
		foreach my $current (@$foldedOrAllInThisRound) { # there must be someone who folded or is all-in (so paid less than the full price)
			my $player = $res->{activePlayersSeats}->[$current];
			my $amountPaid = $res->{putInPot}->[$roundId]->{$player};
			$log->trace("player $current ($player) paid $amountPaid (total), price was $playerPrice");
			 # wrong if folded		$log->logconfess("Error: player $player is supposed to have been active this round but undefined amount this round") if (!defined($amountPaid));
			if ($amountPaid < $playerPrice) { 
				$log->trace("player $player paid $amountPaid < price = $playerPrice");
				$log->logconfess("Error checking balance for round $roundId: price is $playerPrice but player '$player' paid only $amountPaid and is not all-in (round $roundId, id $res->{id})") if ($res->{players}->{$player}->{stackEnd} > 0); # normally this can only happen if the player is allin since the player is still active
				# player is all-in: find the min diff if several players allin (amount of uncalled bet if only one player paid full price)
				$minDiffWrtLeftOrAllIn = ($playerPrice - $amountPaid) if (!$minDiffWrtLeftOrAllIn || ($playerPrice - $amountPaid < $playerPrice - $amountPaid)); 
				$log->trace("new minDiffWrtLeftOrAllIn=$minDiffWrtLeftOrAllIn");
			} else { # remark: it is possible that the player folded/is all-in with $amountPaid == $playerPrice
				$log->trace("player $player paid $amountPaid = price = $playerPrice");
			}
		}
		if ($minDiffWrtLeftOrAllIn>0) { # uncalled bet
			$log->trace("minDiffWrtLeftOrAllIn=$minDiffWrtLeftOrAllIn, expecting uncalled bet");
			my $line = $self->parseHandGetNextLine($input, $lineNoRef, $res);
			my ($dummyEuro, $amountRead, $playerRead) = ($line =~ m/Uncalled bet \(($euroUTF8Code)?([0-9.]+)\) returned to (\S+)/) or $log->logconfess("Error: expected 'Uncalled bet (...) returned to ...' but found $line (round $roundId, id $res->{id})");
			$log->logconfess("Error: expected uncalled bet for player $theOnlyPlayerLeft but found it for player $playerRead (round $roundId, id $res->{id})") if ($playerRead ne $theOnlyPlayerLeft);
			$log->logconfess("Error: expected uncalled bet amount for player $playerRead = $minDiffWrtLeftOrAllIn but found amount $amountRead (round $roundId, id $res->{id})") if ($amountRead != $minDiffWrtLeftOrAllIn);
			$log->trace("ok uncalled bet");
		} else { # otherwise no uncalled bet expected
			$log->trace("all the players paid the price, no uncalled bet expected");
		}
	} else { # otherwise no uncalled bet expected
			$log->trace("more than one player still involved (not all-in), no uncalled bet expected");
	}
	
}


sub parseShownDown {
	my ($self, $input, $lineNoRef, $res) = @_;

	my $log = $self->{logger};
	my @involved;	
	foreach my $playerSeat (@{$res->{activePlayersSeats}}) {
		my $player = $res->{activePlayersSeats}->[$playerSeat];
		push(@involved, $playerSeat) if (!defined($res->{players}->{$player}->{stoppedRound})); # if the player did not fold (thus is still involded at showdown)
	}
	# we expect to read N lines corresponding to hands shown or mucked (at this stage the hands are not read)
	for (my $i=0; $i<scalar(@involved); $i++) {
	    my $line = $self->parseHandGetNextLine($input, $lineNoRef, $res);
	}
	
	$log->logconfess("BUG: function not finished! (message added May 19 long time after doing the original code)");
	
}
	

=head2 parseTournament($@input, $lineNoRef, $history)

=cut

sub parseTournament {
	my ($self, $input, $lineNoRef, $history) = @_;
	my %res;
	my $log = $self->{logger};
	while ( 1 ) {	# iterate until a value is returned (the loop is used mainly to skip non regular cases if any)
	    while (($$lineNoRef < scalar(@$input)) &&  !($input->[$$lineNoRef] =~ m/^PokerStars Tournament #\d+,/))  {  # find the start of a tournament
	    	$log->trace("Skipping line '$input->[$$lineNoRef]'");
	    	$$lineNoRef++;
	    }
	    if ($$lineNoRef < scalar(@$input)) {  # if it's not the end of the data
	    	$log->trace("Reading line '$input->[$$lineNoRef]'");
	    	($res{id}) = ($input->[$$lineNoRef] =~ m/^PokerStars Tournament #(\d+),/) or $log->logconfess("Error: Expected 'PokerStars Tournament #' instead of '$input->$[line]'.");
	    	$$lineNoRef++;
	    	$log->trace("Reading line '$input->[$$lineNoRef]'");
			$log->debug("Reading tournament $res{id}");
			my $satellite = 0;
			if (defined($history) && ($history->existsTournament($res{id}))) {
				$log->info("Tournament #$res{id} is already in the history, skipping.");
			} elsif ($input->[$$lineNoRef] =~ m/^Freeroll/) {
				$log->logwarn("Warning: tournament #$res{id} is a freeroll, skipping.");
			} elsif ($input->[$$lineNoRef] =~ m@^Buy-In: €[0-9.]+/€[0-9.]+/€[0-9.]+ EUR$@) {
				$log->logwarn("Warning: tournament #$res{id} includes a bounty price pool, skipping.");
			} else {  # regular so far...
				if ($input->[$$lineNoRef] =~ m/Satellite\s*$/) { # satellite are considered, but the prizes as tournaments are ignored
					$res{satellite} = 1;
					$$lineNoRef++;
					$log->trace("Satellite found. Reading line '$input->[$$lineNoRef]'");
				}
				if ($input->[$$lineNoRef] =~ m@^Buy-In: [0-9.]+/[0-9.]+\s*$@) {
				    $log->logwarn("Warning: tournament #$res{id} doesn't have a regular buy-in price, skipping.");
				    return undef;
				}
				($res{buyInMinusRake}, $res{rake}, $res{currency}) = ($input->[$$lineNoRef] =~ m@^Buy-In: \S([0-9.]+)/\S([0-9.]+) (EUR|USD)\s*$@) or $log->logconfess("Error: Expected 'Buy-In: ' instead of '$input->[$$lineNoRef]' (tournament $res{id}).");
				$log->trace("res{buyInMinusRake}=$res{buyInMinusRake}, res{rake}=$res{rake}, res{currency}=$res{currency}");
				$$lineNoRef++;
				$log->trace("Reading line '$input->[$$lineNoRef]'");
				($res{nbPlayers}) = ($input->[$$lineNoRef] =~ m/^(\d+) players/) or $log->logconfess("Error: Expected 'X players' instead of '$input->[$$lineNoRef]' (tournament $res{id}).");
				$$lineNoRef++;
				$log->trace("Reading line '$input->[$$lineNoRef]'");
				$$lineNoRef++ if ($input->[$$lineNoRef] =~ m/^€[0-9.]+ EUR added to the prize pool by PokerStars\s*$/); # ok, skip this line
				my $x = $input->[$$lineNoRef+1];
				if ($input->[$$lineNoRef+1] =~ m/^Tournament is still in progress\s*/) {  # last possible case to skip
					$log->logwarn("Warning: tournament #$res{id} was still in progress, skipping.") ;
				} else {
				     # at this step we always return a value, UPDATE 2019 except if file is truncated (undef)
				    my $tournData = $self->_parseRegularTournament($input, $lineNoRef, \%res);
				    if (defined($tournData)) {
					$history->addTournament($tournData); 
					return \%res;
				    } else {
					$log->logwarn("Warning: the data for tournament #$res{id} is truncated, skipping.");
				    }
				}
			}
		} else {
			$log->debug("No more data, returning undef");
			return undef; # no more data
		}
	}
}




sub _parseRegularTournament {
	my ($self, $input, $lineNoRef, $res) = @_;
	my $log = $self->{logger};
	($res->{prizePool}) = ($input->[$$lineNoRef] =~ m/Total Prize Pool: €([0-9.]+) EUR/);
	$$lineNoRef++;
   	$log->trace("Reading line '$input->[$$lineNoRef]'");
	if ($res->{satellite}) {
		$log->trace("satellite is TRUE");
		$log->logconfess("Satellite: expected 'Target Tournament', found '$input->[$$lineNoRef]' (tournament $res->{id})") if (!$input->[$$lineNoRef] =~ m/^Target Tournament/);
   		$$lineNoRef++;
		if ($input->[$$lineNoRef] =~ m/^\d+ tickets to the target tournament\s*$/) { # optional, some satellite tournaments don't have this line apparently
		    $$lineNoRef += 2; # skip empty line
		}
	}
	($res->{startDate}, $res->{startTime}) = ( $input->[$$lineNoRef] =~ m@^Tournament started ([0-9/]+) ([0-9:]+) [CW]?ET@)  or $log->logconfess("Error: Expected 'Tournament started ' instead of '$input->[$$lineNoRef]' (tournament $res->{id}).");
	$$lineNoRef++;
   	$log->trace("Reading line '$input->[$$lineNoRef]'");
	if (!($input->[$$lineNoRef] =~ m/^\s*$/)) { # "Tournament finished..." is optional, replaced by an empty line if not present
		($res->{endDate}, $res->{endTime}) = ( $input->[$$lineNoRef] =~ m@^Tournament finished ([0-9/]+) ([0-9:]+) [CW]?ET@) or $log->logconfess("Error: Expected 'Tournament finished ' instead of '$input->[$$lineNoRef]' (tournament $res->{id}).");
	}
	$$lineNoRef++;
   	$log->trace("Reading line '$input->[$$lineNoRef]'");
	$res->{ranking} = $self->_parseTournamentRanking($input, $lineNoRef, $res);
	$$lineNoRef++; # skip empty line
	if (!defined($input->[$$lineNoRef])) {
	    $log->debug("Truncated data, returning undef");
	    return undef;
	}
   	$log->trace("Reading line '$input->[$$lineNoRef]' (lineNo=$$lineNoRef)");
	($res->{myPosition}) = ( $input->[$$lineNoRef] =~ m/^You finished in ([\d]+)/) or $log->logconfess("Error: Expected 'You finished in ' instead of '$input->[$$lineNoRef]' (tournament $res->{id}).");
	$$lineNoRef++;
	$log->debug("Tournament $res->{id}: done. Returning structure");
	return $res;
}



sub _parseTournamentRanking {
	my ($self, $input, $lineNoRef, $res) = @_;
	my $log = $self->{logger};
	my @ranking;
	my $seenDiff = 0;
	while (!($input->[$$lineNoRef] =~ m/^\s*$/)) {
		my ($pos,$player,$remaining) = ($input->[$$lineNoRef] =~ m/([\d]+): (.+) \(.*\),\s?(.*?)?\s*/) or $log->logconfess("Error: Expected '<N>: <player id>, <amount>' instead of '$input->[$$lineNoRef]' (tournament $res->{id}).");
		if (defined($remaining) && ($remaining ne '')) {
			if ($remaining eq "still playing") {
				$ranking[$pos] = { "player" => $player, "winnings" => undef };
			} else {
				my ($amount, $percentage);
				if ($res->{satellite}) {
					($amount) = ($remaining =~ m/€([0-9.]+)( \(qualified for the target tournament\))?\s*$/);
				} else {
					($amount, $percentage) = ($remaining =~ m/€([0-9.]+) \(([0-9.]+)%\)$/);
				}
				$log->logconfess("Can not read winnings amount in '$remaining'") if (!defined($amount));
				if (defined($percentage)) {
					my $checkWinnings = sprintf("%.2f", $res->{prizePool} * $percentage/100);
					if (abs($checkWinnings - $amount) >0.1) {
						if (!$seenDiff) {
							$log->logwarn("Warning: tournament $res->{id}: calculated winnings differ from actual winnings. prizePool=$res->{prizePool}, percentage=$percentage, winnings=$amount, winnigsComputed=$checkWinnings.");
							$seenDiff = 1;
						} else {
							$log->debug("Warning: tournament $res->{id}: calculated winnings differ from actual winnings. prizePool=$res->{prizePool}, percentage=$percentage, winnings=$amount, winnigsComputed=$checkWinnings.");
						}
					}
				} else {
					$percentage = sprintf("%.2s", $amount / $res->{prizePool} /100);
				}
				$ranking[$pos] = { "player" => $player, "winnings" => $amount, "prizePercentage" => $percentage };
				}
		} else {
			$ranking[$pos] = { "player" => $player, "winnings" => 0 };
		}
   		$$lineNoRef++;
    	$log->trace("Reading line '$input->[$$lineNoRef]'");
	}
	return \@ranking;
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

1;
