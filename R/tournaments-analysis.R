library(ggplot2)
library(reshape2)
library(plyr)


loadData <- function(f='data.tsv') {
  read.csv(f,sep='\t',header=TRUE)
}

prepareData <- function(d) {
  d[,'price'] <- paste(d[,'currency'],d[,'buyInMinusRake'],d[,'rake'])
  d
  #list(data=d,prizeStruct=extractPrizeStruct(d))
}

extractPrizeStruct <- function(d) {
  dlply(d, c('price'), function(sub) {
    valuesNbPlayers <- unique(sub[,'nbPlayers'])
    if (length(valuesNbPlayers)==1) {
      
    } else {
      
    }
  })  
  
}