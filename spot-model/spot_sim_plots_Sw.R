# spot-model/spot_sim_plots.R
#
# Author: Cameron Craddock, Daniel Clark (2015)

# Import packages
library(ggplot2)
library(gridExtra)
library(plyr)
library(reshape2)

# Create aggregated dataframe
aggregate_df <- function(csv, func_name) {

  # Read in dataframe
  print('Reading in full dataframe...')
  full_df <- read.csv(csv)

  # Check to see if mean or median
  print('Aggregating dataframe...')
  if (func_name == 'mean') {
    df_agg <- ddply(full_df, .(av_zone, bid_ratio, num_datasets), summarize,
                    mean_instance_cost=mean(instance_cost),
                    mean_num_interr=mean(num_interrupts),
                    mean_pernode_cost=mean(per_node_cost),
                    mean_run_time=mean(run_time),
                    mean_total_cost=mean(total_cost),
                    mean_total_time=mean(total_time),
                    mean_wait_time=mean(wait_time))
  } else if (func_name == 'median') {
      df_agg <- ddply(full_df, .(av_zone, bid_ratio, num_datasets), summarize,
                      median_instance_cost=median(instance_cost),
                      median_num_interr=median(num_interrupts),
                      median_pernode_cost=median(per_node_cost),
                      median_run_time=median(run_time),
                      median_total_cost=median(total_cost),
                      median_total_time=median(total_time),
                      median_wait_time=median(wait_time))
  }

  # Rename regions
  df_agg <- format_region(df_agg)

  # Return the aggregated dataframe
  return(df_agg)
}


# Populate regions with name formatted
format_region <- function(data_frame) {
  data_frame$region[grep('us-west-1',data_frame$av_zone)]='N. California'
  data_frame$region[grep('us-west-2',data_frame$av_zone)]='Oregon'
  data_frame$region[grep('us-east-1',data_frame$av_zone)]='N. Virginia'
  data_frame$region[grep('eu-west-1',data_frame$av_zone)]='Ireland'
  data_frame$region[grep('eu-central-1',data_frame$av_zone)]='Frankfurt'
  data_frame$region[grep('ap-southeast-1',data_frame$av_zone)]='Singapore'
  data_frame$region[grep('ap-southeast-2',data_frame$av_zone)]='Sydney'
  data_frame$region[grep('ap-northeast-1',data_frame$av_zone)]='Tokyo'
  data_frame$region[grep('sa-east-1',data_frame$av_zone)]='Sao Paulo'
  #data_frame$region=factor(data_frame$region)

  # Return the data frame with region header
  return(data_frame)
}


# Format cost/time vs num_ds/bid_ratio plots
format_cost_times <- function(plot_obj) {

  # Add ggplot2 formatting to plot object
  frmt_plot <- plot_obj +
    geom_line() +
    facet_grid(region~., scales='free_y') +
    theme_bw() +
    theme(legend.position='None',
          axis.title.x=element_text(size=10, colour='black', vjust=-.8),
          axis.title.y=element_text(size=10, colour='black'),
          axis.text.x=element_text(size=8, colour='black', angle=35),
          axis.text.y=element_text(size=8, colour='black'),
          strip.text.y=element_text(size=8, colour='black'))

  # Return formatted plot
  return(frmt_plot)
}


# Plot and print simulation results to pdf
plot_cost_times <- function(agg_df, num_ds, bid_rat, out_file) {
  ## Ceiling costs to round to the nearest dollar
  fixed_ds_df <- subset(agg_df, num_datasets==num_ds)
  # Cost vs. Bid ratio
  cost_br <- ggplot(fixed_ds_df,
                    aes(x=bid_ratio, y=ceiling(mean_total_cost), col=av_zone)) +
             labs(x='Bid ratio', y='Cost ($)',
                  title=paste('Cost vs bid ratio, datasets = ', num_ds))
  cost_br <- cost_br + geom_hline(aes(yintercept=on_demand_total_cost))
  cost_br <- format_cost_times(cost_br)

  # Cost vs. Num datasets
  cost_ds <- ggplot(subset(agg_df, bid_ratio==bid_rat),
                    aes(x=num_datasets, y=ceiling(mean_total_cost), col=av_zone)) +
             labs(x='Number of datasets', y='Cost ($)',
                  title=paste('Cost vs datasets, bid ratio = ', bid_rat))
  cost_ds <- format_cost_times(cost_ds)

  # Cost vs. Bid ratio
  time_br <- ggplot(subset(agg_df, num_datasets==num_ds),
                    aes(x=bid_ratio, y=mean_total_time/3600, col=av_zone)) +
             labs(x='Bid ratio', y='Time (hours)',
                  title=paste('Time vs bid ratio, datasets = ', num_ds))
  time_br <- time_br + geom_hline(aes(yintercept=static_total_time/3600.0))
  time_br <- format_cost_times(time_br)

  # Cost vs. Num datasets
  time_ds <- ggplot(subset(agg_df, bid_ratio==bid_rat),
                    aes(x=num_datasets, y=mean_total_time/3600, col=av_zone)) +
             labs(x='Number of datasets', y='Time (hours)',
                  title=paste('Time vs datasets, bid ratio = ', bid_rat))
  time_ds <- format_cost_times(time_ds)

  # Open pdf file to save plots to
  pdf(file=out_file, title='sim_results', width=180/25.4, height=8,
      family='ArialMT', paper='special')

  # Set up the 2x2 grid
  grid.newpage()
  layout=grid.layout(1,2)
  pushViewport(viewport(layout=layout))

  # Print to pdf
  print(cost_br, vp=viewport(layout.pos.row=1, layout.pos.col=1))
  #print(cost_ds, vp=viewport(layout.pos.row=2, layout.pos.col=1))
  print(time_br, vp=viewport(layout.pos.row=1, layout.pos.col=2))
  #print(time_ds, vp=viewport(layout.pos.row=2, layout.pos.col=2))

  # Shutdown printout device
  dev.off()
}

# Plot and print simulation results to pdf
plot_tradeoffs <- function(agg_df, num_ds, bid_rat, out_file) {
  ## Ceiling costs to round to the nearest dollar
  fixed_ds_df <- subset(agg_df, num_datasets==num_ds)

  # Cost vs. Bid ratio
  time_to <- ggplot(fixed_ds_df,
                    aes(x=bid_ratio, y=time_to_cost, col=av_zone)) +
    labs(x='Bid ratio', y='Cost ($)',
         title=paste('Time/cost vs bid ratio, datasets = ', num_ds))
  time_to <- time_to + geom_hline(aes(yintercept=time_to_cost_od))
  time_to <- format_cost_times(time_to)
  
  # Cost vs. Bid ratio
  time_pl <- ggplot(fixed_ds_df,
                    aes(x=bid_ratio, y=time_plus_cost, col=av_zone)) +
    labs(x='Bid ratio', y='Cost ($)',
         title=paste('Time/cost vs bid ratio, datasets = ', num_ds))
  time_pl <- time_pl + geom_hline(aes(yintercept=time_plus_cost_od))
  time_pl <- format_cost_times(time_pl)

  # Open pdf file to save plots to
  pdf(file=out_file, title='sim_results', width=180/25.4, height=8,
      family='ArialMT', paper='special')
  
  # Set up the 2x2 grid
  grid.newpage()
  layout=grid.layout(1,2)
  pushViewport(viewport(layout=layout))
  
  # Print to pdf
  print(time_to, vp=viewport(layout.pos.row=1, layout.pos.col=1))
  #print(cost_ds, vp=viewport(layout.pos.row=2, layout.pos.col=1))
  print(time_pl, vp=viewport(layout.pos.row=1, layout.pos.col=2))
  #print(time_ds, vp=viewport(layout.pos.row=2, layout.pos.col=2))
  
  # Shutdown printout device
  dev.off()
}


# Plot correlation plots for costs and times
plot_correlations <- function(sim_stat_df, bid_ratio, pipeline) {
  # Plot
  # Average sim vs static costs
  sim_vs_stat_cost <- ggplot(subset(sim_stat_df, bid_ratio=bid_ratio), 
                             aes(x=static_total_cost, y=mean_total_cost,
                                 color=factor(region), size=factor(num_datasets))) +
                      labs(x='Static model total cost ($)',
                           y='Mean simulation total cost ($)',
                           title=paste('Mean simulation costs vs Static model costs, bid ratio =',
                                       bid_ratio)) +
                      geom_point(alpha=2/10)
  # Write out to pdf
  pdf(file=file.path(proj_base_dir, 'spot-model/plots',
                     paste(pipeline, '_mean_sim_vs_static_costs.pdf', sep='')),
      width=11, height=8)
  print(sim_vs_stat_cost)
  dev.off()

  # Average sim vs static times
  sim_vs_stat_time <- ggplot(subset(sim_stat_df, bid_ratio=bid_ratio),
                             aes(x=static_total_time/3600,y=mean_total_time/3600,
                                 color=factor(region), size=factor(num_datasets))) +
                      labs(x='Static model total time (hrs)',
                           y='Mean simulation total time (hrs)',
                           title=paste('Mean simulation time vs Static model time, bid ratio =',
                                       bid_ratio)) +
                      geom_point(alpha=2/10)
  # Write out to pdf
  pdf(file=file.path(proj_base_dir, 'spot-model/plots',
                     paste(pipeline, '_mean_sim_vs_static_times.pdf', sep='')),
      width=11, height=8)
  print(sim_vs_stat_time)
  dev.off()
}


# Plot correlation plots for costs
plot_cost_ratio <- function(sim_stat_df, pipeline, bid_ratio, num_datasets, itr, x_axis) {

  # Ratio vs bid ratio
  if (x_axis == 'bid_ratio') {
    # Get only dataframe at fixed number of datasets
    subset_df <- subset(sim_stat_df, num_datasets=num_datasets)

    # Average sim vs static costs
    cost_ratio_plot <- ggplot(subset_df, aes(x=bid_ratio, y=cost_ratio,
                                              color=factor(region))) +
      labs(x='Bid ratio',
           y='Static cost to mean simulation cost ratio',
           title=paste(pipeline, ' - cost ratio vs number of datasets, num datasets =',
                       num_datasets)) +
      geom_point(alpha=2/10)

  }

  # Ratio vs num datasets
  else if (x_axis == 'num_datasets') {
    # Get only dataframe at fixed bid ratio
    subset_df <- subset(sim_stat_df, bid_ratio=bid_ratio)

    # Average sim vs static costs
    cost_ratio_plot <- ggplot(subset_df, aes(x=num_datasets, y=cost_ratio,
                                          color=factor(region))) +
      labs(x='Number of datasets',
           y='Static cost to mean simulation cost ratio',
           title=paste(pipeline, ' - cost ratio vs number of datasets, bid ratio =',
                       bid_ratio, sep='')) +
      geom_point(alpha=2/10)

  }
  return(cost_ratio_plot)

}

# Plot correlation plots for costs
plot_time_ratio <- function(sim_stat_df, pipeline, bid_ratio, num_datasets, itr, x_axis) {

  # Ratio vs bid ratio
  if (x_axis == 'bid_ratio') {
    # Get only dataframe at fixed number of datasets
    subset_df <- subset(sim_stat_df, num_datasets=num_datasets)

    # Average sim vs static costs
    time_ratio_plot <- ggplot(subset_df, aes(x=bid_ratio, y=time_ratio,
                                             color=factor(region))) +
      labs(x='Bid ratio',
           y='Static runtime to mean simulation runtime ratio',
           title=paste(pipeline, ' - time ratio vs number of datasets, num datasets =',
                       num_datasets)) +
      geom_point(alpha=2/10)
  }

  # Ratio vs num datasets
  else if (x_axis == 'num_datasets') {
    # Get only dataframe at fixed bid ratio
    subset_df <- subset(sim_stat_df, bid_ratio=bid_ratio)

    # Average sim vs static costs
    time_ratio_plot <- ggplot(subset_df, aes(x=num_datasets, y=time_ratio,
                                             color=factor(region))) +
    labs(x='Number of datasets',
         y='Static runtime to mean simulation runtime ratio',
         title=paste(pipeline, ' - time ratio vs number of datasets, bid ratio =',
                     bid_ratio)) +
    geom_point(alpha=2/10)
  }

  return(time_ratio_plot)
}


# Init variables
# Local dir of project base on computer
proj_base_dir <- '~/Documents/projects/Clark2015_AWS'
# Relative path of project csvs
rel_csvs_dir <- 'spot-model/csvs'

# Input parameters
# Pipeline
pipeline <- 'ants'
# Plotting parameters
bid_ratio = 2.5
num_datasets = 1000

# Define csv
sim_stat_csv <- file.path(proj_base_dir, rel_csvs_dir,
                          paste(pipeline, '_merged.csv', sep=''))

# Load in sim vs stat dataframe
sim_stat_df <- read.csv(sim_stat_csv)

sim_stat_df$region = ''
region_df <- format_region(sim_stat_df)

# To write out plots
plot_cost_times(region_df, num_datasets, bid_ratio,
                file.path(proj_base_dir, 'spot-model/plots',
                          paste(pipeline,'_sim_mean.pdf', sep='')))

# Plot the correlations between simultions and static models
plot_correlations(region_df, bid_ratio, pipeline)

# Iterate over pipelines for plots
pipelines <- c('ants', 'cpac', 'fs')
for (p_idx in 1:3) {
  # Init pipeline
  pipeline <- pipelines[p_idx]

  # Define csv
  sim_stat_csv <- file.path(proj_base_dir, rel_csvs_dir,
                            paste(pipeline, '_avg_sims_and_static.csv', sep=''))
  # Load in sim vs stat dataframe
  sim_stat_df <- read.csv(sim_stat_csv)

  # Make plots
  # Plot cost and times vs bid ratio and num datasets
  plot_cost_times(ants_df, num_datasets, bid_ratio,
                  file.path(proj_base_dir, 'spot-model/plots',
                            paste(pipeline,'_sim_mean.pdf', sep='')))

  # Plot the correlations between simultions and static models
  plot_correlations(sim_stat_df, bid_ratio, pipeline)

  # Plot ratios vs bid ratios
  cost_plot_br <- plot_cost_ratio(sim_stat_df, pipeline, bid_ratio, num_datasets, p_idx, 'bid_ratio')
  time_plot_br <- plot_time_ratio(sim_stat_df, pipeline, bid_ratio, num_datasets, p_idx, 'bid_ratio')
  if (p_idx == 1) {
    # Open pdf file to save plots to
    pdf(file=paste('~/bid_ratio.pdf'), width=24, height=8)
    # Set up the 2x3 grid
    grid.newpage()
    layout=grid.layout(2,3)
    pushViewport(viewport(layout=layout))
  }
  # Print to pdf
  print(cost_plot_br, vp=viewport(layout.pos.row=1, layout.pos.col=p_idx))
  print(time_plot_br, vp=viewport(layout.pos.row=2, layout.pos.col=p_idx))
  # Write out to pdf
  if (p_idx == 3) {
    dev.off()
  }

#   # Plot ratios vs num datasets
#   cost_plot_ds <- plot_cost_ratio(sim_stat_df, pipeline, bid_ratio, num_datasets, p_idx, 'num_datasets')
#   time_plot_ds <- plot_time_ratio(sim_stat_df, pipeline, bid_ratio, num_datasets, p_idx, 'num_datasets')
#   # Open pdf file to save plots to
#   if (p_idx == 1) {
#     pdf(file=paste('~/num_datasets.pdf'), width=24, height=8)
#     # Set up the 2x3 grid
#     grid.newpage()
#     layout=grid.layout(2,3)
#     pushViewport(viewport(layout=layout))
#   }
#   # Print to pdf
#   print(cost_plot_ds, vp=viewport(layout.pos.row=1, layout.pos.col=p_idx))
#   print(time_plot_ds, vp=viewport(layout.pos.row=2, layout.pos.col=p_idx))
#   if (p_idx == 3) {
#     dev.off()
#   }
}
