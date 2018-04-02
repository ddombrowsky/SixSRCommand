#!/usr/bin/perl
# $Id: playlist.pl,v 1.16 2011-09-18 23:51:50 davek Exp $
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
	LOGFILE => 'playlist.log'
};

# read parameters
my $station_name = "pop"; # default station
if(scalar(@ARGV)>0){
	$station_name = $ARGV[0];
}

my $ctrl_dir_name = "";
my $conf_name = "";
if($station_name eq "pop"){
	$ctrl_dir_name = "control";
	$conf_name = "playlist.conf";
}elsif($station_name eq "tallinn"){
	$ctrl_dir_name = "control_tallinn";
	$conf_name = "playlist-tallinn.conf";
}else{
	print(STDERR "ERROR: invalid station name: $station_name\n");
	exit(-1);
}

# import configuration
our $PLAYTYPE = undef;
our $ITEMNAME = undef;
our $ITEMORDER = undef;
our $CONTROL_DIR = $ENV{PWD}."/".$ctrl_dir_name;
require $conf_name;

sub play_control_dir(){

	# process removals first
	REMOVE: {
		open(RM,"<$CONTROL_DIR/remove") && do {
			my $rm = <RM>;
			last REMOVE if(not defined($rm));

			chomp($rm);

			last REMOVE if($rm eq "");

			# set file to played
			if(not move($rm,$rm.".played")){
				print(STDERR "move failed: <$rm> ".$!);
			}
			close(RM) || die;

			# truncate file
			open(RM,">$CONTROL_DIR/remove") || die;
			close(RM);
		};
	}

	# read all files in $CONTROL_DIR directory
	opendir(CTRL,"$CONTROL_DIR");
	my @files =  grep(!/^\./,readdir(CTRL));

	# this will play the songs in canonical order
	@files=sort(@files) if(@files);

	close(CTRL);

	# process files in $CONTROL_DIR directory
	for(@files){
		# skip the remove file
		next if(/^remove$/);

		# skip the played files
		if(/\.played$/){
			next;
		}

		# this is the next file to be played, print it
		my $play = "$CONTROL_DIR/".$_;
		print($play."\n");

		# mark file to be removed
		open(RM,">$CONTROL_DIR/remove") || die;
		print(RM $play."\n");
		close(RM);

		print(LOG "Playing file from control dir: $play\n");

		# finish it
		return 1;
	}
	return 0;
}

# NOTE: this does not work for multiple lists, and 
# probably never will.  It is intended as a backup if
# there is no mysql database
sub play_by_file(){

	open(PL,"<playlist.txt") || die;
	my @playlist = <PL>;
	close(PL);

	# select next one from top of shuffeled list

	my $NEXT_INDEX = undef;
	my $shuf_file = "/home/davek/src/ices_conf/".SHUFFLE_LIST;
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
	die "no MYSQL_PASSWORD environment defined" if(not $ENV{MYSQL_PASSWORD});

	my $listid=$ITEMNAME;

	my $DBH = DBI->connect("DBI:mysql:database=sixthstreet;host=localhost;user=".$ENV{MYSQL_USER}.";password=".$ENV{MYSQL_PASSWORD}) || die $DBI::errstr;

	# first, advance the now playing pointer
	my $failure = 0;
	my $next_id_p;
	my $cur_id;
	my $cur_id_p;
	$cur_id_p = $DBH->selectall_arrayref("select id from list_data where is_playing=1 and list_id=$listid") ;
	if(defined($cur_id_p) && scalar(@$cur_id_p)>0){
		$next_id_p = $DBH->selectall_arrayref("
			select id 
			from list_data 
			where ordering > (
				select ordering
				from list_data 
				where is_playing=1
				and list_id=$listid
			)
			and is_active=1
			and list_id=$listid
			order by ordering
			limit 1
		") || do {$failure=1;};
	} else {$failure=1;}
	
	if($failure){
		# no track has is_playing=1
		print(STDERR "Looks like nothing is playing...... starting radio station over at min(id)\n");
		$DBH->do("update list_data set is_playing=0 where is_playing=1 and list_id=$listid");
		my $min=$DBH->selectall_arrayref("select min(id) from list_data where list_id=$listid")->[0]->[0] || die;
		$cur_id_p = [ [ $min ] ] ;
		$next_id_p = [ [ $cur_id_p->[0]->[0] ] ] ;
	};
	$cur_id = $cur_id_p->[0]->[0];

	if(scalar(@$next_id_p)==0){
		# there is no next element
		# loop back to the top 
		$next_id_p = $DBH->selectall_arrayref("
			select id
			from list_data
			where list_id=$listid
			and ordering=(
				select min(ordering)
				from list_data
				where list_id=$listid
				and is_active=1
			)
		");
		die "fell of end of list, argh!" if(not $next_id_p);
	}

	my $next_id = $next_id_p->[0]->[0];
	die "next_id not defined!!" if(not defined($next_id));
	die "cur_id not defined!!" if(not defined($cur_id));

	my $r=0;
	$r+=$DBH->do("update list_data set is_playing=0 where id=$cur_id\n") || die;
	$r+=$DBH->do("update list_data set is_playing=1 where id=$next_id\n") || die;
	if($r<2){
		print(STDERR "error updating database.  r=$r\n");
	}

	my $next_song_p=$DBH->selectall_arrayref("
		select track_id, path
		from list_data
		left join tracks using (track_id)
		where is_playing=1
		and list_id=$listid;
	")->[0] || die "died getting track path form DB";

	my $track_id = $next_song_p->[0];
	my $next_song = $next_song_p->[1];
	if(not defined($next_song)){
		$next_song='';
	}

	if(-f $next_song){
		printf(LOG localtime().": (list_id:$listid) playing #%5d: $next_song\n",$track_id);
	}else{
		printf(LOG localtime().": (list_id:$listid) playing #%5d: ERROR: file not found: $next_song\n",$track_id);
		$next_song='';
	}
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
		print(play_by_file()."\n");
		last SELECT;
	}
	# database list
	if($PLAYTYPE eq 'dblist'){
		my $next = '';
		my $break_count = 0;

		#  try 100 times to get a song
		while($next eq ''){
			$next=play_by_dblist();
			$break_count++;
			if($break_count > 100){last;}
		}

		print($next."\n");
		last SELECT;
	}

	print(STDERR "invalid PLAYTYPE: $PLAYTYPE\n");
}

close(LOG);
