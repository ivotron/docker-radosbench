#!/bin/bash
set -e

if [ "$#" -eq 1 ] && [ "$1" = "plot" ]; then
  # generates multiple graphs out of radosbench output
  #
  # expects to have results stored in the following folder structure:
  #
  #   * results/osd_count/num_replica/obj_size/repetition_type.csv
  #
  # where

  if [ ! -n "$RESULTS_PATH" ]; then
    echo "ERROR: RESULTS_PATH must be defined"
    exit 1
  fi

  if [ ! -n "$MAX_OSD" ]; then
    echo "ERROR: MAX_OSD must be defined"
    exit 1
  fi

  if [ ! -n "$EXPERIMENT" ]; then
    echo "ERROR: EXPERIMENT must be defined"
    exit 1
  fi

  throughput=${RESULTS_PATH}/${EXPERIMENT}_per-osd-write-throughput.csv
  latency=${RESULTS_PATH}/${EXPERIMENT}_per-osd-write-latency.csv
  rw=${RESULTS_PATH}/${EXPERIMENT}_per-osd-rw-throughput.csv
  scale=${RESULTS_PATH}/${EXPERIMENT}_per-osd-scalable-throughput.csv
  expath=$RESULTS_PATH/$EXPERIMENT

  # headers
  echo "replicas, size, throughput" > $throughput
  echo "replicas, size, latency" > $latency
  echo "replicas, size, read_throughput, write_throughput" > $rw
  echo "num_osd, replicas, size, throughput" > $scale

  for replicas in `ls $expath/$MAX_OSD/` ; do
    for size in `ls $expath/$MAX_OSD/$replicas/` ; do
      tp=`grep 'Bandwidth (MB/sec):' $expath/$MAX_OSD/$replicas/$size/1_write.csv | sed 's/Bandwidth (MB\/sec): *//'`
      lt=`grep 'Average Latency:' $expath/$MAX_OSD/$replicas/$size/1_write.csv | sed 's/Average Latency: *//'`
      r=`grep 'Bandwidth (MB/sec):' $expath/$MAX_OSD/$replicas/$size/1_seq.csv | sed 's/Bandwidth (MB\/sec) *//'`
      echo "$replicas, $size, $tp" >> $throughput
      echo "$replicas, $size, $lt" >> $latency
      echo "$replicas, $size, $r, $tp" >> $rw
    done
  done

  for osd in `ls $expath` ; do
    for replicas in `ls $expath/$osd/` ; do
      for size in `ls $expath/$osd/$replicas/` ; do
        tp=`grep 'Bandwidth (MB/sec):' $expath/$osd/$replicas/$size/1_write.csv | sed 's/Bandwidth (MB\/sec): *//'`
        echo "$osd, $replicas, $size, $tp" >> $scale
      done
    done
  done
  exit 0
fi

# Executes rados bench

if [ "$#" -ne 0 ] ; then
  echo "ERROR: unexpected arguments"
fi

if [ ! -n "$N" ]; then
  echo "ERROR: N must be defined as the number of replicas"
  exit 1
fi

if [ ! -n "$SEC" ]; then
  echo "ERROR: SEC must be defined as the number of seconds to execute for"
  exit 1
fi

if [ ! -n "$REPS" ]; then
  echo "ERROR: REPS must be defined as the number of times to execute for"
  exit 1
fi

if [ ! -n "$NUM_OSD" ]; then
  echo "ERROR: NUM_OSD must be defined as the number of OSDs in the cluster"
  exit 1
fi

if [ ! -n "$SIZE" ]; then
  SIZE="4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304"
fi

if [ ! -d "/data" ]; then
  echo "ERROR: folder '/data' doesn't exist"
  exit 1
fi

YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
TIME=`date +%H%M`

ceph_health()
{
  echo -n "Waiting for pool operation to finish..."
  while [ "$(/usr/bin/ceph health)" != "HEALTH_OK" ] ; do
    sleep 2
    echo -n "."
  done
  echo ""
}

# set PGS to the recommended values
if [ "$NUM_OSD" -le 2 ] ; then
  PGS=32
elif [ "$NUM_OSD" -le 3 ] ; then
  PGS=64
elif [ "$NUM_OSD" -le 5 ] ; then
  PGS=128
elif [ "$NUM_OSD" -le 10 ] ; then
  PGS=512
else
  PGS=4096
fi

BASE_PATH="/data/${YEAR}_${MONTH}_${DAY}_${TIME}/${NUM_OSD}"
for ((n=1; n<=N; n++)); do

  # check if we have enough OSDs for replication
  if [ "$NUM_OSD" -lt "$n" ] ; then
    continue
  fi

for size in $SIZE ; do
for ((rep=1; rep<=REPS; rep++)); do
  RESULTS_PATH="${BASE_PATH}/${n}/${size}/"
  mkdir -p ${RESULTS_PATH}
  POOL=perf
  echo "===> CREATE POOL: ${POOL} (`date +%H:%M:%S`)"
  /usr/bin/ceph osd pool create ${POOL} ${PGS} ${PGS}
  /usr/bin/ceph osd pool set ${POOL} size ${n}
  ceph_health
  echo "===> RADOS BENCH WRITE TEST: START (`date +%H:%M:%S`)"
  /usr/bin/rados bench ${SEC} write -b ${size} -p ${POOL} --no-cleanup > ${RESULTS_PATH}/${rep}_write.csv
  echo "===> RADOS BENCH WRITE TEST: END (`date +%H:%M:%S`)"
  echo "===> RADOS BENCH SEQ TEST: START (`date +%H:%M:%S`)"
  /usr/bin/rados bench ${SEC} seq -b ${size} -p ${POOL} > ${RESULTS_PATH}/${rep}_seq.csv
  echo "===> RADOS BENCH SEQ TEST: END (`date +%H:%M:%S`)"
  /usr/bin/ceph osd pool delete ${POOL} ${POOL} --yes-i-really-really-mean-it
  echo "===> DELETE POOL: ${POOL} (`date +%H:%M:%S`)"
done
done
done
