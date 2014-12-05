#!/bin/bash
set -e

# Executes rados bench

if [ "$#" -ne 0 ] ; then
  echo "ERROR: unexpected arguments"
  exit 1
fi

if [ ! -n "$SIZE" ]; then
  echo "ERROR: OBJ_SIZE must be defined as the object size"
  exit 1
fi

if [ ! -n "$SECS" ]; then
  echo "ERROR: SEC must be defined as the number of seconds to execute for"
  exit 1
fi

if [ ! -n "$TYPE" ]; then
  echo "ERROR: TYPE must be one of write|seq|rand"
  exit 1
fi

if [ ! -n "$POOL" ]; then
  echo "ERROR: POOL must be defined"
  exit 1
fi

if [ ! -d "$OUTFILE" ]; then
  echo "ERROR: OUTFILE should point to output file"
  exit 1
fi

exec /usr/bin/rados bench ${SEC} ${TYPE} -b ${SIZE} -p ${POOL} --no-cleanup > $OUTFILE
