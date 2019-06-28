#!/usr/bin/perl
#############################################################################################
#
# __________                  __        ___.   .__        
# \______   \_____    _______/  |_  ____\_ |__ |__| ____  
#  |     ___/\__  \  /  ___/\   __\/ __ \| __ \|  |/    \ 
#  |    |     / __ \_\___ \  |  | \  ___/| \_\ \  |   |  \
#  |____|    (____  /____  > |__|  \___  >___  /__|___|  /
#                 \/     \/            \/    \/        \/ 
#   _________                          .__                
#  /   _____/ ________________  ______ |__| ____    ____  
#  \_____  \_/ ___\_  __ \__  \ \____ \|  |/    \  / ___\ 
#  /        \  \___|  | \// __ \|  |_> >  |   |  \/ /_/  >
# /_______  /\___  >__|  (____  /   __/|__|___|  /\___  / 
#         \/     \/           \/|__|           \//_____/  
#
# Copyright (C) 2010 - 2012, Silas Cutler
#      <Silas.Cutler@BlackListThisDomain.com>
#		(c) 2010 - 2012
#
# This program is private software; redistribution, execution and/or modification is 
#      prohibited, unless written consent is given from the author which states the 
#      specific actions that the code can be used for. 
#
#############################################################################################
# Collector
#	- Scrapes Pastie & PasteBay (Both Sides)
#			
#
##############################################################################################


use strict;
use warnings;
use LWP::Simple;
use LWP::UserAgent;
use PerlIO::gzip;
use DBI;



use constant MOTD => q{
          _,-,-.
        ,-: |.'-:|..-.		Collector.pl -  1.1
   _..-:| | `-`. \.--'
 <...--:'-|_|_|;  \
        \   /     /
         :      ,'
         |   |  |   ReverSecurity.com / #### ###########
         |   +  |     For ongoing research with Pastebin Sites
         |   |  |   ASCII art by SSt

	usage : ./Collector.pl 			[ Pulls all recent Posts      ]

Build with:
   - PasteBay
   - wwwPastebay
   - SkidPaste
   


};

##################################################################################################
############## Variables 
##################################################################################################
my $database_name = "CollectorDB";
my $database_user = "root";
my $database_password = "";

##################################################################################################
############## Main 
##################################################################################################
my $dbh = DBI->connect('dbi:mysql:'. $database_name,$database_user,$database_password) or die "Connection Error: $DBI::errstr\n";

chdir("/opt/PastebinScraping/bin/");

my @stats =();
print MOTD;
print "------+          Starting                 +------\n";


getPasteBay();
getPasteBay_www();
getSkidPaste();



##################################################################################################
############## Subs 
##################################################################################################

sub dumpPaste {

	my $pasteID = shift;
	my $site = shift;
	my $raw_paste = shift;
		
	my $path = '../saved/' . $site . "/" . $site . "-" . $pasteID . ".gz";

	open (DUMPPASTE, ">>:gzip", $path);
		print DUMPPASTE $raw_paste;
	close (DUMPPASTE); 
}  

sub db_insert_completed_pull{
# +----------------+--------------+------+-----+---------+-------+
# | pull_time      | int(10)      | NO   | PRI | 0       |       |
# | site           | varchar(200) | YES  |     | NULL    |       |
# | total_failed   | int(10)      | YES  |     | NULL    |       |
# | total_success  | int(10)      | YES  |     | NULL    |       |
# | last_pulled    | varchar(50)  | YES  |     | NULL    |       |
# | total_run_time | int(10)      | YES  |     | NULL    |       |
# +----------------+--------------+------+-----+---------+-------+

	my $time_start = shift;
	my $site = shift;
	my $total_failed = shift;
	my $total_success = shift;
	my $last_pulled = shift;
	my $run_time = shift;
	my $sth = $dbh->prepare("INSERT INTO collector_log ( pull_time, site, total_failed, total_success, last_pulled, total_run_time) VALUES  ( ?, ?, ?, ?, ?, ? )");
	$sth->execute( $time_start, $site, $total_failed, $total_success, $last_pulled, $run_time );

	return;
	
}
sub db_insert_paste{
# +-----------+--------------+------+-----+---------+-------+
# | paste_id  | varchar(10)  | NO   | PRI | NULL    |       |
# | site      | varchar(200) | YES  |     | NULL    |       |
# | url       | varchar(200) | YES  |     | NULL    |       |
# | saved     | varchar(10)  | YES  |     | NULL    |       |
# | pull_time | int(10)      | YES  |     | NULL    |       |
# +-----------+--------------+------+-----+---------+-------+	
	my $paste_id = shift;
	my $site = shift;
	my $base_url = shift;
	my $status = shift;
	my $pull_time = shift;
	my $sth = $dbh->prepare("REPLACE INTO pastes ( paste_id, site, url, saved, pull_time ) VALUES  ( ?, ?, ?, ?, ? )");
	$sth->execute( $paste_id, $site, $base_url , $status , $pull_time );
	
	return;
}

sub db_select_last_paste{

	my $site = shift;	
	my $last_paste_id = "";
	my $request_handle = $dbh->prepare("select last_pulled from collector_log where (site = ? ) ORDER BY pull_time limit 1;");
	$request_handle->execute( $site );
	$request_handle->bind_columns(undef, \$last_paste_id );
	$request_handle->fetch();
	
	return $last_paste_id;
}


sub getPasteBay_www {
	
	print "------+      Initializing Pastebay_www    +------\n";
	my $time_start = time();
	my $newestPost = 0;
	my $site = "wwwpastebay";
	my $failed_count = 0;
	my $success_count = 0;
	my $counter = db_select_last_paste($site);
	
	my $ua = LWP::UserAgent->new(agent => q{Mozilla/5.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NETCLR 1.1.4322)},);
	$ua->timeout(10);
	my $url = 'http://www.pastebay.net/';
	my $rsp = $ua->get($url);

	
	if ( ! $rsp->is_success) {
		print " [X] SiteDown or we are being blocked..!!!\n";
		return;
	}
		
		
	my @current_pasteIDs = split /\n/, $rsp->content;
	foreach (@current_pasteIDs) {
		if ( ($_ =~ /secs ago/i) || ($_ =~ /mins ago/) || ($_ =~ /hours ago/) || ($_ =~ /hour ago/) )  {
			$_ =~ s/.*net\///;
			$_ =~ s/\x22.*//;
			$newestPost = $_;
			last;
		}
	}

	print "------+      Pulling Pastebay_www         +------\n";
	if ($newestPost == 0){
		print "[X] Problem pulling latest paste\n";
	}
	
	while (  $counter <= $newestPost ) {
		$url = 'http://www.pastebay.net/pastebay.php?dl='.$counter;
		my $rsp = $ua->get($url);
		print " [ ] Attempting to fetch $counter\n";

		if ( $rsp->is_success ) {
			print " [+] Dumping ... $counter\n";
			$success_count++;
			dumpPaste( $counter, $site, $rsp->content );	
			db_insert_paste( $counter, $site, $url, "success", time );
			 
		}else{
			db_insert_paste( $counter, $site, $url, "failed", time );
			$failed_count++;	
			
		}
		$counter++;	
	}

	
	my $time_end = time();
	my $exec_time = $time_end - $time_start;
	print "------+      Updating Database            +------\n";

	db_insert_completed_pull( $time_start, $site, $failed_count, $success_count, $newestPost, $exec_time);
	print "------+      Finished Pastebay_www        +------\n";
}

sub getPasteBay {
	print "------+      Initializing Pastebay        +------\n";
	my $time_start = time();
	my $newestPost = 0;
	my $site = "pastebay";
	my $failed_count = 0;
	my $success_count = 0;
	my $counter = db_select_last_paste($site);

	
	my $ua = LWP::UserAgent->new(agent => q{Mozilla/5.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NETCLR 1.1.4322)},);
	$ua->timeout(10);
	my $url = 'http://pastebay.net/';
	my $rsp = $ua->get($url);

	
	if ( ! $rsp->is_success) {
		print " [X] SiteDown or we are being blocked..!!!\n";
		return;
	}
		
		
	my @current_pasteIDs = split /\n/, $rsp->content;
	foreach (@current_pasteIDs) {
		if ( ($_ =~ /secs ago/i) || ($_ =~ /mins ago/) || ($_ =~ /hours ago/) || ($_ =~ /hour ago/) )  {
			$_ =~ s/.*net\///;
			$_ =~ s/\x22.*//;
			$newestPost = $_;
			last;
		}
	}
	print "------+      Pulling Pastebay             +------\n";
	if ($newestPost == 0){
		print "[X] Problem pulling latest paste\n";
	}
	
	while (  $counter <= $newestPost ) {
		$url = 'http://pastebay.net/pastebay.php?dl='.$counter;
		my $rsp = $ua->get($url);
		print " [ ] Attempting to fetch $counter\n";

		if ( $rsp->is_success ) {
			print " [+] Dumping ... $counter\n";
			$success_count++;
			dumpPaste( $counter, $site, $rsp->content );	
			db_insert_paste( $counter, $site, $url, "success", time );
			 
		}else{
			db_insert_paste( $counter, $site, $url, "failed", time );
			$failed_count++;	
			
		}
		$counter++;	
	}

	
	my $time_end = time();
	my $exec_time = $time_end - $time_start;
	print "------+      Updating Database            +------\n";

	db_insert_completed_pull( $time_start, $site, $failed_count, $success_count, $newestPost, $exec_time);
	print "------+      Finished Pastebay            +------\n";
}

sub getSkidPaste {
	print "------+      Initializing SkidPaste       +------\n";
	my $time_start = time();
	my $last_pulled = "";
	my $site = "skidpaste";
	my $failed_count = 0;
	my $success_count = 0;
	my @current_pasteIDs = ();
	
	my $ua = LWP::UserAgent->new(agent => q{Mozilla/5.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NETCLR 1.1.4322)},);
	$ua->timeout(10);
	my $url = 'http://skidpaste.org/pastes.cgi';
	my $rsp = $ua->get($url);

	
	if ( ! $rsp->is_success) {
		print " [X] SiteDown or we are being blocked..!!!\n";
		return;
	}
	print "------+      Processing SkidPaste         +------\n";

		
	foreach my $paste ( $rsp->content =~ /<tr\sclass=\"gradeA\">\n<td><a href="([A-Za-z0-9]*)\">/g ){
		my $paste_valid = "";
		my $request_handle = $dbh->prepare("select paste_id from pastes where paste_id = ?");
		$request_handle->execute( $paste );
		$request_handle->bind_columns(undef, \$paste_valid );
		$request_handle->fetch();
		if ($paste_valid ne $paste){
			push(@current_pasteIDs, $paste);
		}
	}
	
	print "------+      Pulling SkidPaste            +------\n";
	
	foreach my $paste_id( @current_pasteIDs ){
		$url = 'http://skidpaste.org/'. $paste_id . '.download';
		my $rsp = $ua->get($url);
		print " [ ] Attempting to fetch $paste_id\n";

		if ( $rsp->is_success ) {
			print " [+] Dumping ... $paste_id\n";
			$success_count++;
			dumpPaste( $paste_id, $site, $rsp->content );	
			db_insert_paste( $paste_id, $site, $url, "success", time );
			$last_pulled = $paste_id;
			 
		}else{
			db_insert_paste( $paste_id, $site, $url, "failed", time );
			$failed_count++;	
			
		}
	}

	
	my $time_end = time();
	my $exec_time = $time_end - $time_start;
	print "------+      Updating Database            +------\n";

	db_insert_completed_pull( $time_start, $site, $failed_count, $success_count, $last_pulled, $exec_time);
	print "------+      Finished SkidPaste           +------\n";

}





