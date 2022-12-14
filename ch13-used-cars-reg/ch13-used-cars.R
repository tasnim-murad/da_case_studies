################################################################################################
# Prepared for the textbook:
# Data Analysis for Business, Economics, and Policy
# by Gabor BEKES and  Gabor KEZDI 
# Cambridge University Press 2021
# 
# License: Free to share, modify and use for educational purposes. Not to be used for business purposes.
#
###############################################################################################x

# CHAPTER 13
# CH11 Used cars
# version 0.9.2 2021-01-06


# ------------------------------------------------------------------------------------------------------
#### SET UP
# It is advised to start a new session for every case study
# CLEAR MEMORY
rm(list=ls())


# DIRECTORY SETTING


# import libraries
library(tidyverse)
library(modelsummary)
library(fixest)
library(lmtest)
library(sandwich)
#library(haven)
library(stargazer)
library(caret)
library(grid)


# set working directory
# option A: open material as project
# option B: set working directory for da_case_studies
#           example: setwd("C:/Users/bekes.gabor/Documents/github/da_case_studies/")

# set data dir, load theme and functions
source("ch00-tech-prep/theme_bg.R")
source("ch00-tech-prep/da_helper_functions.R")

# data used
source("set-data-directory.R") #data_dir must be first defined #
data_in <- paste(data_dir,"used-cars","clean/", sep = "/")

use_case_dir <- "ch13-used-cars-reg/"
data_out <- use_case_dir
output <- paste0(use_case_dir,"output/")
create_output_if_doesnt_exist(output)


################################################################################

# DATA IMPORT
data <- read.csv(paste0(data_in,"used-cars_2cities_prep.csv"), stringsAsFactors = TRUE)
# From OSF:
#data <- read.csv( 'https://osf.io/7gvz9/download', stringsAsFactors = TRUE)

# check the datatable
glimpse( data )


# SAMPLE DESIGN

# manage missing
data$fuel <- fct_explicit_na(data$fuel, na_level = "Missing")
data$condition <- fct_explicit_na(data$condition, na_level = "Missing")
data$drive <- fct_explicit_na(data$drive, na_level = "Missing")
data$cylinders <- fct_explicit_na(data$cylinders, na_level = "Missing")
data$transmission <- fct_explicit_na(data$transmission, na_level = "Missing")
data$type <- fct_explicit_na(data$type, na_level = "Missing")


# drop hybrid models then drop column
data <- data %>% filter(Hybrid ==0) %>% dplyr::select(-Hybrid)

# check frequency by fuel type
data %>%
  group_by(fuel) %>%
  dplyr::summarize(frequency=n()) %>%
  mutate(percent = frequency / sum(frequency)*100,
         cumulative_percent = cumsum(frequency)/sum(frequency)*100)

# keep gas-fuelled vehicles
data <- data %>% filter(fuel=="gas")



# check frequency by vehicle condition
data %>%
  group_by(condition) %>%
  dplyr::summarize(frequency=n()) %>%
  mutate(percent = frequency / sum(frequency)*100,
         cumulative_percent = cumsum(frequency)/sum(frequency)*100)

# drop vehicles in fair and new condition, trucks
data <- data %>% filter(!condition %in% c("new", "fair"))

# drop unrealistic values for price and odometer reading
data <- data %>% filter(price %in% c(500:25000), odometer <=100)

# drop if price is smaller than 1000 and condition is like new or age is less than 8
data <- data %>% filter(!(price < 1000 & (condition == "like new"|age < 8)))

# check frequency by transmission
data %>%
  group_by(transmission) %>%
  dplyr::summarize(frequency=n()) %>%
  mutate(percent = frequency / sum(frequency)*100,
         cumulative_percent = cumsum(frequency)/sum(frequency)*100)

# remove obs w manual transmission,
data <- data %>% filter(!(transmission == "manual"))

data %>%
  group_by(type) %>%
  dplyr::summarize(frequency=n()) %>%
  mutate(percent = frequency / sum(frequency)*100,
         cumulative_percent = cumsum(frequency)/sum(frequency)*100)
# drop if truck
data <- data %>% filter(!(type == "truck"))
 
# drop pricestr
data <- data %>% dplyr::select(-pricestr)

################################################################################

# DATA GENERATION & DESCRIPTIVES

# condition
data <- data %>%
  mutate(cond_excellent = ifelse(condition == "excellent", 1,0),
         cond_good = ifelse(condition == "good", 1,0),
         cond_likenew = ifelse(condition == "like new", 1,0))

# cylinders
data <- data %>%
  mutate(cylind6 = ifelse(cylinders=="6 cylinders",1,0))

datasummary( cylinders + as.factor( cylind6 ) ~ N + Percent() , data = data )


# age: quadratic, cubic
data <- data %>%
  mutate(agesq = age^2,
         agecu = age^3)

# odometer: quadratic
data <- data %>%
  mutate(odometersq = odometer^2)

# save workfile
write.csv(data, paste0(data_out, "usedcars_work.csv"), row.names = F)

###############################################################################

data <- read.csv(paste0(data_out, "usedcars_work.csv"), stringsAsFactors = FALSE)

# Frequency tables

# area 
datasummary( area * price ~ N + Mean , data = data )

# focus only on Chicago
data <- data %>%
  filter(area=="chicago")

# condition
datasummary( condition * price ~ N + Mean , data = data )

# drive
datasummary( drive * price ~ N + Mean , data = data )

# dealer
datasummary( as.factor( dealer ) * price ~ N + Mean , data = data )

# data summary
datasummary( age + odometer + LE + XLE + SE + cond_likenew + cond_excellent + cond_good + cylind6 + age ~
               Mean + Median + Min + Max + P25 + P75 + N , data = data )

# Histograms not in textbook
# price
F13_h_price_R <- ggplot(data=data, aes(x=price)) +
  geom_histogram(aes(y = (..count..)/sum(..count..)), binwidth = 1000, boundary=0,
                 color = color.outline, fill = color[1], size = 0.25, alpha = 0.8,  show.legend=F, na.rm=TRUE) +
  coord_cartesian(xlim = c(0, 20000)) +
  labs(x = "Price (US dollars)",y = "Percent")+
  theme_bg() +
  expand_limits(x = 0.01, y = 0.01) +
  scale_y_continuous(expand = c(0.01,0.01),labels = scales::percent_format(accuracy = 1)) +
  scale_x_continuous(expand = c(0.01,0.01),breaks = seq(0,20000, 2500))
F13_h_price_R


# lnprice 
F13_h_lnprice_R<- ggplot(data=data, aes(x=lnprice)) +
  geom_histogram(aes(y = (..count..)/sum(..count..)), binwidth = 0.2, boundary=0,
                 color = color.outline, fill = color[1], size = 0.25, alpha = 0.8,  show.legend=F, na.rm=TRUE) +
  coord_cartesian(xlim = c(6, 10)) +
  labs(x = "ln(Price, US dollars)",y = "Percent")+
  expand_limits(x = 0.01, y = 0.01) +
  scale_y_continuous(expand = c(0.01,0.01),labels = scales::percent_format(accuracy = 0.1)) +
  scale_x_continuous(expand = c(0.01,0.01),breaks = seq(6,10, 1)) +
  theme_bg() 
F13_h_lnprice_R




###############################################################################
# REGRESSION ANALYSIS


# lowess
Ch13_p_age_lowess_R <- ggplot(data = data, aes(x=age, y=price)) +
  geom_point( color = color[1], size = 1,  shape = 16, alpha = 0.8, show.legend=F, na.rm = TRUE) + 
  geom_smooth(method="loess", se=F, colour=color[4], size=1, span=0.9) +
  labs(x = "Age (years)",y = "Price (US dollars)") +
  theme_bg() +
  expand_limits(x = 0.01, y = 0.01) +
  scale_y_continuous(expand = c(0.01,0.01),limits = c(0,20000), breaks = seq(0,20000, 5000)) +
  scale_x_continuous(expand = c(0.01,0.01),limits = c(0,30), breaks = seq(0,30, 5))
Ch13_p_age_lowess_R


###################################
# Linear regressions

# Model 1: Linear regression on age
model1 <- as.formula(price ~ age + agesq)
# Models 2-5: Multiple linear regressions
# note: condition - missing will be baseline for regs

model2 <- as.formula(price ~ age + agesq + odometer)
model3 <- as.formula(price ~ age + agesq + odometer + odometersq + LE + cond_excellent + cond_good + dealer)
model4 <- as.formula(price ~ age + agesq + odometer + odometersq + LE + XLE + SE + cond_likenew +
                       cond_excellent + cond_good + cylind6 + dealer)

model5 <- as.formula(price ~ age + agesq + agecu + odometer + odometersq + LE*age + XLE*age + SE*age +
                       cond_likenew*age + cond_excellent*age + cond_good*age + cylind6*age + odometer*age + dealer*age)


# Running simple OLS
reg1 <- feols(model1, data=data, vcov = 'hetero')
reg2 <- feols(model2, data=data, vcov = 'hetero')
reg3 <- feols(model3, data=data, vcov = 'hetero')
reg4 <- feols(model4, data=data, vcov = 'hetero')
reg5 <- feols(model5, data=data, vcov = 'hetero')

# evaluation of the models
fitstat_register("k", function(x){length( x$coefficients ) - 1}, "No. Variables")
etable( reg1 , reg2 , reg3 , reg4 , reg5 , fitstat = c('aic','bic','rmse','r2','n','k') )

##
# EXTRA: for writing out with stargazer: use lm instead
reg1 <- lm(model1, data=data)
reg2 <- lm(model2, data=data)
reg3 <- lm(model3, data=data)
reg4 <- lm(model4, data=data)
reg5 <- lm(model5, data=data)
# evaluation of the models
models <- c("reg1", "reg2","reg3", "reg4", "reg5")
AIC <- c()
BIC <- c()
RMSE <- c()
RSquared <- c()
regr <- c()
k <- c()
# Get for all models
for ( i in 1:length(models)){
  AIC[i] <- AIC(get(models[i]))
  BIC[i] <- BIC(get(models[i]))
  RMSE[i] <- RMSE(predict(get(models[i])), get(models[i])$model$price)
  RSquared[i] <-summary(get(models[i]))$r.squared
  regr[[i]] <- coeftest(get(models[i]), vcov = sandwich)
  k[i] <- get(models[i])$rank -1
}

# Model 1
#stargazer(regr[[1]],  out=paste(output,"Ch13_reg_age_R.tex",sep=""), digits=2, float = F, no.space = T)

############################################################
# Linear regression evaluation


# Lowess vs. quadratic (reg1) regression
Ch13_p_age_quad_vs_lowess_R <- ggplot(data = data, aes(x=age)) +
  geom_smooth(aes(y=price, colour=color[1]), method="loess", se=F, size=1) +
  geom_line(aes(y=predict(reg1), colour=color[2]), size=1,lty=2) +
  labs(x = "Age (years)",y = "Price (US dollars)") +
  scale_color_manual(name="", values=c(color[1],color[2]),labels=c("Lowess in age","Quadratic in age")) +
  theme_bg() +
  scale_x_continuous(limits = c(0,30), breaks = seq(0,30, 5)) +
  scale_y_continuous(limits = c(0,20000), breaks = seq(0,20000, 5000)) +
  theme(legend.position = c(0.7,0.7),
        legend.direction = "horizontal",
        legend.background = element_blank(),
        legend.box.background = element_rect(color = "white"))

Ch13_p_age_quad_vs_lowess_R



# All models
eval <- data.frame(models, k, RSquared, RMSE, BIC)
eval <- eval %>%
  mutate(models = paste0("(",gsub("reg","",models),")")) %>%
  rename(Model = models, "R-squared" = RSquared, "Training RMSE" = RMSE, "N predictors" = k)
stargazer(eval, summary = F, out=paste(output,"ch13-table-4-bicrmse.tex",sep=""), digits=2, float = F, no.space = T)
# old name: Ch13_bicrmse_R.tex
# models 1-4 only, 5 too large

# TODO 
# use stargazer_r to get robust se
# could be made nicer, also not producing it here
stargazer_r(list(reg1, reg2, reg3, reg4 ), float=F, se = 'robust', digits=2, dep.var.caption = "Dep. var: price", keep.stat = c("rsq","n"),
            out=paste0(output,"ch13-table-2-multireg1.tex",sep=""), no.space = T)
stargazer(reg1, reg2, reg3, reg4 , align = T,   digits=2, dep.var.caption = "Dep. var: price", keep.stat = c("rsq","n"),
            type="text", title = "Cars - regression", out=paste0(output,"ch13-table-2-multireg1.txt",sep=""), no.space = T)
# old name: Ch13_multireg1_R.tex

#################################################################
# Cross-validation

# set number of folds
k <- 4

set.seed(13505)
cv1 <- train(model1, data, method = "lm", trControl = trainControl(method = "cv", number = k))
set.seed(13505)
cv2 <- train(model2, data, method = "lm", trControl = trainControl(method = "cv", number = k))
set.seed(13505)
cv3 <- train(model3, data, method = "lm", trControl = trainControl(method = "cv", number = k), na.action = "na.omit")
set.seed(13505)
cv4 <- train(model4, data, method = "lm", trControl = trainControl(method = "cv", number = k), na.action = "na.omit")
set.seed(13505)
cv5 <- train(model5, data, method = "lm", trControl = trainControl(method = "cv", number = k), na.action = "na.omit")

# calculate average rmse
cv <- c("cv1", "cv2", "cv3", "cv4", "cv5")
rmse_cv <- c()

for(i in 1:length(cv)){
  rmse_cv[i] <- sqrt((get(cv[i])$resample[[1]][1]^2 +
                       get(cv[i])$resample[[1]][2]^2 +
                       get(cv[i])$resample[[1]][3]^2 +
                       get(cv[i])$resample[[1]][4]^2)/4)
}


# summarize results
cv_mat <- data.frame(rbind(cv1$resample[4], "Average"),
           rbind(cv1$resample[1], rmse_cv[1]),
           rbind(cv2$resample[1], rmse_cv[2]),
           rbind(cv3$resample[1], rmse_cv[3]),
           rbind(cv4$resample[1], rmse_cv[4]),
           rbind(cv5$resample[1], rmse_cv[5])
           )

colnames(cv_mat)<-c("Resample","Model1", "Model2", "Model3", "Model4", "Model5")
cv_mat

stargazer(cv_mat, summary = F, digits=0, float=F, out=paste(output,"ch13-table-5-cvmat.tex",sep=""))
stargazer(cv_mat, summary = F, digits=0, float=F, type="text",  out=paste(output,"ch13-table-5-cvmat.txt",sep=""))
# old name: Ch13_cvmat_R

# NB THIS IS SLIGHTLY DIFFERENT TO ONE IN TEXTBOOK (DIFFERENT SEED)

###############################################################################
# Prediction

data <- data %>% dplyr::select(age, agesq, odometer, odometersq, SE, LE, XLE, cond_likenew,
                        cond_excellent, cond_good, dealer,price, cylind6)

# Add new observation
new <- tibble(age=10, agesq=10^2,odometer=12,odometersq=12^2,SE=0,XLE=0, LE=1, 
            cond_likenew=0,cond_excellent=1,cond_good=0, 
            dealer=0, cylind6=0, price=NA)


# Predict price with only 2 predictors (Model1)
pred1 <- feols(model1, data=data, vcov = 'hetero')
# Standard errors of residuals
p1 <- predict(pred1, data)
resid_p1 <- p1-data$price
summary(resid_p1)
# predict value for newly added obs
pred1_new <- predict(pred1, newdata = new ,se.fit = TRUE, interval = "prediction")
p1<- pred1_new$fit

# Predict price with all predictors (Model3)
pred3 <- feols(model3, data=data,vcov = 'hetero')
# Standard errors of residuals
p3 <- predict(pred3, data)
resid_p3 <- p3-data$price
summary(resid_p3)
# predict value for newly added obs
pred3_new <- predict(pred3, newdata = new, se.fit = TRUE, interval = "prediction")
p3<- pred3_new$fit
pred3_new 

#get model rmse
data$p3a <- predict( pred3, data)
log_na <- is.na( data$p3a )
rmse3 <- RMSE(data$p3a[!log_na],data$price[!log_na])
rmse3

# Result summary
sum1 <- cbind(t(pred1_new[,c(1,3,4)]), t(pred3_new[,c(1,3,4)]))
colnames(sum1) <- c('Model1', 'Model3')
rownames(sum1) <- c('Predicted', 'PI_low (95%)', 'PI_high (95%)')

sum1

stargazer(sum1, summary = F, digits=0, float=F, out=paste(output,"ch13-table-3-pred-new.tex",sep=""))
stargazer(sum1, summary = F, digits=0, float=F, type="text",  out=paste(output,"ch13-table-3-pred-new.txt",sep=""))
# old name: Ch13_pred_R.txt

# prediction with 80%

# summary of predictions and PI 80% version
# predict value for newly added obs
pred1_new80 <- predict(pred1, newdata = new, se.fit=TRUE, interval = "prediction", level=0.8)
p180<- pred1_new80$fit
pred3_new80 <- predict(pred3, newdata = new,se.fit = TRUE, interval = "prediction", level=0.8)
p380<- pred3_new80$fit

# Result summary
sum2 <- cbind(t(pred1_new80[,c(1,3,4)]), t(pred3_new80[,c(1,3,4)]))
colnames(sum2) <- c('Model1', 'Model3')
rownames(sum2) <- c('Predicted', 'PI_low (80%)', 'PI_high (80%)')
sum2

stargazer(sum2, summary = F, digits=0, float=F, out=paste(output,"ch13-table-3-pred-new80.tex",sep=""))
stargazer(sum2, summary = F, digits=0, float=F, type="text",  out=paste(output,"ch13-table-3-pred-new80.txt",sep=""))

# in book sum1 and sum2 are combined in Table 3
 