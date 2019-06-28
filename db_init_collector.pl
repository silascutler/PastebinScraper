#!/usr/bin/perl
##########################################################################################
#
##########################################################################################
# Copyright (C) 2012, Silas Cutler
#      <Silas.Cutler@BlackListThisDomain.com 
#
#############################################################################################


use strict;
use warnings;
use MIME::Base64;
use LWP::UserAgent;
use DBI;
use Getopt::Long;


# ----- ARGUMENTS ----- #
my $database_name = "CollectorDB";
my $database_user = "root";
my $database_password = "";

my $date = `date +%Y-%m-%d`;
chomp($date);





initdb() if (defined( $ARGV[0] ) && ( $ARGV[0] =~ /init/));
##############
# Main
##############
my $dbh = DBI->connect('dbi:mysql:'. $database_name,$database_user,$database_password) or die "Connection Error: $DBI::errstr\n";


##############
# Subs
##############





sub initdb{
	### Create database.
	print "Creating Database Scheme . . .\n\n";
	system ("mysql -e \"create database $database_name\" ");

	### Connect to created Database
	my $dbh = DBI->connect('dbi:mysql:'. $database_name,$database_user,$database_password) or die "Connection Error: $DBI::errstr\n";


	# Create Table = watchlist
	print "Processing . . . table = pastes\n";
	my $sql_statement = "
		CREATE TABLE pastes_paths (
			paste_id VARCHAR(10) NOT NULL,
			site VARCHAR(200) NOT NULL, 
			path text NOT NULL
		)
	";
	my $sth = $dbh->prepare($sql_statement);
	$sth->execute;

	$sql_statement = "
		CREATE TABLE pastes ( 
			paste_id VARCHAR(10) NOT NULL,
			site VARCHAR(200),
			url VARCHAR(200),
			saved VARCHAR(10),
			pull_time int(10),
			PRIMARY KEY (paste_id)
				)
	";
	$sth = $dbh->prepare($sql_statement);
	$sth->execute;	
	print "Processing . . . table = collector_pulls\n";

	$sql_statement = "
		CREATE TABLE collector_log ( 
			pull_time int(10),
			site VARCHAR(200),
			total_failed int(10),
			total_success int(10),
			last_pulled VARCHAR(50),
			total_run_time int(10),
			PRIMARY KEY (pull_time)
				)
	";
	$sth = $dbh->prepare($sql_statement);
	$sth->execute;	
	print "Processing . . . table = collector_log\n";
	
	exit;
}




### \\fin




