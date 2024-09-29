#!/usr/bin/env python
import sys
import json
import re
import os
import subprocess

# This tool allows to view and edit the options in an existing __schema__ file.
# In order to get started download the two files:
# wget https://www.vi4io.org/lib/plugins/newcdcl/scripts/__schema__-io500.json
# wget https://www.vi4io.org/lib/plugins/newcdcl/scripts/site-io500.json
#
# You can then copy the site-io500.json template file and modify it using this tool

def invoke_prog(name, prog):
  try:
    data = subprocess.check_output(prog, shell = True, encoding='UTF-8')
    if len(data) == 0:
      print("Program returned zero output %s" % prog)
      return ""
  except subprocess.CalledProcessError:
    print("Cannot inoke program %s" % prog)
    return ""
  return name + "\n" + data

def warn(str):
  print("WARNING: %s " % str)

def parse_full_val(val, schema_data):
  global __units__
  tmp = val
  if "unit" in schema_data and schema_data["unit"] != "":
    tmp = re.split("([0-9.]+) *", tmp)
    val_unit = ""
    if len(tmp) > 2:
      val_unit = tmp[2].strip()
    tmp = tmp[1]
    if schema_data["dtype"] == "number":
      number = float(tmp)
    elif schema_data["dtype"] == "integer":
      number = int(tmp)
    else:
      return None
    #if len(tmp) != 2:
    #  print("The value %s requires a unit of type: %s" % (val, schema_data["unit"]))
    #  return None
    exp_unit = __units__[schema_data["unit"]]
    for (unit, multiplier) in exp_unit:
      if val_unit == unit:
        return [ number, val_unit ]
    return None
  if isinstance(tmp, list):
    tmp = tmp[0]
  
  if schema_data["dtype"] == "number":
    return float(tmp)
  elif schema_data["dtype"] == "integer":
    return int(tmp)
  else:
    return val

def processDict(data, token, path, val, replace, usePrefix, resultdict):
  global value
  cur = token[0].strip()
  
  if len(token) == 1:
    was = ""
    old = ""
    cval = None
    if not "att" in data:
      data["att"] = {}
    if cur in data["att"]:
      cval = data["att"][cur]
      if isinstance(cval, list):
        cval = "%s %s" % (cval[0], cval[1])
      old = cval
      if val != None:
        was = "   # was: %s" % cval

    if val != None:
      nval = val
      if isinstance(val, list):
        nval = "%s %s" % (val[0], val[1])
      if cval == nval:
        was = "   # unchanged"
      elif not replace and cval:
        was = "   # won't replace with " + nval
      if replace or cur not in data["att"]:
        data["att"][cur] = nval
        cval = nval
    #if usePrefix:
    #  path = edit_infos + "-" + path
    if resultdict != None:
      if cur in data["att"]:
        resultdict[path] = cval
      else:
        resultdict[path] = None
    else:
      if cur in data["att"]:
        print("%s = %s%s" % (path, cval, was))
      else:
        print("%s = undefined" % path)
  else:
    processSingle(data["childs"], token, path, val, replace, usePrefix, resultdict)

def processSingle(data, token, path, val, replace, usePrefix, resultdict=None):
  cur = token.pop(0)
  index = 0
  m = re.search("(.*)\[([0-9]+)\]", cur)
  if m:
    cur = m.group(1)
    index = int(m.group(2))

  if isinstance(data, list):
    # need to find token
    for k in range(0, len(data)):
      if data[k]["type"] == cur:
        if index == 0:
          processDict(data[k], token, path, val, replace, usePrefix, resultdict)
          return
        else:
          index = index - 1
    for k in range(0, index + 1):
      data.append({"type" : cur, "att" : {}, "childs" : [] })
    processDict(data[len(data)-1], token, path, val, replace, usePrefix, resultdict)
    return
  if data["type"] == cur:
    processDict(data, token, path, val, replace, usePrefix, resultdict)

def validate_in_template(templateNames, cur, token, val, multi = False):
  global __templates__
  index = 0
  m = re.search("(.*)\[([0-9]+)\]", cur)
  if m:
    cur = m.group(1)
    index = int(m.group(2))

  for t in templateNames:
    name = t
    if t.find(":") > -1: # a renamed type
      name = t.split(":")[0]
      t = t.split(":")[1]
    if name == cur: # found it
      if index > 0 and not multi:
        print("The template %s does not support [X] notation" % cur)
        return None
      return validate_path_value(__templates__[t], token, val)
  return None

# Check if the __schema__ supports the provided path token Site.XXX.YYY.ZZZ
def validate_path_value(__schema__, token, val):
  global value
  cur = token.pop(0).strip()
  type = cur
  
  m = re.search("(.*)\[([0-9]+)\]", cur)
  if m:
    type = m.group(1)

  if type in __schema__:
    if len(token) == 0:
      # Validate the correctness of the value
      if val:
        __schema__ = __schema__[cur]
        value = parse_full_val(val, __schema__)
        return value != None
      return True;
    else:
      return validate_path_value(__schema__[type], token, val)

  if "SCHEMES" in __schema__:
    ret = validate_in_template(__schema__["SCHEMES"], cur, token, val)
    if ret != None:
      return ret
  if "SCHEMES_multi" in __schema__:
    ret = validate_in_template(__schema__["SCHEMES_multi"], cur, token, val, multi = True)
    if ret != None:
      return ret
  return False

def process(data, schema, tokens, replace = True, usePrefix = None, resultdict = None):
  global value
  for t in tokens:
    kv = t.split("=")
    token = kv[0].split(".")
    val = kv[1].strip() if len(kv) == 2 else None
    value = None
    if validate_path_value(schema, list(token), val):
      processSingle(data, token, kv[0].strip(), value, replace, usePrefix, resultdict=resultdict)
    else:
      print("Error: cannot validate path (or value): %s" % token)

def edit_infos(sitefile, tokens, replace=True, schemafile = "schema-io500.json", printFile=True):
  global __units__, __templates__, __schema__

  check_requirements(sitefile, schemafile)

  with open(schemafile, 'r') as f:
    __schema__ = json.load(f)
    __templates__ = __schema__["SCHEMES"]
    __units__ = __schema__["UNITS"]
  
  if printFile:
    usePrefix = sitefile
  else:
    usePrefix = None

  with open(sitefile, 'r+') as f:
      data = json.load(f)
      process(data["DATA"], __schema__["SYSTEM"], tokens, replace=replace, usePrefix=usePrefix)

      f.seek(0)
      json.dump(data, f, indent=2)
      f.truncate()

__loaded__ = False

"""This function returns a dictionary of all requested tokens"""
def cdclgather(sitefile, tokens, schemafile = "schema-io500.json"):
  global __units__, __templates__, __schema__, __loaded__
  if not __loaded__:
    __loaded__ = True
    # load data
    check_requirements(sitefile, schemafile)
    with open(schemafile, 'r') as f:
      __schema__ = json.load(f)
      __templates__ = __schema__["SCHEMES"]
      __units__ = __schema__["UNITS"]
  result = {}
  with open(sitefile, 'r+') as f:
      data = json.load(f)
      process(data["DATA"], __schema__["SYSTEM"], tokens, replace=False, resultdict=result)
  return result

def execute_download(url, outfile):
  import subprocess
  try:
    subprocess.check_output("wget " + url + " -O " + outfile, shell=True)
  except:
    try:
      subprocess.check_output("curl " + url + " -o " + outfile, shell=True)
    except:
      print("Neither wget or curl are working to download! Will abort now.")
      sys.exit(1)


def check_requirements(site, __schema__ = "__schema__-io500.json"):
  if not os.path.exists(site):
    print("Downloading new site specification")
    execute_download("https://www.vi4io.org/lib/plugins/newcdcl/scripts/site-io500.json", site)
  if not os.path.exists(__schema__):
    execute_download("https://www.vi4io.org/lib/plugins/newcdcl/scripts/schema-io500.json", __schema__)


value = None # currently parsed value

if __name__ == "__main__":
  if len(sys.argv) < 3:
    print("Synopsis: %s <FILE> {<TOKEN[=VALUE [UNIT]]>}" % sys.argv[0])
    print("Examples:")
    print("printing current: %s site.json Site.institution" % sys.argv[0])
    print("Token examples:")
    print("changing: Site.StorageSystem.Lustre.OSS.count=5")
    print("changing options: Site.StorageSystem.Lustre.features=DNE1;DNE2")
    print("changing a numeric value \"Site.IO500.IOR.easy write = 351.2 GiB/s\"")
    print("setting a value for a second Lustre (for multiple schemes): Site.StorageSystem.Lustre[1].OSS.count=5")
    sys.exit(1)
  edit_infos(sys.argv[1], sys.argv[2:])

  print("OK")
