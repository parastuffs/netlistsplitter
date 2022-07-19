"""
Usage:
    net-driving.py [-d <dir>] [--lef <LEF>] [--2D <NETLIST>]
    net-driving.py (--help|-h)

Options:
    -d <dir>        Partitioning directory holding Verilog netlists
    --lef <LEF>     LEF file
    --2D <NETLIST>  2D flat Verilog netlist
    -h --help       Print this help

Post-processing 3D netlists
"""

import os
import datetime
from docopt import docopt
import logging, logging.config
import sys
from alive_progress import alive_bar
import re

TOP_DIE_F = "topDie.v"
BOTTOM_DIE_F = "botDie.v"

class Instance:
    def __init__(self, name):
        self.name = name
        self.pins = dict() # dictionary of Pin objects. Key: name of the pin.

class Pin:
    def __init__(self, name, direction):
        self.name = name
        self.direction = direction
        self.net = None # Net object connected to the pin

class Net:
    def __init__(self, name):
        self.name = name
        self.instancesDirection = {} # {instanceName : direction} where direction is the direction of the Pin on the Instance connecting the Net.




if __name__ == "__main__":

    netlistDir = ""
    lefFile = ""
    netlist2DFile = ""

    instances = {} # {instanceName : Instance}
    nets = {} # {netName : Net}

    args = docopt(__doc__)
    if args["-d"]:
        netlistDir = args["-d"]
    if args["--lef"]:
        lefFile = args["--lef"]
    if args["--2D"]:
        netlist2DFile = args["--2D"]

    # Load base config from conf file.
    logging.config.fileConfig('log.conf')
    # Load logger from config
    logger = logging.getLogger('default')
    # Create new file handler
    fh = logging.FileHandler(os.path.join(netlistDir, 'net-driving_' + datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S") + '.log'))
    # Set a format for the file handler
    fh.setFormatter(logging.Formatter('%(asctime)s: %(message)s'))
    # Add the handler to the logger
    logger.addHandler(fh)

    logger.debug(args)


    ###############################
    # LEF parsing
    # Extracting pins direction
    ###############################
    logger.info(f"Reading macro definitions from {lefFile}")
    with open(lefFile, 'r') as f:
        lines = f.readlines()

    macros = {} # {macroName : {pinName : dir}}

    macroName = ""
    pinName = ""
    direction = ""
    for line in lines:
        line = line.strip()
        if 'MACRO ' in line:
            macroName = line.split(' ')[1]
            macros[macroName] = {}
        elif 'PIN ' in line:
            pinName = line.split(' ')[1]
        elif 'DIRECTION ' in line:
            direction = line.split(' ')[1] # INOUT, INPUT, OUTPUT
            if pinName != 'VDD' and pinName != 'VSS':
                macros[macroName][pinName] = direction

    with open(netlist2DFile, 'r') as f:
        lines = f.readlines()


    ####################################
    # 2D Verilog netlist parsing
    # Extracting the connectivity
    ####################################
    entry = ""
    macroName = ""
    instanceName = ""



    logger.info(f"Read connectivity from {netlist2DFile}")
    with alive_bar(len(lines)) as bar:
        for line in lines:
            bar()
            line = line.strip()

            if not line.startswith('#'):
                # Accumulate full entry
                entry += line + " "
            if ';' in line:
                # Split at '.' which marks the start of an instance pin.
                entry = entry.strip()
                tokens = entry.split('.')
                if len(tokens) > 1:
                    # logger.debug("Testing entry {}".format(tokens))
                    match = re.search("^([^\s]+) ([^\s]+) \(", tokens[0])
                    if match:
                        macroName = match.group(1)
                        instanceName = match.group(2)
                        instance = Instance(instanceName)
                        instances[instanceName] = instance
                        for pinName in macros[macroName]:
                            # print(pinName)
                            pin = Pin(pinName, macros[macroName][pinName]) # Name, direction
                            instances[instanceName].pins[pinName] = pin
                        # logger.debug("{} {}".format(macroName, instanceName))
                    for token in tokens[1:]:
                        match = re.search("^([^\(]+)\(([^\)]+)\)", token)
                        if match:
                            pinName = match.group(1)
                            netName = match.group(2)
                            net = Net(netName)
                            # logger.debug(f"{instanceName}, {pinName}")
                            net.instancesDirection[instanceName] = instances[instanceName].pins[pinName].direction
                            instances[instanceName].pins[pinName].net = net
                            nets[netName] = net
                            # sys.exit()
                # Reset entry upon encountering a ';'
                entry = ""



    ###############################################
    # TOP die netlist
    # First pass to check all feedthrough nets and
    # list the modifications needed
    ###############################################
    feedthroughs = {}   # {feedthroughName : {direction}}, with {direction} being a set of all directions of pins connecting the net to instances.
                        # The wire declaration direction will be in lower caps.

    os.chdir(netlistDir)
    with open(TOP_DIE_F, 'r') as f:
        lines = f.readlines()
    #
    # Look for '*_ft_toplevel' nets, those are the one we need to analyse and check the direction.
    #
    entry = ""
    logger.info(f"First pass on {TOP_DIE_F}")
    with alive_bar(len(lines)) as bar:
        for line in lines:
            bar()
            line = line.strip()
            entry += line + " "

            if ';' in line:
                entry = entry.strip()
                if '_ft_toplevel' in entry:
                    tokens = entry.split('.')
                    if len(tokens) > 1:
                        # logger.debug("Testing entry {}".format(tokens))
                        match = re.search("^([^\s]+) ([^\s]+) \(", tokens[0])
                        if match:
                            macroName = match.group(1)
                            instanceName = match.group(2)
                            # logger.debug("{} {}".format(macroName, instanceName))
                        for token in tokens[1:]:
                            if '_ft_toplevel' in token:
                                match = re.search("^([^\(]+)\(([^\)]+)\)", token)
                                if match:
                                    pinName = match.group(1)
                                    netName = match.group(2)
                                    direction = instances[instanceName].pins[pinName].direction
                                    # if netName not in feedthroughs:
                                    #     feedthroughs[netName] = []
                                    feedthroughs[netName].add(direction)
                                    # logger.debug(f"{instanceName}, {pinName}")
                    elif entry.startswith('input') or entry.startswith('output'):
                        match = re.search("^([^\s]+) ([^;]+)", entry)
                        if match:
                            direction = match.group(1)
                            netName = match.group(2)
                            feedthroughs[netName] = set()
                            feedthroughs[netName].add(direction)
                # Reset entry upon encountering a ';'
                entry = ""

    # logger.debug(feedthroughs)

    feedthroughsChanges = {} # {feedthroughName : newDirection}

    for ft in feedthroughs:
        directions = feedthroughs[ft]
        if len(directions) == 2:
            if 'input' in directions and 'OUTPUT' in directions:
                feedthroughsChanges[ft] = 'output'
            elif 'output' in directions and 'INPUT' in directions:
                feedthroughsChanges[ft] = 'input'

    # logger.debug(feedthroughsChanges)

    ####################################################
    # 2nd pass on topDie.v, changing the port direction
    ####################################################
    topDieOutStr = ""
    logger.info(f"Second pass on {TOP_DIE_F}")
    with alive_bar(len(lines)) as bar:
        for line in lines:
            bar()
            line = line.strip()
            if '_ft_toplevel' in line:
                # logger.debug(f"Considering line {line}")
                if line.startswith('input') or line.startswith('output'):
                    # logger.debug(f"Checking line '{line}'")
                    match = re.search("^([^\s]+) ([^;]+)", line)
                    if match:
                        direction = match.group(1)
                        netName = match.group(2)
                        if netName in feedthroughsChanges:
                            # logger.debug(f"{netName} needs to be changed to {feedthroughsChanges[netName]}")
                            line = f"{feedthroughsChanges[netName]} {netName};"
                        # else:
                            # logger.debug(f"{netName} needs no change.")
            topDieOutStr += f"{line}\n"

    with open(TOP_DIE_F+".new", 'w') as f:
        f.write(topDieOutStr)

    ##########################################################
    # Pass on botDie.v to adapt the feedthroughs direction
    ##########################################################
    logger.info("Change the direction of feedthroughs in bottom die netlist.")
    with open(BOTTOM_DIE_F, 'r') as f:
        lines = f.readlines()

    botDieOutStr = ""
    with alive_bar(len(lines)) as bar:
        for line in lines:
            bar()
            line = line.strip()
            if '_ft_toplevel' in line:
                if line.startswith('input') or line.startswith('output'):
                    match = re.search("^([^\s]+) ([^;]+)", line)
                    if match:
                        direction = match.group(1)
                        netName = match.group(2)
                        if netName in feedthroughsChanges:
                            direction = feedthroughsChanges[netName]
                            if direction == "input":
                                direction = "output"
                            elif direction == "output":
                                direction = "input"
                            line = f"{direction} {netName};"
            botDieOutStr += f"{line}\n"

    with open(BOTTOM_DIE_F+".new", 'w') as f:
        f.write(botDieOutStr)




