#' Create a m_arms design
#'
#' This designer creates an \code{m_arms} arm design with equal assignment probabilities accross arms.
#'
#' @param N An integer. Sample size.
#' @param m_arms An integer. Number of treatment arms.
#' @param means A vector of size \code{m_arms}.  Average outcome in each treatment arm.
#' @param sds A double. Standard deviation for all treatment arms.
#' @param fixed A list. List of arguments to be fixed in design.
#' @return A function that returns a design.
#' @author \href{https://declaredesign.org/}{DeclareDesign Team}
#' @concept experiment 
#' @concept multi-trial
#' @import DeclareDesign stats utils fabricatr estimatr randomizr
#' @export
#' @examples
#' # To make a design using default arguments:
#'  \dontrun{
#' design <- multi_arm_designer()
#' get_estimates(design)
#' 
#' 
#' # A design with different mean and sd in each arm
#' design <- multi_arm_designer(means = c(0, 0.5, 2), sd =  c(1, 0.1, 0.5))
#' diagnose_design(design)
#' 
# A design with fixed sds and means. N is the sole modifiable argument. 
#' design <- multi_arm_designer(N = 80, m_arms = 4, means = 1:4, 
#'                              fixed = list(m_arms = 4, sds = rep(1, 4), 
#'                                           means = 1:4))
#' cat(get_design_code(design), sep = '\n')
#' diagnose_design(design)
#' 
#' If 'means' or 'sds' are defined in fixed list the same definition has to be  
#' given in the arguments list.
#' multi_arm_designer(N = 20, fixed = list(means = 1:3))
#' multi_arm_designer(N = 20, fixed = list(sds = 1:3))
#' }

multi_arm_designer <- function(
  N = 30, 
  m_arms = 3, 
  means = rep(0, m_arms),
  sds = rep(1, m_arms),
  fixed = NULL
){
  # Housekeeping
  if("means" %in% names(fixed)) if(!identical(means, fixed$means)) stop(paste("Conflicting definitions of 'means' in argument list (possibly the default)--(", paste(means, collapse = ","), ")--and in the fixed list--(", paste(fixed$means, collapse = ","), "). If 'means' is defined in fixed list the same definition has to be  given in the arguments list."))
  if("sds" %in% names(fixed)) if(!identical(sds, fixed$sds)) stop(paste("Conflicting definitions of 'sds' in argument list (possibly the default)--(", paste(sds, collapse = ","), ")--and in the fixed list--(", paste(fixed$sds, collapse = ","), "). If 'sds' is defined in fixed list the same definition has to be  given in the arguments list."))
  if(length(means) != m_arms || length(sds) != m_arms) stop("`means' and `sds` arguments must be the of length m_arms .")
  if(m_arms <= 1 || round(m_arms)!=m_arms) stop("`m_arms' should be an integer greater than one.")
  if(any(sds<=0)) stop("`sds' should be positive.")
  
  # Create list for substitution
  conds = paste0("T", 1:m_arms)
  
  U <- paste0(" population <- declare_population(N = N, ",  
              paste0("u_", 1:m_arms, " = rnorm(n = N, sd = ",  sds, ")", collapse = ", "), ")")
  
  
  f_Y = formula(paste0(
    "Y ~ ", paste0("(", means, " + u_", 1:m_arms, ")*( Z == 'T", 1:m_arms, "')", collapse = " + "))
  )
  
  
  Q <- paste0(" estimand <- declare_estimand('(Intercept)' = mean(Y_Z_T1), ",
              paste0("T_", 2:m_arms, " = mean(Y_Z_T", 2:m_arms, " - Y_Z_T1)", collapse = ", "), ", term = TRUE)")
  
  T_m <- paste0("get_T <- declare_step(", paste0(
    "T_",  2:m_arms, " =  as.numeric(Z == 'T", 2:m_arms, "')", collapse = ", "), ", handler = fabricate)")
  
  f_YT <- formula(paste0("Y ~ ", paste0("T_", 2:m_arms, collapse = " + ") ))
  
  fixes <- list(conds = conds, f_Y = f_Y, U = U, Q = Q, T_m = T_m,  f_YT =   f_YT )
  
  fixes <- c(fixes, fixed)
  
  # Design code with arguments in list substituted
  design_code <-  substitute({
    
    "# M: Model"
    U
    potential_outcomes <- declare_potential_outcomes(formula = f_Y, conditions = conds)
    
    "# I: Inquiry"
    Q
    
    "# D: Data"
    assignment <- declare_assignment(num_arms = m_arms)
    T_m
    
    reveal <- declare_reveal()
    
    "# A: Answer" 
    estimator <- declare_estimator(formula =  f_YT , model = lm_robust, term = TRUE)
    
    
    "# Design"
    multi_arm_design <- population + potential_outcomes + assignment + get_T + reveal + estimand +  estimator
    
  }, fixes)
  
  # Run the design code and create the design
  design_code <- clean_code(design_code) 
  
  eval(parse(text = (design_code)))
  
  #  Add  code plus argments as attributes
  attr( multi_arm_design, "code") <- 
    paste0(c(return_args(match.call.defaults(), fixes), design_code))
  
  # Return design
  return( multi_arm_design)
}

attr( multi_arm_designer, "shiny_arguments") <- list(N = c(10, 20, 50)) 

attr( multi_arm_designer, "tips") <-
  list(
    N = "Sample Size"
  )

