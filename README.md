# Job Maker

Making SLURM (or other) job scripts to submit jobs to a [SLURM cluster](https://en.wikipedia.org/wiki/Slurm_Workload_Manager) is annoying. Research Computing at Stanford, [inspired by NERSC](https://my.nersc.gov/script_generator.php), have created this static tool that you (some cluster admin) can tweak the configuration for, and then serve statically for your users.

## Configuration

The configuration and specification for your cluster is defined by files in the [assets/data](assets/data) folder. We generated these files from the `slurm.conf` directly, which is usually located at `/etc/slurm/slurm.conf`. You have a few options for generating these data files:

### Option 2. Manual
If you don't want to generate the file programatically, you can manually enter values for your cluster. A template / example file for you to start from is provided in [helpers/template](helpers/template).

### Option 1. Programmatic
In the helpers folder, we have provided a command line executable, [slurm2json.py](helpers/slurm2json.py) that can be run with the `slurm.conf` to generate the required data files. You have a few ways to run this, depending on the number of clusters and level of filtering you want to apply to each. First, take a look at the usage:


```
python slurm2json.py --help
usage: slurm2json.py [-h] [--config CONFIG] [--print] [--force]
                     [--outfile OUTFILE]

convert slurm.conf to machines.json

optional arguments:
  -h, --help         show this help message and exit
  --config CONFIG    path to slurm config file. Default is slurm.conf in
                     present working directory.
  --print            print to screen instead of saving to machines.json
  --force            Force overwrite of the output file, if it exists.
  --outfile OUTFILE  output json file. Default is machines.json
```

#### Generation

###### Generate for One Cluster
The simplest thing to do would be to cd to the folder with your `slurm.conf`, and generate the file:

```
git clone https://www.github.com/researchapps/job-maker
cd job-maker/helpers
cp /etc/slurm/slurm.conf $PWD
python slurm2json.py
```

If you want to change the name of the output file, specify it:

```
python slurm2json.py --outfile cluster.json
```

Or if you want to change the name of the input file, that works too:

```
python slurm2json.py --input slurm-corn.conf
```

If you make a mistake and need to overwrite (for example, to have the script run automatically and force update the file) just use force:

```
python slurm2json.py --force --outfile cluster.json
```

###### Generate for One Cluster with Filters
It might be the case that you want to disclude particular partitions. To do this, simply specify their names:


```
# One
python slurm2json.py --disclude-partition normal

# Multiple
python slurm2json.py --disclude-partition normal,dev
```


###### Generate for Multiple Clusters
Most institutions have multiple clusters, and would want their users to be able to select a cluster, and then filter down. To specify the `machines.json` to be generated for multiple clusters, you should specify the `--input` command, but provide several comma separated slurm configuation files:

```
python slurm2json.py --input slurm.conf,slurm-corn.conf
```

###### Generate for Multiple Clusters with Filters
If you have a filter to apply across all clusters, then you can generate as above, and add the filter:

```
python slurm2json.py --input slurm.conf,slurm-corn.conf --disclude-partition normal,dev
```

and in the example above, `normal` and `dev` would be discluded from both clusters defined in the two configuration files, given that they exist. However, if you have two clusters with a shared name but you only want to disclude a partition from one, then you should generate the `machines.json` for one cluster, and update it by adding the second. To do this you would use the `update` command described below, which also functions to add a cluster with different filters.


#### Add a Cluster
To add a new cluster to an already existing `machines.json` (possibly with different filters than the other clusters already in the file) you would use the `--update` flag. For example, you would first generate your initial file (as we did above) and then use `--update` to add a cluster to it:

```
python slurm2json.py --input slurm.conf                                  # include normal and dev
python slurm2json.py --update slurm-corn.conf --disclude-part normal,dev # do not include
```

In laymans terms, the example above will first write a `machines.json` with information about the cluster defined in `slurm.conf`. The second will also target the same `machines.json`, but add the cluster defined in `slurm-corn.conf`, not including paritions normal and dev. 


#### Update a Cluster
In addition to using this `update` command to add a new cluster to an already existing `machines.json`, if you use it again with an already existing file for which the cluster is defined, it will overwrite that particular cluster. Let's say we generated a configuration file for our cluster:

```
python slurm2json.py --input slurm-corn.conf,slurm.conf
```

and then we wanted to update just `slurm-corn.conf`

```
python slurm2json.py --update slurm-corn.conf
```

This would do the trick! `--update` assumes you want to overwrite an existing file, so `--force` is implied.

And if you need further functionality, please [create an issue](https://www.github.com/researchapps/job-maker/issues)


## Credits

 - [Research Computing](https://srcc.stanford.edu)
 - [UiKit](https://github.com/uikit/uikit)
 - [Nersc](https://my.nersc.gov/script_generator.php)
