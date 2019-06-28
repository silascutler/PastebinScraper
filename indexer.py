#!/usr/bin/env python

import os
import sys
import leveldb
import datetime

def main():
	db = leveldb.LevelDB("/opt/PastebinScraping/db")
	ydate = str((datetime.datetime.today() - datetime.timedelta(1)).strftime('%Y-%m-%d'))
	ydate = str((datetime.datetime.today()).strftime('%Y-%m-%d'))

	for rfile in os.listdir('/opt/PastebinScraping/Repository/' + ydate + '/Pastebin/'):
		pid = str(rfile[9:][:-3])
		db.Put(pid, '/opt/PastebinScraping/Repository/' + ydate + '/Pastebin/' + rfile )


if __name__ == "__main__":
	main()




