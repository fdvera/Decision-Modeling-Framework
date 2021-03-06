#-------------------------------------------------------------------#
#### Generate model outputs for calibration from a parameter set ####
#-------------------------------------------------------------------#
f.calibration_out <- function(v.params.calib, l.params.all){ # User defined
  ### Definition:
  ##   Computes model outputs to be used for calibration routines
  ### Arguments:  
  ##   v.params.calib: vector of parameters that need to be calibrated
  ##   l.params.all: List with all parameters of the decision model
  ### Returns:
  ##   l.out: List with Survival (Surv), Prevalence of Sick and Sicker (Prev), 
  ##          and proportion of Sicker (PropSicker) out of all sick 
  ##          (Sick+Sicker) individuals
  ##
  # Substitute values of calibrated parameters in base-case with 
  # calibrated values
  l.params.all <- f.update_param_list(l.params.all = l.params.all, params.updated = v.params.calib)
  
  # Run model with updated calibrated parameters
  l.out.stm <- f.decision_model(l.params.all = l.params.all)
  
  ####### Epidemiological Output ###########################################
  #### Overall Survival (OS) ####
  v.os <- 1 - l.out.stm$m.M[, "D"]
  
  #### Disease prevalence #####
  v.prev <- rowSums(l.out.stm$m.M[, c("S1", "S2")])/v.os
  
  #### Proportion of sick in S1 state #####
  v.prop.S2 <- l.out.stm$m.M[, "S2"] / rowSums(l.out.stm$m.M[, c("S1", "S2")])
  
  ####### Return Output ###########################################
  l.out <- list(Surv = v.os[c(11, 21, 31)],
              Prev = v.prev[c(11, 21, 31)],
              PropSicker = v.prop.S2[c(11, 21, 31)])
  return(l.out)
}

#-------------------------------------------------------------------#
#### Likelihood and log-likelihood functions for a parameter set ####
#-------------------------------------------------------------------#
f.log_lik <- function(v.params){ # User defined
  ### Definition:
  ##  Computes a log-likelihood value for one (or multiple) parameter set(s)
  ##  using the simulation model and likelihood functions
  ### Arguments:  
  ##   v.params: Vector (or matrix) of model parameters 
  ### Returns:
  ##   v.llik.overall: Scalar (or vector) with log-likelihood values
  ##
  if(is.null(dim(v.params))) { # If vector, change to matrix
    v.params <- t(v.params) 
  }
  
  n.samp <- nrow(v.params)
  v.llik <- matrix(0, nrow = n.samp, ncol = n.target) 
  colnames(v.llik) <- c("Surv", "Prev", "PropSick")
  v.llik.overall <- numeric(n.samp)
  for(j in 1:n.samp) { # j=1
    jj <- tryCatch( { 
    ###   Run model for parametr set "v.params" ###
    l.model.res <- f.calibration_out(v.params.calib = v.params[j, ], 
                                     l.params.all = l.params.all)
  
    ###  Calculate log-likelihood of model outputs to targets  ###
    ## TARGET 1: Survival ("Surv")
    ## Normal log-likelihood  
    v.llik[j, "Surv"] <- sum(dnorm(x = SickSicker.targets$Surv$value,
                                   mean = l.model.res$Surv,
                                   sd = SickSicker.targets$Surv$se,
                                   log = T))
    
    ## TARGET 2: Prevalence ("Prev")
    ## Normal log-likelihood
    v.llik[j, "Prev"] <- sum(dnorm(x = SickSicker.targets$Prev$value,
                                   mean = l.model.res$Prev,
                                   sd = SickSicker.targets$Prev$se,
                                   log = T))
    
    ## TARGET 3: Proportion Sick+Sicker who are Sick ("PropSick")
    ## Normal log-likelihood
    v.llik[j, "PropSick"] <- sum(dnorm(x = SickSicker.targets$PropSick$value,
                                       mean = l.model.res$PropSick,
                                       sd = SickSicker.targets$PropSick$se,
                                       log = T))
    
    ## OVERALL
    ## can give different targets different weights (user must change this)
    v.weights <- rep(1, n.target)
    ## weighted sum
    v.llik.overall[j] <- v.llik[j, ] %*% v.weights
    }, error = function(e) NA) 
    if(is.na(jj)) { v.llik.overall <- -Inf }
  } ## End loop over sampled parameter sets
  
  ## return GOF
  return(v.llik.overall)
}
# test if it works
# f.log_lik(v.params = sample.prior(n.samp = 2))

likelihood <- function(v.params){ 
  ### Definition:
  ##  Computes a likelihood value for one (or multiple) parameter set(s)
  ### Arguments:  
  ##   v.params: Vector (or matrix) of model parameters 
  ### Returns:
  ##   v.like: Scalar (or vector) with likelihood values
  ##
  v.like <- exp(f.log_lik(v.params)) 
  
  return(v.like)
}
# test if it works
# likelihood(v.params = sample.prior(2))

#----------------------------------------------------------------------------#
#### Function to sample from prior distributions of calibrated parameters ####
#----------------------------------------------------------------------------#
sample.prior <- function(n.samp){
  ### Definition:
  ##  Generates a sample of parameter sets from their prior distribution
  ### Arguments:  
  ##   n.samp: Number of samples
  ### Returns:
  ##   m.param.samp: Matrix with a sample of parameter sets
  ##
  m.lhs.unit   <- randomLHS(n = n.samp, k = n.param)
  m.param.samp <- matrix(nrow = n.samp, ncol = n.param)
  colnames(m.param.samp) <- v.param.names
  for (i in 1:n.param){
    m.param.samp[, i] <- qunif(m.lhs.unit[,i],
                               min = v.lb[i],
                               max = v.ub[i])
    # ALTERNATIVE prior using beta (or other) distributions
    # m.param.samp[, i] <- qbeta(m.lhs.unit[,i],
    #                            min = 1,
    #                            max = 1)
  }
  return(m.param.samp)
}
# test if it works
# pairs.panels(sample.prior(1000))

#--------------------------------------------------------------------------#
#### Functions to evaluate log-prior and prior of calibrated parameters ####
#--------------------------------------------------------------------------#
f.log_prior <- function(v.params){
  ### Definition:
  ##  Computes a log-prior value for one (or multiple) parameter set(s) based on
  ##  their prior distributions
  ### Arguments:  
  ##   v.params: Vector (or matrix) of model parameters 
  ### Returns:
  ##   lprior: Scalar (or vector) with log-prior values
  ##
  if(is.null(dim(v.params))) { # If vector, change to matrix
    v.params <- t(v.params) 
  }
  n.samp <- nrow(v.params)
  colnames(v.params) <- v.param.names
  lprior <- rep(0, n.samp)
  for (i in 1:n.param){
    lprior <- lprior + dunif(v.params[, i],
                             min = v.lb[i],
                             max = v.ub[i], 
                             log = T)
    # ALTERNATIVE prior using beta distributions
    # lprior <- lprior + dbeta(v.params[, i],
    #                          min = 1,
    #                          max = 1, 
    #                          log = T)
  }
  return(lprior)
}
# test if it works
# f.log_prior(v.params = sample.prior(5))

prior <- function(v.params) { 
  ### Definition:
  ##  Computes a prior value for one (or multiple) parameter set(s)
  ### Arguments:  
  ##   v.params: Vector (or matrix) of model parameters 
  ### Returns:
  ##   v.prior: Scalar (or vector) with prior values
  ##
  v.prior <- exp(f.log_prior(v.params)) 
  
  return(v.prior)
}
# test if it works
# prior(v.params = sample.prior(5))

#----------------------------------------------------------------------------------#
#### Functions to evaluate log-posterior and posterior of calibrated parameters ####
#----------------------------------------------------------------------------------#
f.log_post <- function(v.params) { 
  ### Definition:
  ##  Computes a log-posterior value for one (or multiple) parameter set(s) based on
  ##  the simulation model, likelihood functions and prior distributions
  ### Arguments:  
  ##   v.params: Vector (or matrix) of model parameters 
  ### Returns:
  ##   v.lpost: Scalar (or vector) with log-posterior values
  ##
  v.lpost <- f.log_prior(v.params) + f.log_lik(v.params)
 
   return(v.lpost) 
}
# test if it works
# f.log_post(v.params = sample.prior(5))
