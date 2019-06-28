#!/usr/bin/env python

import sys
import leveldb

def main():
	db = leveldb.LevelDB("/opt/PastebinScraping/db")
	try:
		print db.Get(sys.argv[1])
	except Exception, e:
		print "[X] Exception: %s" % e
if __name__ == "__main__":
	main()
