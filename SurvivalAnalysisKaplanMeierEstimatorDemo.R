# This notebook illustrates the effectiveness of survival analysis statistics to model event based processes.
# The Kaplan-Meier estimator is used to obtain a survival function using a sample of random data generated from a weibull distribution. This script can be easily adapted for other distributions.

# First the required R packages are loaded.
# Next a number of functions are defined. This first generates random data based on a (weibull) distribution function (generate_deal). Next is a function which is used to display the obtained results and the theoretical expected values (plot_km_vs_theoretical_value). The final 2 functions retrieve the period event rate and the cumulative event rate from the (weibull) distribution function.

library(ggplot2)
library(dplyr)
library(survival)

generate_deal <- function(nbr, end_period = 3650, horizon_period = 3650, minimum_duration = 1825, density_function = 0.0001) {
  #' This function generates a number (nbr) of deals based on the density function (default_density) and returns these as a data frame.
  #' Each of the deals starts at a random period from 1 to end_period. Each of the deals has a minimum original maturity of minimum_duration. The horizon_period is the period at which the deals are being observed (aka reporting date).
  #' The data frame contains 6 columns.
  #' The end period is the value of the input variable which is the latest period at which a deal can start.
  #' The deal period is a random period between period 1 and the end period at which the deal starts.
  #' The time value is the number of periods after the deal period that a deal defaulted or matured or when the horizon period was reached (which ever occured first)
  #' The censor value indicates if the deal was censored (id est the deal did not default at the deal period + time)
  #' The maturity period is a random period between the deal period and the end period increased with the deal period and the minimum duration. It is the period in which the deal will mature if no default occured before that period.
  #' The default period is the period when a deal defaulted. If it did not default the value is set to -1.
  # Check that the horizon period is at least equal to the end period
  if (horizon_period < end_period) {
    print('The horizon period can not be smaller than the end period. It has been set equal to the horizon period for the generation of data.')
    horizon_period <- end_period
  }
  # The deal period is a random period between the start period (= 1) and the end period
  deal_period <- sample(1:end_period, nbr, TRUE)
  # Initially we apply the same logic to the maturity period (so for the moment a deal can mature before it starts)
  maturity_period <- sample(1:end_period, nbr, TRUE)
  # Convert to a data frame
  data <- as.data.frame(cbind(end_period,deal_period,maturity_period))
  # The maturity period is increase with the deal period and the minimum duration
  data$maturity_period <- data$deal_period + data$maturity_period + minimum_duration
  # Without default the time value for the survival analysis is the minimum of the maturity period and the horizon period reduced with the deal period
  data$time <- data$maturity_period
  data$time[which(horizon_period < data$maturity_period)] <- horizon_period
  data$time <- data$time - data$deal_period
  # Without default all deals are censored for the survival analysis (set to 0 and NOT to 1)
  data$censor <- 0
  # Initially set all deals as not defaulted
  data$default_period <- -1
  ## Iterate over the data to determine a default period and time (for each time period until the deal time)
  for (time in 1:end_period) {
    # here we use a constant daily default rate (update with a function call to a weibull if time permits)
    default_rate <- density_function(period = time)
    default_check <- runif(n = nbr) # generates nbr uniform random variables from 0 to 1
    # if the default check is smaller than the default rate and the deal has not matured nor has it defaulted in an earlier period
    # then set the default period to the deal date increased with the current value of time variable we are iterating over
    data$default_period[which(default_check < default_rate & time < data$time & data$default_period == -1)] <- data$deal_period[which(default_check < default_rate & time < data$time & data$default_period == -1)] + time
    # update the censor status accordingly (defaulted = not censored)
    data$censor[which(data$default_period == data$deal_period + time)] <- 1 # set to 1 and NOT to 0
    # update the time value accordingly
    data$time[which(default_check < default_rate & time < data$time & data$default_period == data$deal_period + time)] <- time
  }
  return(data)
}

plot_km_vs_theoretical_value <- function(KM, horizon, cumulative_density_function) {
  # Function to plot the Kaplan-Meier estimator and the expected values of the cumulative density function.
  plot(KM, xlim = c(0,horizon), ylim = c(0,1), col = 'blue', xaxs = 'r') # plots the KM with 95% confidence intervals
  par(new=TRUE)
  xi = seq(0, horizon, length=10*horizon)
  yi = cumulative_density_function(period = xi)
  plot(x = xi, y = 1 - yi, xlim = c(0,horizon), ylim = c(0,1), col = 'green',
       xlab = 'theoretical = green, Kaplan Meier = blue', xaxs = 'r', main = paste0('number of deals ', KM$n))
}

get_period_event_rate_weibull <- function(period, k = k_value, lambda = lambda_value) {
  p <- pweibull(period,k,scale = lambda)
  p_prev <- pweibull(period - 1,k,scale = lambda)
  return((p - p_prev) / (1 - p_prev))
}

get_period_cumulative_event_rate_weibull <- function(period, k = k_value, lambda = lambda_value) {
  return(pweibull(period,k,scale = lambda))
}

# Below are listed the input parameters of the data generation process and of the distribution function. These values can be modified to examine the accuracy of the Kaplan-Meier estimator for other Weibull distributions. The corresponding Weibull distribution is displayed.
# The value of period_of_observation should be at least equal to the value of deal_latest_period_to_start.

deal_latest_period_to_start <- 200
period_of_observation <- 200
number_of_deals <- 25
deal_minimum_duration <- 30
k_value <- 1.05 # update this to get a different k value for the weibull rate
lambda_value <- 250 # update this to get a different lambda / scale value for the weibull rate
# generic functions to assign the specific event rate functions
period_event_rate <- get_period_event_rate_weibull
period_event_cumulative_rate <- get_period_cumulative_event_rate_weibull
# the weibull distribution plot
x <- seq(0, period_of_observation, length=10*period_of_observation)
y <- dweibull(x,k_value,scale = lambda_value) # density
data <- as.data.frame(cbind(x,y))
plot <- ggplot(data, aes(x = data$x, y = data$y))
print(plot + geom_line() + xlab(paste("k = ", k_value, " ; lambda = ", lambda_value)) + ylab("Weibull density"))

# Below is the main section of the notebook.
# First the data generation function is called (modify the nbr parameter to get a different sample size).
# In the next 2 lines a Kaplan-Meier estimator model is generated.
# In the last line the results display function is called which allows to get a feeling of the accuracy of the obtained survival function compared to the theoretical survival function.

# generate data
data <- generate_deal(nbr = number_of_deals, end_period = deal_latest_period_to_start, horizon_period = period_of_observation, minimum_duration = deal_minimum_duration, density_function = period_event_rate)

# The below 2 lines of code are the only ones needed to construct the model
data_surv <- Surv(data$time,data$censor)
KM=survfit(data_surv~1) # Obtain the Kaplan-Meier estimator

# Kaplan Meier analysis
plot_km_vs_theoretical_value(KM = KM, horizon = period_of_observation, cumulative_density_function = period_event_cumulative_rate)
