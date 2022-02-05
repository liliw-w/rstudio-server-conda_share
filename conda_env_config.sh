USER=$(whoami)

## create conda environment for storing R, python, pcks, rstudio server, et al
conda create --prefix /scratch/midway2/${USER}/conda_env/rstudio-server python=3.10

## activate the env
conda activate /scratch/midway2/${USER}/conda_env/rstudio-server

## install R
conda install -c conda-forge r-base=4.1.2

## install R essential pcks
conda install -c conda-forge r-essentials

## list installed pcks in the env
conda list -p /scratch/midway2/${USER}/conda_env/rstudio-server

## a special example of installing a pck that should use more than one channels to avoid conflicts
## > Please remember to use the conda-forge channel as well, we use it in Bioconda for many dependencies. https://www.biostars.org/p/444261/
conda install -c conda-forge -c bioconda r-wgcna

