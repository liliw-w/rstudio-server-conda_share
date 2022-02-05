#!/bin/sh
#SBATCH --time=2:00:00
#SBATCH --signal=USR2
#SBATCH --partition=broadwl
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=5G
#SBATCH --output=rstudio-server.job
# customize --output path as appropriate (to a directory readable only by the user!)

# See also https://www.rocker-project.org/use/singularity/

# Main parameters for the script with default values
IP=$(/sbin/ip route get 8.8.8.8 | awk '{print $NF;exit}')
PORT=8787
echo "Open RStudio Server at http://${IP}:${PORT}"

USER=$(whoami)
USER_psw=123
CONDA_PREFIX="/scratch/midway2/${USER}/conda_env/rstudio-server"
TMPDIR=${TMPDIR:-tmp}

# singularity pull docker://rocker/rstudio_latest
dir_repo="/scratch/midway2/${USER}/rstudio-server-conda"
CONTAINER="${dir_repo}/singularity/rstudio_latest.sif"


# Set-up temporary paths
RSTUDIO_TMP="${TMPDIR}/$(echo -n $CONDA_PREFIX | md5sum | awk '{print $1}')"
mkdir -p $RSTUDIO_TMP/{run,var-lib-rstudio-server,local-share-rstudio,tmp}

R_BIN=$CONDA_PREFIX/bin/R
PY_BIN=$CONDA_PREFIX/bin/python

if [ ! -f $CONTAINER ]; then
    singularity build --fakeroot $CONTAINER Singularity
fi

if [ -z "$CONDA_PREFIX" ]; then
  echo "Activate a conda env or specify \$CONDA_PREFIX"
  exit 1
fi

cat > ${RSTUDIO_TMP}/rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=1
#export R_LIBS_USER=${CONDA_PREFIX}/lib
export CONDA_PREFIX=${CONDA_PREFIX}/bin/macs2
exec rsession "\${@}"
END

chmod +x ${RSTUDIO_TMP}/rsession.sh

export SINGULARITYENV_USER=${USER}
export SINGULARITYENV_PASSWORD=${USER_psw}
export SINGULARITYENV_RSTUDIO_WHICH_R=${R_BIN}
export SINGULARITYENV_CONDA_PREFIX=${CONDA_PREFIX}
export SINGULARITYENV_USER=${USER}
export SINGULARITY_CACHEDIR=/scratch/midway2/${USER}/.singularity

cat 1>&2 <<END
1. SSH tunnel from your workstation using the following command:

   ssh -N -L 8787:${HOSTNAME}:${PORT} ${SINGULARITYENV_USER}@midway2.rcc.uchicago.edu

   and point your web browser to http://localhost:8787

2. log in to RStudio Server using the following credentials:

   user: ${SINGULARITYENV_USER}
   password: ${SINGULARITYENV_PASSWORD}

When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END

/software/singularity-3.4.0-el7-x86_64/bin/singularity exec \
    --bind $RSTUDIO_TMP/run:/run \
    --bind $RSTUDIO_TMP/var-lib-rstudio-server:/var/lib/rstudio-server \
    --bind $RSTUDIO_TMP/tmp:/tmp \
    --bind $RSTUDIO_TMP/rsession.sh:/etc/rstudio/rsession.sh \
    --bind /sys/fs/cgroup/:/sys/fs/cgroup/:ro \
    --bind ${dir_repo}/singularity/database.conf:/etc/rstudio/database.conf \
    --bind ${dir_repo}/singularity/rsession.conf:/etc/rstudio/rsession.conf \
    --bind ${dir_repo}/singularity/rserver.conf:/etc/rstudio/rserver.conf \
    --bind $RSTUDIO_TMP/local-share-rstudio:/home/rstudio/.local/share/rstudio \
    --bind ${CONDA_PREFIX}:${CONDA_PREFIX} \
    --bind $HOME/.config/rstudio:/home/rstudio/.config/rstudio \
    --bind /project2:/project2 \
    --bind /scratch/midway2/${USER}:/scratch/midway2/${USER} \
    ${CONTAINER} rserver  \
    --rsession-which-r=${R_BIN} \
    --www-address=${IP} \
    --www-port=${PORT} \
    --server-user ${USER} \
    --auth-none=0 \
    --auth-pam-helper-path=pam-helper \
    --auth-timeout-minutes=0 \
    --auth-stay-signed-in-days=3

printf 'rserver exited' 1>&2
