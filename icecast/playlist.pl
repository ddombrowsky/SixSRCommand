#!/usr/bin/perl
# $Id$
#
# DJ script.  This script picks the next song when run from 
# icecast (see ices-playlist.xml).  Originall written in perl.
# Perhaps it should be ported to ruby to match the rest of the project.

use File::Copy;
use strict;
use warnings;
use diagnostics;
use DBI;

use constant {
	SHUFFLE_LIST => 'shuffle_list.ctrl',
	LOGFILE => '/usr/local/log/ices/playlist.log'
};
my $HOME ="/home/davek/download/space/ices-2.0.1/conf/";
chdir($HOME); 

# import configuration
our $PLAYTYPE = undef;
our $ITEMNAME = undef;
our $ITEMORDER = undef;
require "playlist.conf";

sub play_control_dir(){

	# process removals first
	REMOVE: {
		open(RM,"<ctrl/remove") && do {
			my $rm = <RM>;
			last REMOVE if(not defined($rm));

			chomp($rm);

			last REMOVE if($rm eq "");

			# set file to played
			move($rm,$rm.".played") || die "move failed: <$rm> ".$!;
			close(RM) || die;

			# truncate file
			open(RM,">ctrl/remove") || die;
			close(RM);
		};
	}

	# read all files in ctrl directory
	opendir(CTRL,"ctrl");
	my @files =  grep(!/^\./,readdir(CTRL));

	# this will play the songs in canonical order
	@files=sort(@files) if(@files);

	close(CTRL);

	# process files in ctrl directory
	for(@files){
		# skip the remove file
		next if(/^remove$/);

		# skip the played files
		if(/\.played$/){
			next;
		}

		# this is the next file to be played, print it
		my $play = $HOME."ctrl/".$_;
		print($play."\n");

		# mark file to be removed
		open(RM,">ctrl/remove") || die;
		print(RM $play."\n");
		close(RM);

		print(LOG "Playing file from control dir: $play\n");

		# finish it
		return 1;
	}
	return 0;
}

sub play_by_file(){

	open(PL,"<playlist.txt") || die;
	my @playlist = <PL>;
	close(PL);

	# select next one from top of shuffeled list

	my $NEXT_INDEX = undef;
	my $shuf_file = $HOME.SHUFFLE_LIST;
	SHUFFLE:{
		my $max_size = scalar(@playlist);
		open(SHF,"<".$shuf_file) || do {
			#
			# create a new shuffle list
			#
			print(LOG localtime().": reshuffling playlist: size $max_size\n");

			open(SHF,">".$shuf_file) || do {
				last SHUFFLE;
			};

			# create array
			my @shuf = ();
			my $i = $max_size;
			while($i>0){
				push(@shuf,$i);
				$i--;
			}

			# shuffle playlist indexes
			$i=scalar(@shuf)*64;
			while($i-->0){
				my $r1 = int(rand(scalar(@shuf)));
				my $r2 = int(rand(scalar(@shuf)));

				my $tmp = $shuf[$r1];
				$shuf[$r1] = $shuf[$r2];
				$shuf[$r2] = $tmp;
			}

			for(@shuf){
				print(SHF "$_\n");
			}
			close(SHF);

			open(SHF,"<".$shuf_file) || do {
				last SHUFFLE;
			};
		};

		# get top line from file, and remove from file
		my $next = <SHF> || do{
			# file is empty, remove it
			print(LOG "shuffle file is empty\n");
			system("rm $shuf_file");
			last SHUFFLE;
		};
		my $is_empty = 1;
		my $tmpfile = "/tmp/shuff.tmp";
		open(TMP,">$tmpfile") || do{
			print(LOG "error opening tmp file\n");
			last SHUFFLE;
		};
		while(<SHF>){
			print(TMP $_);
		}
		close(SHF);
		close(TMP);
		system("mv $tmpfile $shuf_file");

		$next = int($next);

		if($next>0 && $next<=$max_size){
			# Success
			$NEXT_INDEX = ($next-1);
		}else{
			print(LOG "Ignoring invalid index: $next.  choosing random.\n");
		}
	}

	if(not defined($NEXT_INDEX)){
		# random fallback
		$NEXT_INDEX = int(rand(scalar(@playlist)));
		print(LOG "FALLBACK: Playing index $NEXT_INDEX\n");
	}

	my $play = $playlist[$NEXT_INDEX];

	# add one to NEXT_INDEX so the number matches those in SHUFFLE_LIST
	printf(LOG localtime().": playing #%5d: $play\n",($NEXT_INDEX+1));

	return $play;
}

sub play_by_dblist(){
	die "no MYSQL_USER environment defined" if(not $ENV{MYSQL_USER});
	die "no MYSQL_PASS environment defined" if(not $ENV{MYSQL_PASS});

	my $listid=$ITEMNAME;

	my $DBH = DBI->connect("DBI:mysql:database=sixthstreet;user=".$ENV{MYSQL_USER}.";password=".$ENV{MYSQL_PASS}) || die $DBI::errstr;

	# first, advance the now playing pointer
	my $cur_id = $DBH->selectall_arrayref("select id from list_data where is_playing=1")->[0]->[0] || die;
	my $next_id_p = $DBH->selectall_arrayref("
		select id 
		from list_data 
		where ordering > (
			select ordering 
			from list_data 
			where is_playing=1
		)
		and is_active=1
		and list_id=$listid
		order by ordering
		limit 1
	");
	
	# loop back to the top if needed
	if(scalar(@$next_id_p)==0){
		$next_id_p = $DBH->selectall_arrayref("
			select min(id)
			from list_data
			where list_id=$listid
			and is_active=1
		");
		die "fell of end of list, argh!" if(not $next_id_p);
	}

	my $next_id = $next_id_p->[0]->[0];
	die "next_id not defined!!" if(not defined($next_id));

	my $r=0;
	$r+=$DBH->do("update list_data set is_playing=0 where id=$cur_id\n");
	$r+=$DBH->do("update list_data set is_playing=1 where id=$next_id\n");

	my $next_song_p=$DBH->selectall_arrayref("
		select track_id, path
		from list_data
		left join tracks using (track_id)
		where is_playing=1;
	")->[0] || die;

	my $track_id = $next_song_p->[0];
	my $next_song = $next_song_p->[1];

	printf(LOG localtime().": (l:$listid) (u:$r) playing #%5d: $next_song\n",$track_id);
	return $next_song;
}

#
# MAIN
# 

open(LOG,">>".LOGFILE);

SELECT: {
	if(play_control_dir()){
		last SELECT;
	}

	# simple playlist file
	if($PLAYTYPE eq 'file'){
		print(play_by_file());
		last SELECT;
	}
	# database list
	if($PLAYTYPE eq 'dblist'){
		print(play_by_dblist());
		last SELECT;
	}

	print(STDERR "invalid PLAYTYPE: $PLAYTYPE\n");
}

close(LOG);
