% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mtrx.R
\name{process_batch}
\alias{process_batch}
\title{Function to process batch from shared objects for GPU.}
\usage{
process_batch(count_matrix, first_index, second_index, batch_size, metric)
}
\arguments{
\item{count_matrix}{Count Matrix.}

\item{first_index}{index.}

\item{second_index}{index.}

\item{batch_size}{int.}

\item{metric}{string for metric.}
}
\value{
A list of correlation matrix, batch_a size and batch_b size.
}
\description{
Function to process batch from shared objects for GPU.
}
