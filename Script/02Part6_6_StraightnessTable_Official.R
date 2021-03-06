################ Barrier Behavior Analysis (BaBA): straightness table  ############
# Time: 11302019
# Description: This is to generate a staightness table with straightness calculated with a range of trajectory duration
# the table is to be used for classifying back-n-forth, average movement, and trace. 

## Input ##
# Fence shp, movement points (with the same time intervals since the behavior type assumption 
# 

## output ##
## straightness table 

## note ##
# this loop also takes forever. Mainly because of the large numbers of repeatitions. 
# Maybe apply parellel looping on it.

###############################################################################
#############################################################################################
# ----- set up -------
library(dplyr)
# spatial analysis
library(rgdal)
library(rgeos)
library(sp)
library(raster)
#trajectory analysis
library(adehabitatLT)
# for parallel multi-core calculation 
library(foreach)
library(doParallel)
library(doSNOW)

setwd("C:\\Users\\wenjing.xu\\Google Drive\\RESEARCH\\Pronghorn\\Analysis\\FenceBehavior_Official")

#############################
#########Parameters##########
#############################
target.crs <- "+proj=utm +zone=12 +datum=WGS84 +units=m +no_defs +ellps=WGS84 +towgs84=0,0,0"
interval <- 2 #define time interval (in hours) of the movement data

## parameters after this should be determined by local management requirements and characteristics of the target species.
# based on the data time interval and animal ecology, maximum encounter duration that you'd call it a "bounce" or "Quick Cross".
# aka, what is quick for you?
b.hours <- 4
b <- b.hours/interval
# minimum encounter duration in the burst that you'd call it a trap. Must be divisible by interval.
# aka, what is too long for you?
p.hours <- 36
p <- p.hours/interval

#############################
######### Funciton ##########
#############################
# calculating straightness. Input a dataframe with Easting and Northing. 
strtns <- function(mov.seg) {
  pts <- cbind(mov.seg$Easting, mov.seg$Northing)
  pts.sp <- SpatialPointsDataFrame(pts, mov.seg, proj4string = CRS(target.crs))
  traj <- as.ltraj(xy =  pts, date = mov.seg$date, id = mov.seg$Location.ID)
  #moving distance from first pt to last pt in the burst
  traj.dist <- sqrt(
    as.numeric((traj[[1]]$x[1]-traj[[1]]$x[nrow(traj[[1]])]))*  as.numeric((traj[[1]]$x[1]-traj[[1]]$x[nrow(traj[[1]])])) +
      as.numeric((traj[[1]]$y[1]-traj[[1]]$y[nrow(traj[[1]])]))*as.numeric((traj[[1]]$y[1]-traj[[1]]$y[nrow(traj[[1]])])) 
  )
  #sum of all step lengths
  traj.lgth <- sum(traj[[1]]$dist, na.rm = TRUE)
  #straightness ranges from 0 to 1. More close to 0 more sinuous it is.
  straightness <- traj.dist/traj.lgth
  return(straightness)
}

#############################
######### Set-up ###########
#############################
#read in movement data
#ideally, the movement data should not have missing point. This trial file does have missing points.
movement.df.all <- read.csv("Int2_Comp_Raw_All.csv") 
movement.df.all$date <- as.POSIXct(strptime(as.character(movement.df.all$date),"%m/%d/%Y %H:%M")) #change the format based on the data
movement.df.all <- movement.df.all[(!is.na(movement.df.all$date))&(!is.na(movement.df.all$Easting)),]

#############################
######### Analysis ##########
#############################
animal.stn.df <- data.frame(AnimalID = integer(), window.size = numeric(), Date = character(), Straightness = numeric())

for (i in unique(movement.df.all$Location.ID)) {
  movement.df.i <- movement.df.all[movement.df.all$Location.ID == i,]
  # The range is b~p
  # e.g. interval = 2, b = 2, p = 36. Calculating moving window with size 3 - 24 (including 24)
  for (ii in (b+1):min(p, nrow(movement.df.i))) { # ii is the window size
    straightness.ii <- vector()
    date.ii <- character()
    for (iii in seq(1, (nrow(movement.df.i)-ii), by = 2)) {  # can change "by" for different sampling rate to calculate strightness
      mov.seg.iii <- movement.df.i[iii:(iii+ii),]
      date.iii <- as.character(strftime(mov.seg.iii$date[1], "%Y-%m-%d %H:%M:%S"))# mark the starting point of the calculated straightness
      straightness.iii <- strtns(mov.seg.iii)
      straightness.ii <- c(straightness.ii, straightness.iii)
      date.ii <- c(date.ii, date.iii)
    }
    n <- length(straightness.ii)
    rows.i <- data.frame(AnimalID = rep(i, n), window.size = rep(ii, n), Date = date.ii, Straightness = straightness.ii)
    animal.stn.df <- rbind(animal.stn.df, rows.i)
  }
}
write.csv(animal.stn.df, paste0(getwd(), "I2_all_Straightness.csv"))
