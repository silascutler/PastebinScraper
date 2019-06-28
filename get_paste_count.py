#!/usr/bin/env python

import os
import sys
import leveldb
import datetime

def main():
        db = leveldb.LevelDB("/opt/PastebinScraping/db")
	count = 0
	for k,v in db.RangeIter():
		count += 1
	print count

if __name__ == "__main__":
        main()

