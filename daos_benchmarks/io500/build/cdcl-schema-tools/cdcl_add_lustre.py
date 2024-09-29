#!/usr/bin/env python3

# Identify information from Lustre and add them to the schema
# At the moment, use it to store the data into a file for later usage

import sys
import platform
import os
import re
import traceback
import subprocess
from optparse import OptionParser

from cdcl_info_editor import edit_infos, execute_download, invoke_prog

def parseOBDS(data, state):
  options.lustreFS = state["oss_fs"]
  max_ds = 0  
  for line in data:
    if line == "\n":
      info("OSS.count", max_ds)
      return
    if line == "OBDS:\n":
      info("OSS.count", max_ds)
      max_ds = 0
      state["oss_fs"] = state["oss_fs"] + 1      
      options.lustreFS = state["oss_fs"]
      continue
    m = re.match("([0-9]+): (.*) ", line)
    if m:
      max_ds = int(m.group(1))
    else:
      print("Parsing error OBDS: " + line)

def parseMDTS(data, state):
  options.lustreFS = state["mds_fs"]
  max_ds = 0
  for line in data:
    if line == "\n":
      info("MDS.count", max_ds)
      state["mds_fs"] = state["mds_fs"] + 1
      return
    if line == "MDTS:\n":    
      info("MDS.count", max_ds)
      max_ds = 0
      state["mds_fs"] = state["mds_fs"] + 1
      options.lustreFS = state["mds_fs"]
      continue
    m = re.match("([0-9]+): (.*) ", line)
    if m:
      max_ds = m.group(1)
    else:
      print("Parsing error MDTS: " + line)

def parse(data):
  # TODO
  state = { "mds_fs" : 0, "oss_fs" : 0}
  for line in data:
    if line == "OBDS:\n":
      parseOBDS(data, state)
    if line == "MDTS:\n":
      parseMDTS(data, state)
    
def infoL(key, val, unit = ""):
  global cmd, options
  val = str(val).strip()
  unit = unit.strip()
  if val == None or val == "":
    return
  cmd.append(("Site.StorageSystem[%s].Lustre." % (options.lustreFS) + key + "=" + val + " " + unit).strip())

def info(key, val, unit = ""):
  infoL(key, val)

parser = OptionParser()
parser.add_option("-j", "--json", dest="json",
                  default="site.json",
                  help="Update this JSON file with the new data", metavar="FILE")
parser.add_option("-f", "--file", dest="filename",
                  help="read data from FILE", metavar="FILE")
#parser.add_option("-l", "--lustreFS",
#                  dest="lustreFS", default="0",
#                  help="The Lustre FS in the schema to fill", metavar="NUMBER")

(options, args) = parser.parse_args()
options.loadFromFile = False

if options.filename != None:
  if os.path.isfile(options.filename):
    # load the data from the file!
    options.loadFromFile = True

if options.loadFromFile: 
  print("Loading from file %s" % options.filename)
  data = open(options.filename, "r")
else:
  # try to fetch the data and store it
  params = [
  "ldlm.namespaces.*.{lru_size,lru_max_age}",
  "llite.*.{max_cached_mb,max_read_ahead_mb,max_read_ahead_per_file_mb}",
  "{mdc,osc}.*.{max_rpcs_in_flight,checksums,max_dirty_mb,max_pages_per_rpc}",
  "llite.*.{lmv,lov}.activeobd",         # number of MDTs/OSTs in filesystem
  "llite.*.{files,kbytes}{free,total}",  # all free and total files and inodes
  "mdc.*.{files,kbytes}{free,total}",    # per-MDT free and total files/inodes
  "osc.*.{files,kbytes}{free,total}",    # per-OST free and total files/inodes
  "{mdc,osc}.*.import"]                  # lots of info about server config
  
  data = invoke_prog("LCTL", "lctl get_param debug %s |  sed -e 's/fff[0-9a-f]*/*/'" % " ".join(params))
  data = data + "\n" + invoke_prog("LFS MDTS", "lfs mdts")
  data = data + "\n" + invoke_prog("LFS OSTS", "lfs osts")
  data = data + "\n" + invoke_prog("LFS DF", "lfs df -v")

  if options.filename:
    data = data.strip()
    if len(data) == 0:
      print("Ignoring empty output, nothing to save")
      sys.exit(1)
    print("Saving to file %s" % options.filename)
    file = open(options.filename, 'w')
    file.write(data + "\n")
    file.close()
  data = data.split("\n")

cmd = []
parse(data)
edit_infos(options.json, cmd)
