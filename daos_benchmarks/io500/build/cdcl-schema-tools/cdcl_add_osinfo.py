#!/usr/bin/env python3

# Identify OS-specific information and add them into the result JSON file

import sys
import platform
import os
import re
import traceback
import subprocess
from cdcl_info_editor import edit_infos, execute_download, warn

if len(sys.argv) < 2:
  print("Synopsis: %s <SYSTEM-JSON> [<SupercomputerTypeNumber>] [<NodeTypeNumber>]" % sys.argv[0])
  sys.exit(1)

json = sys.argv[1]
supercomputerNumber = sys.argv[2] if len(sys.argv) > 2 else "0"
nodeNumber = sys.argv[3] if len(sys.argv) > 3 else "0"
cmd = []
cmd_noReplace = []

def info_(cmd, key, val, unit = ""):
  global nodeNumber, supercomputerNumber
  val = str(val).strip()
  unit = unit.strip()
  if val == None or val == "":
    return
  cmd.append(("Site.Supercomputer[%s].Nodes[%s]." % (supercomputerNumber, nodeNumber) + key + "=" + val + " " + unit).strip())

def info(key, val, unit = ""):
  global cmd
  if val == None:
    warn("Couldn't find any information for key %s" % key)
    return
  m = re.match("([0-9]+)K", val)
  if m:
    val = int(m.group(1))
    unit = "KiB"  
  info_(cmd, key, val, unit)

def infoNoReplace(key, val, unit = ""):
  global cmd_noReplace
  info_(cmd_noReplace, key, val, unit)

infoNoReplace("name", platform.node())
info("kernel version", platform.release())
info("Processor.architecture", platform.processor())

# CPU Information
data = open("/proc/cpuinfo", "r").read()
model_set = False
cores = 0
for line in data.split("\n"):
  if "model name" in line and not model_set:
    m = re.match("model name.*: ([^@]*)(@ ([0-9.]*)GHz)?", line)
    if m:
      cpu = m.group(1).strip()
      if cpu.find("CPU") > -1:
        cpu = cpu.replace("CPU", "")
      cpu = re.sub("\([^)]*\)", "", cpu)
      info("Processor.model", cpu)
      info("Processor.frequency", m.group(3), "GHz")
      model_set = True
  if line.startswith("processor"):
    cores = cores + 1

def re_add(regex, key, data, group = 1):
  m = re.search(regex, data)
  if m:
    info(key, m.group(group))

try:
  data = subprocess.check_output("LANG=C lscpu", shell=True, universal_newlines=True).strip()
  m = re.search("Core\(s\) per socket: *([0-9]+)", data)
  if m:
    cores = m.group(1)
  re_add("Thread\(s\) per core: *([0-9]+)", "Processor.threads per core", data)

  re_add("Vendor ID: *(.*)", "Processor.vendor", data)
  re_add("L2 cache: *([0-9]+.*)", "Processor.L2 cache size", data)
  re_add("L3 cache: *([0-9]+.*)", "Processor.L3 cache size", data)

except:
  traceback.print_exc()
  print("Cannot execute lscpu, will continue")

info("Processor.cores per socket", cores)

# OS Information
kv = {}
with open("/etc/os-release") as f:
  for line in f:
    arr = line.split("=")
    if len(arr) == 2:
      kv[arr[0].strip()] = arr[1].strip(" \n\t\"")

if "ID" in kv:
  val = kv["ID"]
  if val == "ubuntu":
    val = "Ubuntu"
  info("distribution", val)
if "VERSION_ID" in kv:
  info("distribution version", kv["VERSION_ID"])

# Try to find country code using a reverse address
if not os.path.exists("ip.html"):
  execute_download("https://pbxbook.com/other/where_ip.html", "ip.html")
  with open("ip.html") as f:
    m = re.search("public IP:.*Country:</b> .* / (.*) /", f.read())
    if m:
      info("nationality", m.group(1))

# Try to add memory
with open("/proc/meminfo") as f:
  for line in f:
    arr = line.split(":")
    if len(arr) == 2:
      kv[arr[0].strip()] = arr[1].strip(" \n\t\"")
  if "MemTotal" in kv:
    info("Memory.net capacity", kv["MemTotal"].replace("kB", "KiB"))

edit_infos(json, cmd)
edit_infos(json, cmd_noReplace, False)
