#!/bin/bash
./cdcl_info_print.py $1 /home/julian/ur-git/io500/submissions/isc21/*/site.json | cut -d "/" -f 8- | sed "s#/site.json =##" | cut -d " " -f 2-
