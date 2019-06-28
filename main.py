#!/usr/bin/env python
#############################################################################################
#
# __________                  __        ___.   .__        
# \______   \_____    _______/  |_  ____\_ |__ |__| ____  
#  |     ___/\__  \  /  ___/\   __\/ __ \| __ \|  |/    \ 
#  |    |     / __ \_\___ \  |  | \  ___/| \_\ \  |   |  \
#  |____|    (____  /____  > |__|  \___  >___  /__|___|  /
#                 \/     \/            \/    \/        \/  
#   _________                                        
#  /   _____/ ________________  ______   ___________ 
#  \_____  \_/ ___\_  __ \__  \ \____ \_/ __ \_  __ \
#  /        \  \___|  | \// __ \|  |_> >  ___/|  | \/
# /_______  /\___  >__|  (____  /   __/ \___  >__|   
#         \/     \/           \/|__|        \/       
#
# Copyright (C) 2010 - 2016, Silas Cutler
#         <Silas.Cutler@BlackListThisDomain.com>
#          (c) 2010 - 2016
#
#
#############################################################################################
# scraper 
#       - Scrapes pastebin for new pastes
#
##############################################################################################


import requests
import re
import sys
import random
import gzip
import time
import json
import datetime
from pymongo import MongoClient

import traceback


print "[*] Pre-Setup"

class db_handle(object):
	def __init__(self):
		self.connect()

	def connect(self):	
		self.client = MongoClient('<REMOVED>', 27017)
		self.mdb = self.client['pastebin']

	def error_handler(self):
		try:
			self.connect()
		except:
			print "Failed to handle error by reconnecting"
	def submit(self, indata):
                cpages = self.mdb['pastes']
                try:
                        post_id = cpages.insert_one( indata )
                except Exception, e:
                        traceback.print_exc()
			self.error_handler()
                        print "[e] Exception w_monogo: %s" % e
	

class paste(object):
	def __init__(self, raw_paste):
		self.id = raw_paste['key']
		self.title = raw_paste['title']
		self.syntax = raw_paste['syntax']
		self.date = raw_paste['date']
		self.expire = raw_paste['expire']
		self.size = raw_paste['size']
		self.path = '/opt/PastebinScraping/Repository/' + str(datetime.date.today()) + '/' + 'pastebin.' + self.id + '.gz'

	def print_short(self):
		print "[%s] %s" % (self.id, self.title)

	def save_paste(self, content):
		try:
			save_handle = gzip.open('/opt/PastebinScraping/saved/pastebin/pastebin-%s.gz' % (self.id), 'wb')	
		except Exception, e:
			print e
			return False 
		try: 
			save_handle.write(content)
		except Exception, e:
			print "[X] Error in save_paste %s" % (e)
			return False
		
		save_handle.close()

	def pull_paste(self):
		try:
			paste_path = 'https://scrape.pastebin.com/api_scrape_item.php?i=%s' % ( self.id)
			raw = requests.get(paste_path, timeout=10 )
		except Exception, e:
			print "[X] exception in paste pull %s" % e
			pass
		self.save_paste(raw.content)


	def log(self):
		notif = {}
                notif['id'] = self.id.encode("utf-8") 
                notif['title'] = self.title.encode("utf-8") 
                notif['syntax'] = self.syntax.encode("utf-8") 
                notif['date'] = int(self.date.encode("utf-8"))
                notif['expire'] = self.expire.encode("utf-8") 
                notif['size'] = self.size.encode("utf-8")
                notif['path'] = self.path.encode("utf-8")

		return notif


	def run(self):
                self.print_short()
                self.pull_paste()
	
def pastebin_request(uri):
	try:
		raw = requests.get(uri, timeout=10 )
		return raw
	except Exception, e:
		print "[X] Failed to pull %s from Pastebin [%s]" % (uri, e)
	
	return False 


def main():
	print "[*] Starting ... %s " % (int(time.time()))
	while True:
#		db = db_handle()
		t_index = {}
		try:
			archive = get_list()
			if archive == False:
				print "Failed to pull Archive Page"
			for t_paste in archive:
				#print "Starting scrape: %s" % (t_paste['key'] + " / " + t_paste['title'])
				time.sleep(.5)
				t = paste(t_paste)
#				db.submit(t.log())
				t.run()
		except Exception, e:
			print "Exception in main: %s" % e
		time.sleep(60)
	
def get_list():
	try:
		r_archive = pastebin_request('https://scrape.pastebin.com/api_scraping.php?limit=250')
	except Exceltion, e:
		print e
		return 1
	return r_archive.json()


if  __name__ == "__main__":
	try:
		main()
	except Exception, msg:
		print msg



#######################################################################################################################
#                       Change Control
########################################################################################################################
# V3.5 - + Proxy Support
#
########
# V3.6  - So, Because 3.5 took too long, threading was implimented.  This, combined
#                          with the proxy should make this work and be safely publicly releasable
#
########
# v4.0 - Made Major changes to the threading process. Fixed issue with Proxies not updating on failed attempts
#                 and pastes being lost.  Script also will force quit after 6 minutes.
#
######
# v4.1 - Threading Problems.  Adding section to the threads
#                 that kill after 6 iterations...Trying to stop the system exploding.
#
######
# v4.2 - Cleaned code.  Fixed Proxys to remove \r & \n.  Implimented the getPasteHandler.  
#                       Removed Old Threading.  Implimented new version
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
#                       Adding @known_good_proxies saver 
#
#####
# v4.7  - Fixed (attempted to) ordering of paste pulling.
#
#####
# v5.0 - Migrated to Python.  Rewritten from scratch to use Pro API Feed
#
#####
# v5.1 - Added no-db option.  Changed License
#        Fixed ASCII art
#####
# 25 April 2018
# v5.2 - Updated for the new API endpoints 
#              - per https://pastebin.com/doc_scraping_api
#       - Fixed MongoDB stuff
##########################################
