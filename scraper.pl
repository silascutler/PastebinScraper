#!/usr/bin/perl
#############################################################################################
#
# __________				  __		___.   .__		
# \______   \_____	_______/  |_  ____\_ |__ |__| ____  
#  |	 ___/\__  \  /  ___/\   __\/ __ \| __ \|  |/	\ 
#  |	|	 / __ \_\___ \  |  | \  ___/| \_\ \  |   |  \
#  |____|	(____  /____  > |__|  \___  >___  /__|___|  /
#				 \/	 \/			\/	\/		\/ 
#   _________						  .__				
#  /   _____/ ________________  ______ |__| ____	____  
#  \_____  \_/ ___\_  __ \__  \ \____ \|  |/	\  / ___\ 
#  /		\  \___|  | \// __ \|  |_> >  |   |  \/ /_/  >
# /_______  /\___  >__|  (____  /   __/|__|___|  /\___  / 
#		 \/	 \/		   \/|__|		   \//_____/  
#
# Copyright (C) 2010 - 2012, Silas Cutler
#	  <Silas.Cutler@BlackListThisDomain.com>
#		(c) 2010 - 2013
#
#
#############################################################################################
# scraper 
#	- Scrapes pastebin for new pastes
#
##############################################################################################


use strict;
use warnings;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
use threads;
use threads::shared;
use Thread::Pool;
use PerlIO::gzip;
use DBI;


use constant MOTD => q{
		  _,-,-.
		,-: |.'-:|..-.		  scraper.pl -  4.6 dev
   _..-:| | `-`. \.--'
 <...--:'-|_|_|;  \
		\   /	 /
		 :	  ,'
		 |_ | __|   ReverSecurity.com
		 |_ X __|	 For ongoing research with Pastebin
		 |  |   |   ASCII art by SSt

		usage : ./scraper.pl					
};

chdir("/opt/PastebinScraping/bin/");
print MOTD;
my $time_start = time();




########################################################################################################################
############## Main
#######################################################################################################################
#Setup Variables
my $database_name = "PastebinDB";
my $database_user = "root";
my $database_password = "";

my @proxyList = createProxyList();
my @known_good_proxies = ();
my @savedPastes : shared = ();
my @failedPastes : shared = ();
my $failedtries : shared = 0;
##############
my $dbh = DBI->connect('dbi:mysql:'. $database_name,$database_user,$database_password) or die "Connection Error: $DBI::errstr\n";

init_proc($time_start);
my $paste_sql = "REPLACE INTO pastes ( paste_id, url, saved, pull_time ) VALUES  ( ?, ?, ?, ? )";



my $archive_uri = 'http://pastebin.com/archive';
my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NETCLR 1.1.4322)},);

my $archivePage = $ua->get($archive_uri, Cookie => '<REMOVED>');
if (! $archivePage->is_success){
	print "[-] FAILED to pull archive";
}
my @paste_ids = $archivePage->content =~ /class=\"i_p0\" alt=\"\" border=\"0\" \/><a href=\"\/([A-Za-z0-9]+)\"/g;

#Starting Dump from Pastebin.com
print "\n------+  Starting Dump from Pastebin  +------\n";
print " [+] Total Pastes: " . ( $#paste_ids + 1) . "\n";
my $threads = 30;
my @_threads = ();

print "------+		  Making Threads		 +------\n";
my $pool = Thread::Pool->new({
							 workers => $threads,
							 do => \&getPasteHandler,
							 });

print "------+		  Starting Pull		  +------\n";
my $timeout = 100;

foreach( reverse(@paste_ids) ){
		push(@_threads, $pool->job($_) );
}

$pool->join;
$pool->shutdown;

print "------+		  Complete			   +------\n";

my $time_end = time;
my $time_total = $time_end - $time_start;

my $db_time_start = time;

print "------+		Logging Results		  +------\n";

my $sth = $dbh->prepare("INSERT INTO scraper_log ( pull_time, total_pastes, total_failed, total_success, total_attempted, total_run_time ) VALUES  ( ?, ?, ?, ?, ? ,? )");
$sth->execute( $time_start, ( $#paste_ids + 1), ($#failedPastes + 1), ($#savedPastes + 1), $failedtries, $time_total );


foreach my $paste_id (@savedPastes){
	$sth = $dbh->prepare($paste_sql);
	$sth->execute( $paste_id , 'http://www.pastebin.com/'.$paste_id , "success", time );
}	
foreach my $paste_id (@failedPastes){
	$sth = $dbh->prepare($paste_sql);
	$sth->execute( $paste_id , 'http://www.pastebin.com/'.$paste_id , "failed", time );
}	



my $db_time_end = time;
my $db_time_total = $db_time_end - $db_time_start;

print "	 -= [ Execution time = $time_total (db = $db_time_total ] =-\n";
exitBanner();




print " [X] THIS SHOULD NEVER BE SEEN...\n";

##########################################################################################
####  SUB ROUTINES
##########################################################################################

sub init_proc{

	my $db_time_start = shift;

	if ( ( -e "./.scraper.pl.loc") && ( -s "./.scraper.pl.loc") ){
		print "Checking System\n";
			open (FILE, "<", "./.scraper.pl.loc");
					my $PID = <FILE>;
			close FILE;
							
		my $running_ccheck = `ps -A | grep "$PID"`;
		print "-- $running_ccheck \n";
		
		if ($running_ccheck =~ /scraper.pl/){
			print "Killing Duplicate!\n";
			system("kill -9 $PID");
		}
		if ( ( -e "./.scraper.pl.tmr.loc") && ( -s "./.scraper.pl.tmr.loc") ){		
		
			open (FILE, "<", "./.scraper.pl.tmr.loc");
				my $old_time = <FILE>;
			close FILE;
			
			my $sth = $dbh->prepare("INSERT INTO scraper_log ( pull_time, total_pastes, total_failed, total_success, total_attempted, total_run_time ) VALUES  ( ?, ?, ?, ?, ? ,? )");
			$sth->execute( $old_time, 0 , 0 , 0 , 0 , 0 );		
			
			system("/bin/rm ./.scraper.pl.tmr.loc");		

		}
		system("/bin/rm ./.scraper.pl.loc");
		
	}	 
	
	
	
	
	   open (DUMP, ">",  "./.scraper.pl.loc");
		   print DUMP $$;
	   close (DUMP);
	   
	   open (DUMP, ">",  "./.scraper.pl.tmr.loc");
		   print DUMP $db_time_start;
	   close (DUMP);


}

sub close_proc{
	print "------+		Cleaning Up			  +------\n";
	system("/bin/rm ./.scraper.pl.loc");
	system("/bin/rm ./.scraper.pl.tmr.loc");
}

sub getPasteHandler {		
	my $limit = 10;
		my $status ="false";
		my $saved_status = 0;
	my $proxy = $proxyList[rand(@proxyList)];
	my $paste = shift;
		while ($limit > 0) {
			if ($limit < 3 ){
				print " [!] Approaching Failed Limit for $paste\n";
			my $proxy = $known_good_proxies[rand(@proxyList)];
			$saved_status = 1;				
		}
		my $rsp = dlPaste($proxy, $paste);
		if ( !( $rsp->is_success ) || ($rsp->headers_as_string !~ /(Content-Transfer\-Encoding: binary)/i) ) {
			my $reason = "";
			if (defined($1)) { $reason = "(Bad Header!)"; 
				print " [-] FAILED - $paste through $proxy " . $reason . " : retying\n";
			}
			addFailedAttemp();
		}
		else {	
					if ($saved_status == 1 ){
						print " [+] Saved $paste through $proxy\n" if  $rsp->is_success;   
					}
					dumpPaste($paste, $rsp->content );
			   
			   		push(@savedPastes, $paste);

			#addPasteSaved();
			push(@known_good_proxies, $proxy);
			return 1;
		}
			$limit--;

	}	
	print " [X] Failed Limit! Killing thread for $paste !!!\n"; 
	push(@failedPastes, $paste);
	#addPasteFailed();
	return 1;
}

# Generate List of proxies for the script to use.  A lit of proxies can be found at :
sub createProxyList{
		open (FILE, "<", "/var/proxies/proxy.lst");
			my @proxyList = <FILE>;
		close FILE;
		if ($#proxyList < 1) { print "Proxy List is empty...Quitting.\n"; exit; }
		foreach(@proxyList){ s/(\n|\r)//g; }
		return @proxyList;
}


# Routine for dumping the output
sub dumpPaste {
		my $printPaste = shift;
		my $printOutPut = shift;
		my $path = '../saved/pastebin/pastebin-' . $printPaste. '.gz';

		open (DUMP, ">:gzip", $path);
				print DUMP $printOutPut;
		close (DUMP);
		return;
}

sub addPasteSaved{
#	$savedPastes++;
}
sub addPasteFailed{
#	$failedPastes++;
}
sub addFailedAttemp{
	$failedtries++;
}


sub exitBanner{
	
	print " [+] Collected        : " . ($#savedPastes + 1) . " Pastes\n";
	print " [-] Lost	     : " . ($#failedPastes  + 1) . " Pastes\n";
	print " [x] Failed Attempts  : " . $failedtries . " Pastes\n";
	close_proc();
	exit;
	
}

sub dlPaste{
	my $proxy = shift;
	my $paste = shift;
	my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NETCLR 1.1.4322)},);
	$ua->cookie_jar( { 'pastebin_user' => '<REMOVED>' } );
	$ua->timeout(10);
	$ua->proxy(['http'] => "http://$proxy" );
	return($ua->get('http://pastebin.com/download.php?i=' . $paste) ) ;
}

########################################################################################################################
############## End Subroutines
#######################################################################################################################


#######################################################################################################################
#			Change Control
########################################################################################################################
# V3.5 - + Proxy Support
#
########
# V3.6  - So, Because 3.5 took too bloody long, threading was implimented.  This, combined
#			   with the proxy should make this work and be safely publicly releasable
#
########
# V3.7 - Added support for targeting Individual users pastebin folders
#
#######
# v4.0 - Made Major changes to the threading process. Fixed issue with Proxies not updating on failed attempts
#		  and pastes being lost.  Script also will force quit after 6 minutes.
#
######
# v4.1 - Threading Problems.  Adding section to the threads
#		  that kill after 6 iterations...Trying to stop the system exploding.
#
######
# v4.2 - Cleaned code.  Fixed Proxys to remove \r & \n.  Implimented the getPasteHandler.  
#			Removed Old Threading.  Implimented new version
#
######
# V4.3 - Threading Redesigned and initialized End Reports
#
######
# v4.4 - Cleaned formatting and rechanged comments 
#
#####
# v4.5 - Script is failing due to Thread Spinup time.  
#
#####
# v4.6 - Adding benchmarking.  
#			Adding @known_good_proxies saver 
#
#####
# v4.7	- Fixed (attempted to) ordering of paste pulling.
#
##########################################
