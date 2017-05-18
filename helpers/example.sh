#!/bin/sh
# This is an example of how I generated the machines.json that is currently
# deployed at oss.stanford.edu/job-maker, for three different slurm clusters
# at stanford, one of which has partitions that need to be removed.

# cd job-maker/helpers
# ls slurm*.conf
# slurm.conf  slurm-corn.conf  slurm-xstream.conf

# First generate a machines.json with no limits for slurm.conf and slurm-corn.conf
python slurm2json.py --input slurm.conf,slurm-corn.conf

# Parsing slurm.conf,slurm-corn.conf, please wait!
# All partitions will be included.
# Adding cluster sherlock
# Adding cluster farmshare2
# Compiling clusters sherlock,farmshare2

# Now add xstream to the machines.json, but remove pascal
python slurm2json.py --input slurm-xstream.conf --update --disclude-part pascal

# Parsing slurm-xstream.conf, please wait!
# Found machines.json to update.
# pascal will not be included.
# Adding cluster xstream
# Compiling clusters xstream,sherlock,farmshare2
