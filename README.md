
#### Setting up the working files



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
