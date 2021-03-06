library(dplyr)

# this is the raw data file but with the header and footer sections describing data reuse / provenance
data_cc = read.csv('e120_Plant aboveground biomass data no header footer.txt',sep = '\t')

names_planted = (data_cc %>% select(Achmi:Sornu) %>% names)

process_taxon <- function(strings)
{
  sapply(strings, function(string)
  {
    parts = strsplit(string, " ")[[1]]
    p1 = substr(parts[1],1,3)
    p2 = substr(parts[2],1,2)
    fullname = paste(p1,p2,sep="")
    if (fullname %in% names_planted)
    {
      fullname = fullname
    }
    else
    {
      fullname = paste(fullname, string,sep="*")
    }
    return(fullname)
  })
}

names_all = process_taxon(data_cc$Species %>% unique)

# make sure all names are unique
stopifnot(length(unique(names_all)) == length(names_all))

process_plot <- function(df, rewrite.names=FALSE)
{
  inputs_planted = df[1,names_planted] # since all the planting within a plot should be constant
  taxa_planted = names(inputs_planted)[which(inputs_planted==1)]
  
  # get biomasses
  taxa_found = df$Biomass..g.m2.
  names(taxa_found) = df$Taxon
  taxa_found_trimmed = taxa_found[names(taxa_found) %in% names_planted]
  
  # sum up biomass by name (seems there are sometimes duplicates)
  taxa_found_trimmed = tapply(unlist(taxa_found_trimmed), names(unlist(taxa_found_trimmed)), sum)
  
  df_planted = data.frame(matrix(nrow=1,ncol=length(names_planted),data=0))
  names(df_planted) = names_planted
  df_planted[1,taxa_planted] = 1
  if (rewrite.names==TRUE)
  {
    names(df_planted) = letters[1:ncol(df_planted)]
  }
  
  df_outcome = data.frame(matrix(nrow=1,ncol=length(names_planted),data=0))
  names(df_outcome) = names_planted
  df_outcome[1,names(taxa_found_trimmed)] = taxa_found_trimmed
  if (rewrite.names==TRUE)
  {
    names(df_outcome) = letters[1:ncol(df_outcome)]
  }
  names(df_outcome) = paste(names(df_outcome),"star",sep=".")
  
  stable = NA
  feasible = TRUE
  richness = NA
  
  return(data.frame(df_planted, stable, feasible, richness, df_outcome))
}

process_data_by_year <- function(year_this)
{
  # select most recent data
  data_by_plot = data_cc %>% 
    filter(Year==year_this) %>% 
    group_by(Plot) %>%
    select(Species, all_of(names_planted), Biomass..g.m2.) %>%
    mutate(Taxon = process_taxon(Species)) %>%
    group_split
  
  data_processed = do.call("rbind",lapply(data_by_plot, process_plot,rewrite.names = TRUE))
  
  return(data_processed)
}

data_2018 = process_data_by_year(2018)
data_2017 = process_data_by_year(2017)
data_2016 = process_data_by_year(2016)

# check row ordering is constant
diffs_2018_2017 = (data_2018 %>% select(all_of(letters[1:length(names_planted)])) - data_2017 %>% select(all_of(letters[1:length(names_planted)])))
diffs_2017_2016 = (data_2017 %>% select(all_of(letters[1:length(names_planted)])) - data_2016 %>% select(all_of(letters[1:length(names_planted)])))

stopifnot(all(as.numeric(as.matrix(diffs_2018_2017)) == 0))
stopifnot(all(as.numeric(as.matrix(diffs_2017_2016)) == 0))


# look for temporal variation in each species biomass over time
star_2018 = as.matrix(data_2018 %>% select(all_of(paste(letters[1:length(names_planted)],"star",sep="."))))
star_2017 = as.matrix(data_2017 %>% select(all_of(paste(letters[1:length(names_planted)],"star",sep="."))))
star_2016 = as.matrix(data_2016 %>% select(all_of(paste(letters[1:length(names_planted)],"star",sep="."))))

star = simplify2array(list(star_2016, star_2017, star_2018))
# calculate elementwise coefficient of variation over time
cv.star = apply(star, c(1,2), function(x) { cv = sd(x)/mean(x); cv[is.nan(cv)] = 0; return(cv) } )
cv.star.mean = apply(cv.star, 1, mean)

data_final = data_2018
#data_final$stable = (cv.star.mean < 0.5)  
data_final$richness = apply(data_final %>% select(all_of(paste(letters[1:length(names_planted)],"star",sep="."))),1,function(x) { sum(x>0)})

write.csv(data_final, file='cedar_creek_2018.csv',row.names = FALSE)
                          