#####################################################################
#
# matest.R
#
# copyright (c) 2001-2004, Hao Wu and Gary A. Churchill, The Jackson Lab.
# Written Apr, 2004
#
# Licensed under the GNU General Public License version 2 (June, 1991)
#
# Part of the R/maanova package
#
# This is the function to do F permutation test 
#
######################################################################

matest <- function(data, model, term, Contrast, n.perm=1000, nnodes=1,
                   test.type=c("ttest","ftest"),
                   shuffle.method=c("sample", "resid"),
                   MME.method=c("REML","noest","ML"),
                   test.method=c(1,0,1,1),
                   pval.pool=TRUE, verbose=TRUE)
{
  if (class(data) != "madata")
    stop("data is not an object of class madata.")
  if (class(model) != "mamodel")
    stop("model is not an object of class mamodel.")

  # get the methods
  shuffle.method <- match.arg(shuffle.method)
  MME.method <- match.arg(MME.method)
  
  # local variables
  nreps <- data$n.rep
  ngenes <- data$n.gene
  narrays <- data$n.array

  ########## initialize cluster ############
  if( (n.perm>1) & (nnodes>1) ) {
    if(!require(snow))
      stop("You have to install SNOW package to use cluster")
    # make cluster object
    cl <- makeMPIcluster(nnodes)
    # correct the possible correlation problem
    clusterApply(cl, runif(length(cl), max=1000000000), set.seed)
  }

  ################################################################
  # if any tested term is random, issue a warning and rebuild model
  ################################################################
  # take the parsed formula from model
  parsed.formula <- model$parsed.formula
  # identify the terms
  termidx <- locateTerm(parsed.formula$labels, term)

  if( is.null(termidx) )
    stop("The term(s) to be tested is not in formula.")
  
  if(any(parsed.formula$random[termidx] == 1)) {
    warning("Testing random terms. Random term will be tested as fixed terms.")
    # rebuild random formula and model object
    # random terms
    random.term <- parsed.formula$labels[parsed.formula$random==1]
    # random term to be tested
    random.term.test <- parsed.formula$labels[termidx]
    random.term.test <- random.term.test[parsed.formula$random[termidx]==1]
    # make the random term to be tested fixed,
    # remake the formula for random
    random.term <- setdiff(random.term, random.term.test)
    if(length(random.term) == 0) {
      random <- ~1
      stop("Cannot test the only random term in the model.")
    }
    else {
      random <- paste(random.term, collapse="+")
      random <- paste("~", random, sep="")
    }

   # remake covariate
    cov.term <- parsed.formula$labels[parsed.formula$covariate==1]
    if(length(cov.term) == 0)
      cov <- ~1
    else {
      cov <- paste(cov.term, collapse="+")
      cov <- paste("~", cov, sep="")
    }
    # remake model
    model <- makeModel(data, formula=model$formula, random=as.formula(random),
                       covariate=as.formula(cov))
  }

  ##########################################
  # for contrast matrix -
  # make one if not given,
  # check the validity if given
  ##########################################
  # for backward compatibility, if user provide Contrast matrix
  # this will be a T-test by default, unless user specify the test type
  if(missing(Contrast)) {# no Contrast matrix, make it
    Contrast <- makeContrast(model, term)
    nContrast <- 1
    # this must be a F-test
    if(missing(test.type))
      is.ftest <- TRUE
    else { # test.type is given
      test.type <- match.arg(test.type)
      if(test.type=="ttest")
        is.ftest <- FALSE
      else
        is.ftest <- TRUE
      if(test.type=="ttest") # cannot be T-test
        stop("You must specify a Contrast matrix for doing T-test")
    }
  }
  else { # given contrast matrix.
    # check if the contrast matrix is valid
    checkContrast(model, term, Contrast)
    # test type is T-test by default for backward compatibility
    test.type <- match.arg(test.type)
    if(test.type=="ftest") {
      is.ftest <- TRUE
      nContrast <- 1
    }
    else { # this is T-test, but will return F values 
      is.ftest <- FALSE
      # number of tests requested
      nContrast <- dim(Contrast)[1] # number of t-tests (comparisons)
    }
  }
  
  # do F test on the observed data
  if(verbose)
    cat("Doing F-test on observed data ...\n")
  # fit ANOVA model
  anovaobj <- fitmaanova(data, model, method=MME.method, verbose=FALSE)
  ftest.obs <- matest.engine(anovaobj, term, test.method=test.method, 
                             Contrast=Contrast, is.ftest=is.ftest, verbose=FALSE)
  # get the results
  mv <- ftest.obs$mv
  dfnu <- ftest.obs$dfnu; dfFtest <- ftest.obs$dfFtest
  partC <- ftest.obs$partC
  
  # initialize output object
  ftest <- NULL
  # general info in the output object
  ftest$model <- model
  ftest$term <- term
  ftest$dfde <- ftest.obs$dfFtest
  ftest$dfnu <- dfnu
  ftest$obsAnova <- anovaobj
  ftest$Contrast <- Contrast
  if(!is.ftest)
    class(ftest) <- c("matest", "ttest")
  else
    class(ftest) <- c("matest", "ftest")

  # calculate P values
  # F1
  if(test.method[1] == 1) {
    ftest$F1 <- NULL
    ftest$F1$Fobs <- ftest.obs$F1
    ftest$F1$Ptab <- 1 - pf(ftest$F1$Fobs, dfnu, dfFtest)
    if(n.perm > 1) {
      ftest$F1$Pvalperm <- array(0, c(ngenes, nContrast))
      ftest$F1$Pvalmax <- array(0, c(ngenes, nContrast))
    }
  }

  #F2
  if(test.method[2] == 1) {
    ftest$F2$Fobs <- ftest.obs$F2
    ftest$F2$Ptab <- 1 - pchisq(ftest$F2$Fobs*dfnu, dfnu)
    if(n.perm > 1) {
      ftest$F2$Pvalperm <- array(0, c(ngenes, nContrast))
      ftest$F2$Pvalmax <- array(0, c(ngenes, nContrast))
    }
  }
  
  #F3
  if(test.method[3] == 1) {
    ftest$F3$Fobs <- ftest.obs$F3;
    ftest$F3$Ptab <- 1 - pchisq(ftest$F3$Fobs*dfnu, dfnu)
    if(n.perm > 1) {
      ftest$F3$Pvalperm <- array(0, c(ngenes, nContrast))
      ftest$F3$Pvalmax <- array(0, c(ngenes, nContrast))
    }
  }
  
  #Fs
  if(test.method[4] == 1) {
    ftest$Fs$Fobs <- ftest.obs$Fs
    ftest$Fs$Ptab <- 1 - pf(ftest$Fs$Fobs, dfnu, dfFtest)
    if(n.perm > 1) {
      ftest$Fs$Pvalperm <- array(0, c(ngenes, nContrast))
      ftest$Fs$Pvalmax <- array(0, c(ngenes, nContrast))
    }
  }

  # return if no permutation test
  if(n.perm == 1) {
    warning("You are not doing permutation test. Only observed values are calculated.")
    return(ftest)
  }

  ########################################
  # start to do permutation test
  ########################################
  if(verbose)
    cat("Doing permutation. This may take a long time ... \n")

  # permutation - use MPI cluster if specified
  if(nnodes > 1) { # use MPI cluster
    # use cluster call to do permutation
    # calculate the number of permutation needed in each node
    nperm.cluster <- rep(floor((n.perm-1)/nnodes), nnodes)
    # maybe some leftovers
    leftover <- n.perm - 1 - sum(nperm.cluster)
    if(leftover > 0)
      nperm.cluster[1:leftover] <- nperm.cluster[1:leftover] + 1
    
    # load library on all nodes
    clusterEvalQ(cl, library(maanova))
    # use clusterApply to run permutation on all nodes
    # note that the only different parameter passed to function
    # is ftest.mixed.perm. So in ftest.mixed.perm I put nperm 
    # as the first argument so I can use clusterApply
    cat(paste("Doing permutation on", nnodes, "cluster nodes ... \n"))
    pstar.nodes <- clusterApply(cl, nperm.cluster, matest.perm, ftest, data,
                                model, term, Contrast, anovaobj$S2, mv,
                                is.ftest, partC, MME.method, test.method,
                                shuffle.method, pval.pool)
    # how to display permutation number?
    # after it's done, gather the results from nodes
    ffields <- c("F1","F2","F3","Fs")
    for(i in 1:nnodes) {
      if(nperm.cluster[i] > 0) {
        pstar <- pstar.nodes[[i]]
        for(itest in 1:4) {
          if(test.method[itest] == 1) {
            ftest[[ffields[itest]]]$Pvalperm <-
              ftest[[ffields[itest]]]$Pvalperm + pstar[[ffields[itest]]]$Pperm
            ftest[[ffields[itest]]]$Pvalmax <-
              ftest[[ffields[itest]]]$Pvalmax + pstar[[ffields[itest]]]$Pmax
          }
        }
      }
    }
    # clear cluster results to save some memory
    rm(pstar.nodes)
    # stop the cluster
    stopCluster(cl)
  }

  else { # no cluster, do it on single node
    pstar <- matest.perm(n.perm, ftest, data, model, term, Contrast, anovaobj$S2,
                         mv, is.ftest, partC, MME.method, test.method, shuffle.method,
                         pval.pool)
    # update the pvalues
    ffields <- c("F1","F2","F3","Fs")
    for(itest in 1:4) {
      if(test.method[itest] == 1) {
        ftest[[ffields[itest]]]$Pvalperm <-
          ftest[[ffields[itest]]]$Pvalperm + pstar[[ffields[itest]]]$Pperm
        ftest[[ffields[itest]]]$Pvalmax <-
          ftest[[ffields[itest]]]$Pvalmax + pstar[[ffields[itest]]]$Pmax
      }
    }
  }    
  # finish permutation loop
  
  # calculate the pvalues. Note that the current object contains the "counts"
  ffields <- c("F1","F2","F3","Fs")
  for(itest in 1:4) {
    if(test.method[itest] == 1) {
      # Pvalperm
      if(pval.pool)
        ftest[[ffields[itest]]]$Pvalperm <-
          ftest[[ffields[itest]]]$Pvalperm / (n.perm*ngenes)
      else
        ftest[[ffields[itest]]]$Pvalperm <-
          ftest[[ffields[itest]]]$Pvalperm / n.perm
      # for Pvalmax
      ftest[[ffields[itest]]]$Pvalmax <-
        ftest[[ffields[itest]]]$Pvalmax / n.perm
    }
  }

  # add some other info to the return object
  ftest$n.perm <- n.perm
  ftest$shuffle <- shuffle.method
  ftest$pval.pool <- pval.pool
  
  # return
  ftest
}
  
