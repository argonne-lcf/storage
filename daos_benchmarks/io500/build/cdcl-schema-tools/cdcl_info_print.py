#!/usr/bin/env python
import sys
import json
import re
import os
import subprocess
import cdcl_info_editor

# This tool allows to view tokens of an existing schema file


value = None # currently parsed value

if __name__ == "__main__":
  if len(sys.argv) < 3:
    print("Synopsis: %s <TOKEN> {<FILE>}" % sys.argv[0])
    print("Examples:")
    print("printing current: %s Site.institution site.json" % sys.argv[0])
    sys.exit(1)
  for file in sys.argv[2:]:
    cdcl_info_editor.edit_infos(file, [sys.argv[1]], replace=False, printFile=True)
