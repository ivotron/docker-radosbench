# radosbench

A convenience container to execute rados bench.

Make sure to pass your /etc/ceph and /data paths as a 
volume/bind-mount.

Example:

```bash
docker run \
  -e SECS=300 -e N=3 -e PGS=512  -e OUTFILE=/data/results.txt \
  -v $HOME/rados_results/:/data \
  -v /etc/ceph:/etc/ceph \
  ivotron/radosbench
```
