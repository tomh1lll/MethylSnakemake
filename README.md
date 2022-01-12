
#### Setting up the working environment

Before running the pipeline, certain packages are required to be installed within a custom conda environment.

```
module load python
source /data/$USER/conda/etc/profile.d/conda.sh
conda create --name meth
conda activate meth
mamba install -yc bioconda bwameth methyldackel
conda deactivate meth
```

#### Setting up the working files

Alter the config.yaml so the rawdata_dir is the absolute path of the directory containing all your fastqs.
Alter the result_dir so it is the absolute path of the working directory containing your snakemake pipeline, where results will be stored.

Within the Snakefile, check that the absolution path of the samples.txt is correct and that the absolute path of the working directory is correct.

Within pipeline_submit.sh, alter the R variable to the absolute path of your working directory.

#### Dry run of the pipeline

To perform a dry run of the pipeline, submit:

```
sh pipeline_submit.sh npr
```

#### Actual run of the pipeline

Once everything seems to work, to perform a full run of the pipeline, submit:

```
sbatch --partition=norm --gres=lscratch:500 --time=10-00:00:00 --mail-type=BEGIN,END,FAIL pipeline_submit.sh process
```
