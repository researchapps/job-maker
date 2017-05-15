#!/usr/bin/perl -wT
# vim: ts=4 sw=4 et
#
# slurm2json: Slurm config, QOS, and account converter.
#
# Written By:
# - A. Karl Kornel <akkornel@stanford.edu>
#
# Last Updated: 2017-05-15
#
# Copyright © 2017 the Board of Trustees of the Leland Stanford Junior University.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use strict;
use warnings;

use IPC::Open2;
use JSON;
use List::Util 1.45; # 1.45+ needed for uniq()
use Text::CSV;

my $DEBUG = 0;
my $SACCTMGR_PATH = '/usr/bin/sacctmgr';

# Wipe out our environment, for taint-safety.
%ENV = ();

# This is our cluster information.
my $cluster_name;
my @features;
my %gres;
my %partitions;
my %qos;
my (@access_all, %access_by_account, %access_by_group);

# Begin processing slurm.conf on standard input
while (1) {
    my $line = <STDIN>;
    if (!defined($line)) {
        print STDERR "No more lines to parse\n" if $DEBUG;
        last;
    }
    chomp $line;

    # Filter out stuff to ignore
    if ((length($line) == 0)
        or ($line =~ m|^#|)
        or ($line =~ m|^\s+$|)) {
        print STDERR "Skipping line $line\n" if $DEBUG;
        next;
    }

    print STDERR "Looking at $line\n" if $DEBUG;

    # Catch multi-line lines (that is, those ending in \)
    # A few cases have whitespace and/or comments after the \, so we must catch that.
    while ($line =~ m|\\\s*$|) {
        my $extra_line = <STDIN>;
        # Remove whitespace from start/end of line, and comments from end of line.
        # But, keep the ending backslash.
        $extra_line =~ s|^\s+||;
        $extra_line =~ s|\s+(#.*)?$||;
        $line =~ s|\\\s*$|$extra_line|;
        print STDERR "Appended line $extra_line\n" if $DEBUG;
    }

    # Figure out what type of line we have.
    my $line_type;
    if ($line =~ m|^(\w+)=(.+)$|) {
        $line_type = lc($1);
    } else {
        print "Could not parse the line $line\n";
        exit 1;
    }
    print STDERR "This line is a $line_type\n" if $DEBUG;

    # We only care about some things
   
    # We want to capture the ClusterName
    if ($line_type eq 'clustername') {
        $line =~ m|^ClusterName=(.+)$|i;
        $cluster_name = $1;
    }

    # For NodeName, we want the feature list, which we add to the global list.
    # (We'll handle deduplication later)
    # We also want to get Gres stuff
    elsif ($line_type eq 'nodename') {
        # Pull out the Feature list
        if ($line =~ m|Feature="(.+)"|i) {
            push @features, (split /,/, $1);
            print STDERR "Found features!\n" if $DEBUG;
        } else {
            print STDERR "No features found\n" if $DEBUG;
        }

        # Pull out the Gres list
        if ($line =~ m|Gres=([a-z0-9:,]+)|i) {
            my $gres_string = $1;
            print STDERR "Found Gres line $gres_string\n" if $DEBUG;
            foreach my $gres_entry (split(/,/, $gres_string)) {
                # Parse out the name, and optional type.
                my @gres_params = split(/:/, $gres_entry);
                my $gres_name = shift @gres_params;
                print STDERR "Gres name is $gres_name\n" if $DEBUG;

                # Make sure the top-level name exists, then add the option
                if (!exists($gres{$gres_name})) {
                    $gres{$gres_name} = [];
                }

                # If a Gres type is defined, add it to the list.
                # Again, we don't de-duplicate right now.
                if (scalar(@gres_params) > 0) {
                    push @{$gres{$gres_name}}, shift @gres_params;
                    print STDERR "Gres type is $gres_params[0]\n" if $DEBUG;
                }
            }
        } else {
            print STDERR "No Gres found\n" if $DEBUG;
        }
    }

    # For PartitionName, we want alot of stuff!
    elsif ($line_type eq 'partitionname') {
        my ($name, $options);
        my $hidden;
        my (%default, %max, %min, @qos);
        my (@allowed_accounts, @allowed_groups);

        # Get the partition name and the rest of the line
        if ($line =~ m|^PartitionName=(\w+)\s+(.+)$|i) {
            ($name, $options) = ($1, $2);
            print STDERR "Name is $name\nOptions are $options\n" if $DEBUG;
        } else {
            print "Could not extract name from $line\n";
            exit 1;
        }

        # Now, let's go through the rest of the options
        foreach my $option (split(/\s+/, $options)) {
            my ($option_name, $option_value) = split(/=/, $option);
            $option_name = lc($option_name);

            # We're going to look for options in this order:
            # Hidden, AllowQOS, Defaults (plus QOS), Max, Min, and Allow/Deny.
           
            # Catch Hidden
            if ($option_name eq 'hidden') {
                print STDERR "Found Hidden\n";
                if ($option_value eq 'YES') {
                    $hidden = JSON::true;
                }
                elsif ($option_value eq 'NO') {
                    $hidden = JSON::false;
                }
                else {
                    print "Invalid Hidden value \"$hidden\" for partition $name\n";
                    exit 1;
                }
            }

            # Build AllowQOS list
            elsif ($option_name eq 'allowqos') {
                @qos = split(/,/, $option_value);
            }

            # Defaults
            elsif ($option_name eq 'defmempercpu') {
                $default{'mem-per-cpu'} = $option_value;
            }
            elsif ($option_name eq 'defmempernode') {
                $default{'mem-per-node'} = $option_value;
            }
            elsif ($option_name eq 'defaulttime') {
                $default{'time'} = $option_value;
            }
            elsif ($option_name eq 'qos') {
                $default{'qos'} = $option_value;
            }

            # Maxima
            elsif ($option_name eq 'maxcpuspernode') {
                $max{'cpu-per-node'} = $option_value;
            }
            elsif ($option_name eq 'maxmempercpu') {
                $max{'mem-per-cpu'} = $option_value;
            }
            elsif ($option_name eq 'maxmempernode') {
                $max{'mem-per-node'} = $option_value;
            }
            elsif ($option_name eq 'maxtime') {
                $max{'time'} = $option_value;
            }
            elsif ($option_name eq 'maxnodes') {
                $max{'nodes'} = $option_value;
            }

            # Minima
            elsif ($option_name eq 'minnodes') {
                $min{'nodes'} = $option_value;
            }

            # Allowed entities
            elsif ($option_name eq 'allowaccounts') {
                @allowed_accounts = split(/,/, $option_value);
            }
            elsif ($option_name eq 'allowgroups') {
                @allowed_groups = split(/,/, $option_value);
            }

            # Denied entities
            # TODO: Add support for DenyAccounts
        }

        # Skip the DEFAULT partition
        if ($name eq 'DEFAULT') {
            print STDERR "Skipping DEFAULT partition\n" if $DEBUG;
            next;
        }

        # Build our partition entry
        my %partition_entry;
        if (defined($hidden)) {
            $partition_entry{'hidden'} = $hidden;
        }
        if (scalar(@qos) != 0) {
            $partition_entry{'qos'} = \@qos;
        }
        if (scalar(keys(%default)) != 0) {
            $partition_entry{'default'} = \%default;
        }
        if (scalar(keys(%max)) != 0) {
            $partition_entry{'max'} = \%max;
        }
        if (scalar(keys(%min)) != 0) {
            $partition_entry{'min'} = \%min;
        }

        # Add our partition to the list!
        $partitions{$name} = \%partition_entry;

        # Now we need to work out who can access this partition!
        
        # If there's nobody in the allowed list, then everyone can access!
        if (!scalar(@allowed_accounts) and !scalar(@allowed_groups)) {
            push @access_all, $name;
        }

        # Otherwise, add this partition to the access lists for accounts & groups.
        if (scalar(@allowed_accounts) > 0) {
            foreach my $account (@allowed_accounts) {
                if (!exists($access_by_account{$account})) {
                    $access_by_account{$account} = [$name];
                } else {
                    push @{$access_by_account{$account}}, $name;
                }
            }
        }
        if (scalar(@allowed_groups) > 0) {
            foreach my $group (@allowed_groups) {
                if (!exists($access_by_group{$group})) {
                    $access_by_group{$group} = [$name];
                } else {
                    push @{$access_by_group{$group}}, $name;
                }
            }
        }

    } # Done with PartitionName
} # Done processing slurm.conf

# Start running external commands!
my ($sacctmgr_pid, $sacctmgr_stdin, $sacctmgr_stdout);

# Pull QoS information from SLURM.

# To help, create an anonymous function that parses a TRES string.
my $tres_parse = sub {
    my ($tres_text) = (@_);
    my %output;

    foreach my $tres_item (split(/,/, $tres_text)) {
        # Each item is name=value
        my @tres_components = split(/=/, $tres_item);

        # For most items, processing is simple!
        if ($tres_components[0] !~ m|^gres/|) {
            $output{$tres_components[0]} = $tres_components[1];
        }

        # For gres components, populate a separate structure.
        else {
            if (!exists($output{'gres'})) {
                $output{'gres'} = {};
            }

            # First, split out the gres string
            $tres_components[0] =~ m|^gres/(.+)$|;
            my $gres_item = $1;

            # For now, put that entire item in.
            $output{'gres'}->{$gres_item} = $tres_components[1];
            # TODO: Properly split out the gres string.
        }
    }

    # Return our hashref!
    return \%output;
};

# Run sacctmgr to get the list of QOSes, in machine-readable form, with only what we want.
eval {
    my @cmdline = ($SACCTMGR_PATH, qw(-p list qos),
        'Format=Name,MaxTRESPerJob,MaxTRESPerUser,MaxWall,MinTRES',
    );
    print STDERR 'Running command: ', join(' ', @cmdline), "\n" if $DEBUG;
    $sacctmgr_pid = open2($sacctmgr_stdout, $sacctmgr_stdin, @cmdline);
    close($sacctmgr_stdin);
    print STDERR "PID is $sacctmgr_pid\n" if $DEBUG;
};
if ($@) {
    print STDERR "sacctmgr error: $@\n" if $DEBUG;
    print "WARNING!  Unable to run sacctmgr to get QOS info.\n";
    print "JSON will be incomplete.\n";
} else {
    # We'll use Text::CSV to handle parsing of sacctmgr's output.
    my $csv = Text::CSV->new({
        'sep_char'       => '|',
        'blank_is_undef' => 1,
        'empty_is_undef' => 1,
    });

    # Pull the first row for column names.
    $csv->column_names($csv->getline($sacctmgr_stdout));

    # Loop through each QoS line.
    while (my $qos_entry = $csv->getline_hr($sacctmgr_stdout)) {
        # Now we need to look at individual columns
        
        # First, get the name and create our entry.
        my $qos_name = $qos_entry->{'Name'};
        my (%qos_min, %qos_max);
        print STDERR "Examining QOS entry $qos_name\n" if $DEBUG;

        # MaxWall is easy to check for.
        if (defined($qos_entry->{'MaxWall'})) {
            $qos_max{'wall'} = $qos_entry->{'MaxWall'};
        }

        # Parse our minimums.
        if (defined($qos_entry->{'MinTRES'})) {
            %qos_min = %{$tres_parse->($qos_entry->{'MinTRES'})};
        }

        # Parse our per-user node maxima.
        if (defined($qos_entry->{'MaxTRESPU'})) {
            %qos_max = %{$tres_parse->($qos_entry->{'MaxTRESPU'})};
        }

        # For per-host maxima, if there's a conflict.
        # We assume that user-level overrides host-level TRES.
        # TODO: Check if this logic is actually correct.
        if (defined($qos_entry->{'MaxTRES'})) {
            my %qos_max_host = %{$tres_parse->($qos_entry->{'MaxTRESPU'})};

            foreach my $conflicting_qos (keys(%qos_max_host)) {
                if (!exists($qos_max{$conflicting_qos})) {
                    $qos_max{$conflicting_qos} = $qos_max_host{$conflicting_qos};
                }
            }
        }

        # Assemble our QOS components into the global hash.
        $qos{$qos_name} = {};
        if (scalar(keys(%qos_min)) > 0) {
            $qos{$qos_name}->{'min'} = \%qos_min;
        }
        if (scalar(keys(%qos_max)) > 0) {
            $qos{$qos_name}->{'max'} = \%qos_max;
        }
    } # Done looping through sacctmgr's QOS output.
} # Done with sacctmgr post-eval code.

# Clean up sacctmgr's child process.
waitpid($sacctmgr_pid, 0);


# Start building our JSON.


# Catch if we didn't get a cluster name
if (!defined $cluster_name) {
    print "No ClusterName line found.  Did you provide a config?\n";
    exit 1;
}

# Make our cluster hash, starting with partitions.
my %cluster = (
    partitions => \%partitions,
);

# If we have a populated QOS hash, add them.
if (scalar(keys(%qos)) > 0) {
    $cluster{'qos'} = \%qos;
}

# If we have features, deduplicate and add them.
# NOTE: This doesn't sort the list!
if (scalar(@features) > 0) {
    $cluster{'features'} = [List::Util::uniq(@features)];
}

# If we have Gres, add them as well.
# If a key has any types, add them as well.  Else add an empty list.
# And again, NOTE, this doesn't sort!
if (scalar(keys(%gres)) > 0) {
    foreach my $gres_key (keys(%gres)) {
        my @gres_types = List::Util::uniq(@{$gres{$gres_key}});
        $gres{$gres_key} = \@gres_types;
    }
    $cluster{'gres'} = \%gres;
}

# If we have any users, then set up that hash key.
if ((scalar(@access_all) > 0) or
    (scalar(keys(%access_by_account)) > 0) or
    (scalar(keys(%access_by_group)))
) {
    $cluster{'users'} = {};
}

# Add the wildcard user
if (scalar(@access_all) > 0) {
    $cluster{'users'}->{'*'} = \@access_all;
}

# TODO: Handle %access_by_account and %access_by_group

# Output the JSON: We encode as UTF-8, and we pretty-print
print JSON->new->utf8(1)->pretty(1)->encode({ $cluster_name => \%cluster });

print STDERR "All done!\n" if $DEBUG;
exit 0;
