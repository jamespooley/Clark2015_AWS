# spot-model/utils.py
#
# Author: Daniel Clark, 2015

'''
This module contains various utilities for the modules and scripts in
this folder or package
'''

# Apply simulation dataframe
def apply_cost_model(sim_df_row):
    '''
    Apply cost model to the simulation results dataframe by row

    Parameters
    ----------
    sim_df_row : pandas.Series
        dataframe row from AWS simulation result dataframe

    Returns
    -------
    stat_series : pandas.Series
        dataframe series with the configuration, simulation run, and
        costs
    '''

    # Import packages
    import numpy as np
    import pandas as pd
    from spot_price_model import calc_s3_model_costs

    # Init variables
    run_time = sim_df_row['compute_time']
    wait_time = sim_df_row['wait_time']
    node_cost = sim_df_row['per_node_cost']
    first_iter_time = sim_df_row['first_iter_time']
    num_jobs = sim_df_row['num_datasets']
    jobs_per = sim_df_row['jobs_per_node']
    num_nodes = min(np.ceil(float(num_jobs)/jobs_per), 20)
    av_zone = sim_df_row['av_zone']
    in_gb = sim_df_row['in_gb']
    out_gb = sim_df_row['out_gb']
    up_rate = sim_df_row['up_rate']
    down_rate = sim_df_row['down_rate']

    # Grab costs from s3 model
    total_cost, instance_cost, ebs_storage_cost, s3_cost, \
    s3_storage_cost, s3_req_cost, s3_xfer_cost, \
    total_time, run_time, wait_time, \
    xfer_up_time, s3_upl_time, s3_download_time = \
        calc_s3_model_costs(run_time, wait_time, node_cost, first_iter_time,
                             num_jobs, num_nodes, jobs_per, av_zone,
                             in_gb, out_gb, up_rate, down_rate)

    # Create dictionary
    stat_dict = {'start_time' : sim_df_row['start_time'],
                 'proc_time' : sim_df_row['proc_time'],
                 'num_datasets' : num_jobs,
                 'jobs_per_node' : jobs_per,
                 'num_jobs_iter' : sim_df_row['num_jobs_iter'],
                 'bid_ratio' : sim_df_row['bid_ratio'],
                 'bid_price' : sim_df_row['bid_price'],
                 'median_history' : sim_df_row['median_history'],
                 'mean_history' : sim_df_row['mean_history'],
                 'stdev_history' : sim_df_row['stdev_history'],
                 'run_time' : run_time,
                 'wait_time' : wait_time,
                 'per_node_cost' : node_cost,
                 'num_interrupts' : sim_df_row['num_interrupts'],
                 'first_iter_time' : first_iter_time,
                 'num_nodes' : num_nodes,
                 'av_zone' : av_zone,
                 'in_gb' : in_gb,
                 'up_rate' : up_rate,
                 'down_rate' : down_rate,
                 # S3 model costs
                 'total_cost' : total_cost,
                 'instance_cost' : instance_cost,
                 'ebs_storage_cost' : ebs_storage_cost,
                 's3_cost' : s3_cost,
                 's3_storage_cost' : s3_storage_cost,
                 's3_req_cost' : s3_req_cost,
                 's3_xfer_cost' : s3_xfer_cost,
                 'total_time' : total_time,
                 'xfer_up_time' : xfer_up_time,
                 's3_upl_time' : s3_upl_time,
                 's3_download_time' : s3_download_time}

    # Convert dict to pandas Series
    stat_series = pd.Series(stat_dict)

    # Return new dataframe row
    return stat_series


# Add comfig columns to simulation dataframe
def add_config_columns(sim_df_csv, cfg_yaml, out_dir):
    '''
    Function to add AWS simulation configuration parameters to the
    simulation dataframe csv generated by the spot_price_model.main()
    function.

    Parameters
    ----------
    sim_df_csv : string
        filepath to the siulation dataframe csv; this should be in the
        availability zone folder it was simulated under
    cfg_yaml : string
        filepath to the AWS simulation configuration yaml file that was
        used to launch the simulation
    out_dir : string
        filepath to the base output directory to store the modified
        dataframe

    Returns
    -------
    new_df : pandas.DataFrame object
        the updated dataframe
    '''

    # Import packages
    import os
    import pandas as pd
    import yaml

    # Init variables
    sim_df_csv = os.path.abspath(sim_df_csv)
    av_zone = os.path.dirname(sim_df_csv).split('/')[-1]
    sim_cfg = yaml.load(open(cfg_yaml, 'r'))

    # Grab values from config
    in_gb = sim_cfg['in_gb']
    out_gb = sim_cfg['out_gb']
    out_gb_dl = sim_cfg['out_gb_dl']
    up_rate = sim_cfg['up_rate']
    down_rate = sim_cfg['down_rate']

    # Load in dataframe
    new_df = pd.DataFrame.from_csv(sim_df_csv)

    # Populate new columns
    new_df['av_zone'] = av_zone
    new_df['in_gb'] = in_gb
    new_df['out_gb'] = out_gb
    new_df['out_gb_dl'] = out_gb_dl
    new_df['up_rate'] = up_rate
    new_df['down_rate'] = down_rate

    # Save dataframe
    out_csv_dir = os.path.join(out_dir, av_zone)
    if not os.path.exists(out_csv_dir):
        try:
            os.makedirs(out_csv_dir)
        except Exception as err:
            print err

    new_df.to_csv(os.path.join(out_csv_dir, os.path.basename(sim_df_csv)))

    # Return new dataframe
    return new_df


# Build data frame
def build_big_df(av_zone_dir):
    '''
    Function to parse and merge the simulation results from the
    *_sim and *_stats files into one big data frame based on the
    availability zone directory provided; it saves this to a csv

    Parameters
    ----------
    av_zone_dir : string
        file path to the directory containing the simulation results

    Returns
    -------
    big_df : pandas.DatFrame object
        a merged dataframe with all of the stats for the simulation
    '''

    # Import packages
    from spot_price_model import spothistory_from_dataframe
    import glob
    import numpy as np
    import os
    import pandas as pd

    # Init variables
    df_list = []
    av_zone = av_zone_dir.split('/')[-1]
    csvs = glob.glob(os.path.join(av_zone_dir, '*_stats.csv'))

    # Print av zone of interest being created
    print av_zone
    spot_history = spothistory_from_dataframe('spot_history/merged_dfs.csv', 'c3.8xlarge', 'Linux/UNIX', av_zone)

    # Iterate through csvs
    for stat_csv in csvs:
        # Get pattern to find sim dataframe
        csv_pattern = stat_csv.split('_stats.csv')[0]
        sim_csv = csv_pattern + '_sim.csv'
        stat_df = pd.DataFrame.from_csv(stat_csv)
        sim_df = pd.DataFrame.from_csv(sim_csv)

        # Extract params from filename
        fp_split = csv_pattern.split('-jobs')
        bid_ratio = float(fp_split[1][1:].split('-bid')[0])
        bid_price = bid_ratio*spot_history.mean()

        ### Download time fix ###
        # *Note the CPAC, ANTs, and Freesurfer csv outputs need this
        # CPAC pipeline params
        jobs_per = 3
        down_rate = 20
        out_gb_dl = 2.3
        down_gb_per_sec = down_rate/8.0/1024.0
        # Variables for download time fix
        num_ds = int(fp_split[0].split('/')[-1].split('_')[-1])
        num_nodes = min(np.ceil(float(num_ds)/jobs_per), 20)
        num_iter = np.ceil(num_ds/float((jobs_per*num_nodes)))
        num_jobs_n1 = ((num_iter-1)*num_nodes*jobs_per)
        res_xfer_out = (num_ds-num_jobs_n1)*(out_gb_dl/down_gb_per_sec)
        # Fix download time
        #stat_df['Download time'] += res_xfer_out/60.0 

        # Add to stat df
        len_df = len(stat_df)
        stat_df['Sim index'] = sim_df.index
        stat_df['Av zone'] = pd.Series([av_zone]*len_df, index=stat_df.index)
        stat_df['Bid ratio'] = pd.Series([bid_ratio]*len_df, index=stat_df.index)
        stat_df['Bid price'] = pd.Series([bid_price]*len_df, index=stat_df.index)
        stat_df['Num datasets'] = pd.Series([num_ds]*len_df, index=stat_df.index)
        stat_df['Start time'] = sim_df['Start time']
        stat_df['Interrupts'] = sim_df['Interrupts']
        stat_df['First Iter Time'] = sim_df['First Iter Time']

        # Add to dataframe list
        df_list.append(stat_df)

    # Status update
    print 'done making df list, now concat to big df...'
    big_df = pd.concat(df_list, ignore_index=True)

    # Write to disk as csv
    print 'Saving to disk...'
    big_df.to_csv('./%s.csv' % av_zone)
    print 'done writing!'

    # Return dataframe
    return big_df


# Build list of processes to use in multi-proc
def build_proc_list(zones_basedir):
    '''
    Function to build a list of build_big_df processes from a directory
    of availability zones folders

    Parameters
    ----------
    zones_basedir : string
        base directory where the availability zone folders are residing

    Returns
    -------
    proc_list : list
        a list of multiprocessing.Process objects to run the
        build_big_df function
    '''

    # Import packages
    import glob
    import os
    import pandas as pd
    from multiprocessing import Process

    # Init variables
    av_zone_fp = os.path.join(zones_basedir, '*')
    av_zones_dirs = glob.glob(av_zone_fp)

    # Build big dictionary
    proc_list = [Process(target=build_big_df, args=(av_zone_dir,)) \
                 for av_zone_dir in av_zones_dirs]

    # Return the process list
    return proc_list


# Convert spot history list to dataframe csv
def pklz_to_df(out_dir, pklz_file):
    '''
    Function to convert pklz list file to csv dataframe

    Parameters
    ----------
    out_dir : string
        filepath to the output base directory to store the dataframes
    pklz_file : string
        filepath to the .pklz file, which contains a list of
        boto spot price history objects

    Returns
    -------
    None
        this function saves the dataframe to a csv
    '''

    # Import packages
    import gzip
    import os
    import pandas as pd
    import pickle as pk
    import time

    # Init variables
    gfile = gzip.open(pklz_file)
    sh_list = pk.load(gfile)
    idx = 0

    # If the list is empty return nothing
    if len(sh_list) == 0:
        return

    # Init data frame
    df_cols = ['Timestamp', 'Price', 'Region', 'Availability zone',
               'Product', 'Instance type']
    merged_df = pd.DataFrame(columns=df_cols)

    # Iterate through histories
    for sh in sh_list:
        timestamp = str(sh.timestamp)
        price = sh.price
        reg = str(sh.region).split(':')[-1]
        av_zone = str(sh.availability_zone)
        prod = str(sh.product_description)
        inst = str(sh.instance_type)
        df_entry = [timestamp, price, reg, av_zone, prod, inst]
        merged_df.loc[idx] = df_entry
        idx += 1
        print '%d/%d' % (idx, len(sh_list))

    # Write out merged dataframe
    out_csv = os.path.join(out_dir, reg, prod.replace('/', '-'), inst, str(time.time()) + '.csv')
    csv_dir = os.path.dirname(out_csv)

    # Check if folders exists
    if not os.path.exists(csv_dir):
        os.makedirs(csv_dir)

    print 'Done merging, writing out to %s...' % out_csv
    merged_df.to_csv(out_csv)


# Run jobs in parallel
def run_in_parallel(proc_list, num_cores):
    '''
    Function to kick off a list of processes in parallel, guaranteeing
    that a fixed number of cores or less is running at all times

    Parameters
    ----------
    proc_list : list
        a list of multiprocessing.Process objects
    num_cores : integer
        the number of cores or processes to run at once

    Returns
    -------
    None
        there is no return value for this function
    '''

    # Import packages
    import time

    # Init variables
    idx = 0
    job_queue = []

    # While loop for when jobs are still running
    while idx < len(proc_list):
        if len(job_queue) == 0 and idx == 0:
            idc = idx
            for p in proc_list[idc:idc+num_cores]:
                p.start()
                job_queue.append(p)
                idx += 1
        else:
            for job in job_queue:
                if not job.is_alive():
                    print 'found dead job', job
                    loc = job_queue.index(job)
                    del job_queue[loc]
                    if idx < len(proc_list):
                        proc_list[idx].start()
                    else:
                        break
                    job_queue.append(proc_list[idx])
                    idx += 1
            time.sleep(2)


# Print status of file progression in loop
def print_loop_status(itr, full_len):
    '''
    Function to print the current percentage completed of a loop
    Parameters
    ----------
    itr : integer
        the current iteration of the loop
    full_len : integer
        the full length of the loop
    Returns
    -------
    None
        the function prints the loop status, but doesn't return a value
    '''

    # Print the percentage complete
    per = 100*(float(itr)/full_len)
    print '%d/%d\n%f%% complete' % (itr, full_len, per)


# Setup log file
def setup_logger(logger_name, log_file, level, to_screen=False):
    '''
    Function to initialize and configure a logger that can write to file
    and (optionally) the screen.

    Parameters
    ----------
    logger_name : string
        name of the logger
    log_file : string
        file path to the log file on disk
    level : integer
        indicates the level at which the logger should log; this is
        controlled by integers that come with the python logging
        package. (e.g. logging.INFO=20, logging.DEBUG=10)
    to_screen : boolean (optional)
        flag to indicate whether to enable logging to the screen

    Returns
    -------
    logger : logging.Logger object
        Python logging.Logger object which is capable of logging run-
        time information about the program to file and/or screen
    '''

    # Import packages
    import logging

    # Init logger, formatter, filehandler, streamhandler
    logger = logging.getLogger(logger_name)
    logger.setLevel(level)
    formatter = logging.Formatter('%(asctime)s : %(message)s')

    # Write logs to file
    file_handler = logging.FileHandler(log_file)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    # Write to screen, if desired
    if to_screen:
        stream_handler = logging.StreamHandler()
        stream_handler.setFormatter(formatter)
        logger.addHandler(stream_handler)

    # Return the logger
    return logger


# Make executable
if __name__ == '__main__':

    # Import packages
    import sys

    # Grab az_zone folders base
    zones_basedir = str(sys.argv[1])

    # Call main
    proc_list = build_proc_list(zones_basedir)

    #build_big_df('~/Documents/projects/Clark2015_AWS/spot-model/out/us-east-1a')
    # Run in parallel
    run_in_parallel(proc_list, 6)
