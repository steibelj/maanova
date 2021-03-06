\author{Hao Wu}

\name{riplot}
\alias{riplot}

\title{Ratio intensity plot for 2-dye Microarray experiment}

\description{
  This function only works for 2-dye array at this time. It will
  plot the log-ratio (log2(R/G)) versus log-intensity (log2(R*G)/2)
  figure for Micro Array experiment. Ideal RI plot will be points
  scattered around the y=0 horizontal line.

  This function works for \code{madata}. This function and 
  \code{\link[maanova]{arrayview}} assume the data is
  on log2 based scale. So if your rawdata is not pre-transformed, you should
  not do riplot on the raw data.
}

\usage{
riplot(object, title, xlab, ylab, array, color = "blue",highlight.flag = TRUE, 
    flag.color = "Red", idx.highlight, highlight.color = "Green", 
    rep.connect = FALSE, onScreen=TRUE) 
}

\note{
  This function will plot one figure for each array. So if you have many
  arrays, there will be many figures generated.
}

\arguments{
  \item{object}{An object of class \code{madata}.}
  \item{title}{The title for figures. The default figure title is "RI
    plot for array number X". If the user wants to provide titles, be
    sure to provide a string array with the same number of elements as
    the number of arrays.}
  \item{xlab}{The xlab for figures. The default figure xlab is 
    "expression(log[2](R*G))". One xlab would be used for all plot, 
     thus unlike title, user (if one wants) need to provide only one name.}
  \item{ylab}{The ylab for figures. The default figure ylab is 
    "expression(log[2](R/G))". One ylab would be used for all plot, 
     thus unlike title, user (if one wants) need to provide only one name.}
  \item{array}{A list of arrays numbers for which you want to draw an RI
    plot.} 
  \item{color}{The color for the points in scatter plot. Default is blue.}
  \item{highlight.flag}{A logical parameter to indicate whether to
    highlight the bad spots or not.}
  \item{flag.color}{The color for bad spots, default is red.}
  \item{idx.highlight}{A vector for highlighted spots other than bad
    spots.}
  \item{highlight.color}{The color for highlighted spots. Default is green.}
  \item{rep.connect}{A logical value to represent whether to connect the
    dots between the replicates or not.}
  \item{onScreen}{A logical value to represent whether to display the
    plots on screen or not. If TRUE, x11() (in Unix/Windows) or
    macintosh() (in Mac) will be called inside the function. Otherwise,
    it will plot the figure on the current device. Default is TRUE.}
}

\examples{
\dontrun{
data(kidney)
# riplot raw data on screen
riplot(kidney.raw)
graphics.off()
# riplot raw data array 1 and 3 and output to postscript file
postscript(file="kidneyRIplot.ps")
riplot(kidney.raw, array=c(1,3), onScreen=FALSE)
}}

\keyword{hplot}

