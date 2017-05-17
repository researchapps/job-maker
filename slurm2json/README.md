# slurm2json: Slurm config, QOS, and account converter.

`slurm2json` is used to convert SLURM configuration into a JSON file that 
job-maker can read.

SLURM configuration is a living thing.  During the life of a cluster, several 
things regularly take place:

* New nodes are added, sometime with new features.

* Partitions are created, typically with the addition of new nodes.

* New users are created, and added to accounts & groups.

* Users are removed.

All of the above actions will cause changes to SLURM's "static" configuration, 
as well as to QOS settings, account membership, etc..

As SLURM configuration is not static, it's not possible to create a job-maker 
JSON file once, and then leave it alone forever.  It needs to be a living 
thing.  For that reason, there needs to be an automated way to read the 
information from a cluster, and output the necessary JSON.

`slurm2json` exists to read the information from a cluster, and output an 
intermediary JSON file, which can then be merged with other JSON files to 
create the `machines.json` file which job-maker requires.

# Requirements

This code uses three modules from CPAN:

* `JSON`

* `List::Util`, version 1.45 or later.

* `Text::CSV`

Although `List::Util` is a core module, your stock Perl might not have a 
new-enough version, so you'll want to pull the latest from CPAN.

You also need to be running this on a system that has the SLURM client 
installed, and which has been configured to communicate with your cluster.  
`sacctmgr` is used to gather a number of things from SLURM.

Also, you should (if possible) run this as root.  The reason is, `sacctmgr` 
will not provide account information to anyone other than root.  If you don't 
run this as root, then some of the user access information will be missing: 
Specifically, partition access that is granted via `AllowAccounts` won't be 
processed.

# How To Run

Running slurm2json can be as simple as running…

    perl -wT slurm2json.pl < /etc/slurm/slurm.conf > cluster.json

… or even …

    ./slurm2json.pl < /etc/slurm/slurm.conf > cluster.json
    
*However*, if you are using something like `local::lib`—where Perl modules are 
outside of system module paths—then you'll need to explicitly specify those 
paths on the command line, using the `-I` option.  For example…

    perl -wT -I/home/akkornel/perl5/lib/perl5 -I/home/akkornel/perl5/lib/perl5/5.24.0/x86_64-linux-thread-multi -I/home/akkornel/perl5/lib/perl5/x86_64-linux-thread-multi slurm2json.pl < /etc/slurm/slurm.conf > cluster.json

This is needed because `slurm2json` runs in Taint mode for safety, and taint 
mode ignores non-system paths unless they are explicitly specified on the 
command-line.

## Non-Standard SLURM paths

`slurm2json` calls `sacctmgr` to get information from SLURM.  It assumes that 
`sacctmgr` can be found at path `/usr/bin/sacctmgr`.  If that is not true, you 
will need to change the definition of `$SACCTMGR_PATH`, which is defined near 
the top of the file.

Note that because this code uses Taint mode, the `PATH` environment variable is 
not trusted.  So, the full path must be specified.

# Making machines.json

`slurm2json` outputs an intermediary JSON file, where the root object is a dict 
containing a single key: The name of the cluster.  The value is another dict, 
which contains the cluster-specific entries that we're used to.

job-maker's `machines.json` also requires that the root object be a dict, but 
it expects the root dict to have a key named `clusters`.  That key's value is a 
dict, which contains one key for each cluster.  So, the intermediate output of 
`slurm2json` needs to be "pushed down a level", and combined with all of the 
other intermediate JSONs, to make a single `machines.json` file.

The easiest way to manipulate the JSON is to use `jq`.

If you only have one cluster, you can use this command:

    jq '{ clusters : . }' slurm2json_output.json > machines.json

That command essentially says, "Output a dict, with one entry, who's key is 
'clusters', and whose value is whatever input is coming in.".

If you have multiple clusters, you'll need to run `slurm2json` on each cluster 
(to generate the intermediate JSON files, and then combine the outputs, like so:

    jq -s 'add | { clusters : . }' slurm2json_output1.json slurm2json_output2.json ... > machines.json

This command is more complicated.  The `-s` option "slurps" in all of the 
input, making `.` an array of dicts.  The `add` filter takes that array of 
dicts, and merges them into a single dict.  This is OK, because the top-level 
keys are cluster names, and clusters *should* be using different names.  The 
new dict is then processed normally, as if we were working with a single 
intermediate JSON file.

# To-Do

There are a number of things which aren't done yet.

* **DenyAccounts**: The `DenyAccounts` partition option isn't being processed 
  right now.

* **Groups Resolution**: SLURM is able to restrict partition access to members 
  of a particular UNIX group.

  The code already builds a list of UNIX groups that have special access.  The 
  global hash `$access_by_group` uses UNIX group names as keys, and the value 
  is an arrayref of partitions (partitions which the UNIX group can access).

  The work to be done is: Get the list of SLURM users, get each user's group 
  membership, and grant them access to the partition.  This is done by updating
  `$cluster{'users'}`: This resolves to a hashref, where the keys are 
  usernames, and the value is an arrayref of partitions.

  This either requires root access to run `sacctmgr list users`, or you have to 
  do alot of manual trawling through the results of `getent passwd` and `getent 
  group`.

* **Accounts Resolution**: SLURM is able to restrict partition access to 
  members of a particular "account".  In this usage, "account" is basically 
  another grouping of people, except this grouping is internal to SLURM.

  The code already builds a list of SLURM accounts that have special access.  
  The global hash `%access_by_account` has SLURM account names as keys, and the 
  value is an arrayref of partition names.

  The work to be done is, use `sacctmgr` to work out who is in which account, 
  and then update `$cluster{'users'}` appropriately.  This requires root 
  access, or else `sacctmgr` won't provide the necessary data.
