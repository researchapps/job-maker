#!/usr/bin/env python

'''
slurm2json.py: convert a slurm.conf to a machines.json input file

The MIT License (MIT)

Copyright (c) 2017 Vanessa Sochat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

'''

import argparse
import json
import sys
import os
import re


def get_parser():
    parser = argparse.ArgumentParser(
    description="convert slurm.conf to machines.json")

    parser.add_argument("--input", dest='input', 
                        help='''path to one or more slurm config files, separated by commas. 
                                Default is one slurm.conf in present working directory.''', 
                        type=str, default='slurm.conf')

    parser.add_argument("--update", dest='update', 
                        help='''Update an already existing machines.json (or other)''', 
                        default=False, action='store_true')


    parser.add_argument("--disclude-part", dest='disclude_part', 
                        help='''Partitions to disclude, separated by commas''', 
                        type=str, default=None)


    parser.add_argument("--print", dest='print', 
                        help="print to screen instead of saving to machines.json", 
                        default=False, action='store_true')


    parser.add_argument("--quiet", dest='quiet', 
                        help='''Suppress all output (other than print)''', 
                        default=False, action='store_true')


    parser.add_argument("--force", dest='force', 
                        help="Force overwrite of the output file, if it exists.", 
                        default=False, action='store_true')

    # Two images, for similarity function
    parser.add_argument("--outfile", dest='outfile', 
                        help="output json file. Default is machines.json", 
                        type=str, default='machines.json')

    return parser




def main():

    parser = get_parser()

    try:
        args = parser.parse_args()
    except:
        sys.exit(0)

    if os.path.exists(args.outfile) and args.force is False and args.update is False and args.print is False:
        message("%s already exists! Use --force to force overwrite." %args.outfile)
        sys.exit(1)

    print("Parsing %s, please wait!" %args.input)

    # If the user wants an update, the output file must exist
    if args.update is True:
        if not os.path.exists(args.outfile):
            message("Cannot find %s to update. Did you specify the right path?" %args.outfile)
            sys.exit(1)
        message("Found %s to update." %args.outfile,args.quiet)
        machines = read_json(args.outfile)
    else:
        machines = dict()

    # Does the user want to disclude partitions?
    disclude_part = None
    if args.disclude_part is not None:
        disclude_part = args.disclude_part.split(',')
        message("%s will not be included." %', '.join(disclude_part),args.quiet)
    else:
        message("All partitions will be included.",args.quiet)

    input_files = args.input.split(',')
    for input_file in input_files: 
        if not os.path.exists(input_file):
            message("Cannot find %s. Did you specify the right path?" %input_file)
            sys.exit(1)
        cluster = parse_config(config_file=input_file)
        cluster_names = ",".join(list(cluster.keys()))
        message('Adding cluster %s' %(cluster_names),args.quiet)
        if disclude_part is not None:
            cluster = disclude_partitions(cluster,disclude_part)  
        machines.update(cluster)

    cluster_names = ",".join(list(machines.keys()))
    message('Compiling clusters %s' %(cluster_names),args.quiet)
    if args.print is True:
        message(json.dumps(machines, indent=4, sort_keys=True))
    else:
        write_json(machines,args.outfile)


########################################################################
# Utils
########################################################################

def message(text,quiet=False):
    if not quiet:
        print(text)

def unpack_data(data):
    config = data['config']
    nodes = data['nodes']
    partitions = data['partitions']
    return config,nodes,partitions


def pack_data(config,nodes,partitions):
    return {'config':config,
            'nodes':nodes,
            'partitions':partitions}


def combine_clusters(clusters):
    machines = dict()
    for cluster in clusters:
        for cluster_name,metadata in cluster:
            machines[cluster_name] = metadata
    return machines


def read_file(file_name, clean=True, join=False):
    '''read in a file, with optional "clean up" to remove
    comments (lines starting with #) and empty lines)
    '''
    with open(file_name,'r') as filey:
        content = filey.readlines()
    if clean is True:
        content = [c.strip('\n') 
                   for c in content 
                   if not c.startswith('#') 
                   and len(c.strip('\n')) > 0]

    if join:
        content = ''.join(content)    
    return content


def write_json(json_obj,filename,mode="w"):
    with open(filename,mode) as filey:
        filey.writelines(json.dumps(json_obj, indent=4, separators=(',', ': ')))
    return filename


def read_json(filename,mode='r'):
    with open(filename,mode) as filey:
        data = json.load(filey)
    return data


def remove_comments(line):
    return line.rsplit('#',1)[0].strip()


def parse_line_multi(line,keepers=None):
    '''parse_line_multiple will return a dictionary with keys and
    values for a line from a slurm conf, with variables expected to be separated
    by spaces. If keepers is not defined, all is kept'''
    parsed = dict()
    lines = line.strip().split('#')[0].split(' ')
    for line in lines:
        if len(line) > 0:
            params = line.split('=')
            key = params[0]
            key = "%s%s" %(key[0].capitalize(),key[1:])
            value = params[-1].strip()
            if keepers is not None:
                if key in keepers:
                    parsed[key] = value
            else:
                if key is not "\\":
                    parsed[key] = value
    return parsed



########################################################################
# Nodes
########################################################################

def get_node_variables():
    return ["RealMemory",
            "Gres",
            "Weight",
            "Feature",
            "Default"]



def break_range_expressions(node_name):
    parts = list(node_name)
    current = ''
    finished = []
    opened = False
    for c in range(len(parts)):
        part = parts[c]
        if part == '{':
            if len(current) > 0: 
                finished.append(current)       
            opened = True
            current='{'
        elif part == '}':
            if len(current) > 0:
                finished.append("%s}" %current)
                current=''       
            opened = False
        else:
            current = "%s%s" %(current,part)
              
    if opened:
        current = "%s}" %(current)
    if current not in finished and len(current)>0:
        finished.append(current)
    return finished
        

def parse_single_node(node_name):
    '''this function will parse a single string to describe a group of 
    nodes, eg gpu-27-{21,35}'''
    parts = break_range_expressions(node_name)
    options = []
    for part in parts:
        node_options = []
        if not re.search("^{|}$",part):  
            options.append([part])
        else:
            node_ranges = re.findall("[0-9]+-[0-9]+",part)
            node_lists = re.findall("[0-9]+,[0-9]+",part)
            for node_range in node_ranges:
                start,end = [int(x) for x in node_range.split('-')]
                node_options += [int(x) for x in range(start,end+1)]
            for node_list in node_lists:
                node_options += [int(x) for x in node_list.split(',')]
            options.append(node_options)
    final_options = options.pop(0)
    while len(options) > 0:
        option_set = options.pop(0)
        new_options = []
        for final_option in final_options:
            for option in option_set:
                new_options.append("%s%s" %(final_option,option))
        final_options = new_options
    return final_options


def parse_node_names(line):
    '''parse_node_names will take a whole list of nodes (multiple with ranges and
    lists in brackets) and return a list of unique, complete names.'''
    new_nodes = []
    #nodelist = re.sub("\\\\| ","",line).split('=')[-1]
    nodelist = re.sub("\\\\| ","",line)
    nodelist = nodelist.replace('[','{').replace(']','}')
    nodelist = re.split(',\s*(?![^{}]*\})', nodelist)
    for node_name in nodelist:
        contenders = [x for x in parse_single_node(node_name) if x not in new_nodes]
        new_nodes = new_nodes + contenders
    return new_nodes

def keep_going(name):
    '''A function to filter a string to determine if
    the calling function should continue. Returns False
    if the string being checked contains any flag variables.
    '''
    skip_these = ['DEFAULT','test']
    go_on = True
    for skip in skip_these:
        if name.startswith(skip):
            go_on = False
    return go_on


def parse_node_block(data):
    '''line should be the first line popped that has 'NodeName'
    and config is the entire config following that. The new node
    entry is added to the global nodes.
    '''
    config,nodes,partitions = unpack_data(data)

    line = parse_line_multi(config.pop(0))

    if "NodeName" not in line:
        return pack_data(config,nodes,partitions)

    node = line['NodeName']
    if not keep_going(node):
        return pack_data(config,nodes,partitions)
    
    # Get all variables for node group
    keepers = get_node_variables()
    node_names = parse_node_names(node)
    del line['NodeName']
    node_settings = line
    done = False

    while not done:
        line = remove_comments(config.pop(0))
        if not line.endswith('\\'):
            done = True
        updates = parse_line_multi(line,keepers)
        node_settings.update(updates)

    for node in node_names:
        if node not in nodes:
            nodes[node] = node_settings
            nodes[node]['partitions'] = [] 
        else:
            nodes[node].update(node_settings)    
    return pack_data(config,nodes,partitions)


########################################################################
# Features and Defaults
########################################################################

def parse_features(data):
    config,nodes,partitions = unpack_data(data)
    features = dict()
    for node_name,attributes in nodes.items():
        if 'Feature' in attributes:
            feature_list = attributes['Feature'].strip('"').split(',')
            for partition in attributes['partitions']:
                if partition not in features:
                    features[partition] = feature_list
                else:
                    new_features = [x for x in feature_list 
                                    if x not in features[partition]]
                    features[partition] = features[partition] + new_features
    return features


def find_defaults(data):
    defaults = dict()
    for key,datum in data.items():
        if datum:
            defaults[key] = []
            for name,attributes in datum.items():
                if "Default" in attributes:
                    defaults[key].append(name)
    return defaults

########################################################################
# Partitions
########################################################################

def get_partition_variables():
    return ["DefaultTime",
            "Default",
            "DefMemPerCPU",
            "MaxMemPerCPU",
            "AllowQos",
            "Nodes"]


def disclude_partitions(cluster,disclude_parts):
    for cluster_name, attributes in cluster.items():
        if "partitions" in attributes:
            for disclude_part in disclude_parts:
                if disclude_part in attributes['partitions']:
                    del cluster[cluster_name]['partitions'][disclude_part]
        if "nodes" in attributes:
            for node_name, node_attributes in attributes['nodes'].items():
                if "partitions" in node_attributes:    
                    update = [x for x in cluster[cluster_name]['nodes'][node_name]['partitions']
                              if x not in disclude_parts]
                    cluster[cluster_name]['nodes'][node_name]['partitions'] = update
        if "features" in attributes:
            for disclude_part in disclude_parts:
                if disclude_part in attributes['features']:
                    del cluster[cluster_name]['features'][disclude_part]
    return cluster


def parse_partition_block(data):
    '''line should be the first line popped that has 'PartitionName'
    and config is the entire config following that. The new partition
    entry is added to the global partitions. The next line (non partition)
    is returned.
    '''
    config,nodes,partitions = unpack_data(data)

    line = parse_line_multi(config.pop(0))
 
    if "PartitionName" not in line:
        return pack_data(config,nodes,partitions)

    partition_name = line['PartitionName']
    keepers = get_partition_variables()

    if not keep_going(partition_name):
        return pack_data(config,nodes,partitions)

    # Get all variables for node group
    new_partition = line
    done = False
    while not done:
        line = remove_comments(config.pop(0))
        if not line.endswith('\\'):
            done = True
        updates = parse_line_multi(line,keepers)
        if "Nodes" in updates:
            parts = parse_node_names(updates['Nodes'])
            for node in parts:
                if node in nodes:
                    if partition_name not in nodes[node]['partitions']:
                        nodes[node]['partitions'].append(partition_name)
                else:
                    nodes[node] = {'partitions':[partition_name]} 
            # Note, we don't add an exaustive list of nodes to each partition
            # But if we needed to, could do that here.
            updates['maxNodes'] = len(parts)
            del updates['Nodes']
        new_partition.update(updates)    
    partitions[partition_name] = new_partition
    return pack_data(config,nodes,partitions)


########################################################################
# Main Parser
########################################################################

def parse_config(config_file):
    '''parse a config file to return a complete list of machines
    '''
    machines = dict()
    config = read_file(config_file)    
    data = {'partitions':{},
            'nodes': {},
            'config':config}

    while data['config']:
        line = data['config'][0]
        if line.startswith('ClusterName'):
            line = data['config'].pop(0)
            cluster = parse_line_multi(line)['ClusterName']
        elif line.startswith('PartitionName'):
            data = parse_partition_block(data)
        elif line.startswith('NodeName'):
            data = parse_node_block(data)        
        else:
            data['config'].pop(0)

    # Calculate features for each partition
    machines[cluster] = dict()
    machines[cluster]['features'] = parse_features(data)

    # Find Defaults
    machines[cluster]['defaults'] = find_defaults(data)

    del data['config']
    machines[cluster].update(data)



    return machines


if __name__ == '__main__':
    main()
