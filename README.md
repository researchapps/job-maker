# Job Maker

Making SLURM (or other) job scripts to submit jobs to a [SLURM cluster](https://en.wikipedia.org/wiki/Slurm_Workload_Manager) is annoying. Research Computing at Stanford, [inspired by NERSC](https://my.nersc.gov/script_generator.php), have created this static tool that you (some cluster admin) can tweak the configuration for, and then serve statically for your users.

## Configuration

The configuration and specification for your cluster is defined by files in the [assets/data](assets/data) folder. We generated these files from the `slurm.conf` directly, which is usually located at `/etc/slurm/slurm.conf`. You have a few options for generating these data files:

### Option 2. Manual
If you don't want to generate the file programatically, you can manually enter values for your cluster. A template / example file for you to start from is provided in [helpers/template](helpers/template).

### Option 1. Programmatic
In the helpers folder, we have provided a command line executable, [slurm2json.py](helpers/slurm2json.py) that can be run with the `slurm.conf` to generate the required data files.

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

If you make a mistake and need to overwrite (for example, to have the script run automatically and force update the file) just use force:

```
python slurm2json.py --force --outfile cluster.json
```

And if you need further functionality, please [create an issue](https://www.github.com/researchapps/job-maker/issues)

## Credits

 - [Research Computing](https://srcc.stanford.edu)
 - [UiKit](https://github.com/uikit/uikit)
 - [Nersc](https://my.nersc.gov/script_generator.php)
