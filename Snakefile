###########################################################################
# Bisulphite sequencing (methylseq) analysis workflow
#
# This pipeline is adapted from current methyseq pipeline from BCB core
# This pipeline focuses on the second set of steps,
# Creator: Neelam Redekar, neelam.redekar@nih.gov
# Created: December 21, 2021
# Modifier: Tom Hill, tom.hill@nih.gov
# Modified: December 28, 2021
#
###########################################################################

from os.path import join
from snakemake.io import expand, glob_wildcards
from snakemake.utils import R
from os import listdir
import pandas as pd

configfile: "/data/NHLBIcore/projects/NHLBI-4/config.yaml"

##
## Locations of working directories and reference genomes for analysis
##
rawdata_dir= config["rawdata_dir"]
working_dir= config["result_dir"]
hg38_fa= config["hg38_fa"]
phage_fa= config["phage_fa"]
bisulphite_genome_path= config["bisulphite_ref"]
bisulphite_fa= config["bisulphite_fa"]
species= config["species"]

##
## Read in the masterkey file for 3 tab-delimited columns of samples, groups and comparison
## Each sample can be in the file multiple times if used in multiple comparisons, but will only be mapped/process once.
##
## e.g.
##
##sample	group	comp
##S1	GA	GAvsGB
##S2	GA	GAvsGB
##S3	GB	GAvsGB
##S4	GB	GAvsGB
##S5	GC	GAvsGC
##S6	GC	GAvsGC
##S1	GA	GAvsGC
##S2	GA	GAvsGC

## The file requires these headings as they are used in multiple rules later on.

## Here we read in the samples file generated and begin processing the data, printing out the samples and group comparisons

df = pd.read_csv("/data/NHLBIcore/projects/NHLBI-4/samples.txt", header=0, sep='\t')

SAMPLES=list(set(df['sample'].tolist()))
GROUPS=list(set(df['comp'].tolist()))

print(SAMPLES)
print(len(SAMPLES))
print(GROUPS)
print(len(GROUPS))

CHRS = ['chr1','chr2','chr3','chr4','chr5','chr6','chr7','chr8','chr9','chr10','chr11','chr12','chr13','chr14','chr15','chr16','chr17','chr18','chr19','chr20','chr21','chr22','chr23','chrX']

RN = ['R1', 'R2']

rule All:
    input:
      # Creating data links:
      expand(join(working_dir, "raw/{samples}.{rn}.fastq.gz"), samples=SAMPLES, rn=RN),
      # Checking data quality:
      expand(join(working_dir, "rawQC/{samples}.{rn}_fastqc.html"), samples=SAMPLES, rn=RN),
      # Quality trimming output:
      expand(join(working_dir, "trimGalore/{samples}_val_1.fq.gz"),samples=SAMPLES),
      expand(join(working_dir, "trimGalore/{samples}_val_2.fq.gz"),samples=SAMPLES),
      # bisulphite genome preparation
      join(bisulphite_genome_path, species, "Bisulfite_Genome/CT_conversion/genome_mfa.CT_conversion.fa"),
      join(bisulphite_genome_path, species, "Bisulfite_Genome/GA_conversion/genome_mfa.GA_conversion.fa"),
      # bwa-meth align to human reference genomes
      expand(join(working_dir, "bwaMethAlign/{samples}.bm_pe.flagstat"),samples=SAMPLES),
      expand(join(working_dir, "bwaMethAlign/{samples}.bm_pe.deduplicated.bam"),samples=SAMPLES),
      expand(join(working_dir, "bwaMethAlign/{samples}.bm_pe.metrics.txt"),samples=SAMPLES),
      expand(join(working_dir, "bwaMethAlign/{samples}.bm_pe.deduplicated.flagstat"),samples=SAMPLES),
      # extract methylation sites
      expand(join(working_dir, "CpG_bwa/{samples}.bm_pe.deduplicated_CpG.bedGraph"),samples=SAMPLES),
      # input for bbseq
      expand(join(working_dir, "phenofiles/{group}_bismark.txt"),group=GROUPS),
      expand(join(working_dir, "phenofiles/{group}_bwa.txt"),group=GROUPS),
      # lm methylation sites from bwa alignments
      expand(join(working_dir, "bsseq_bwa/{group}_{chr}_lm.txt"),chr=CHRS,group=GROUPS),
      expand(join(working_dir, "bsseq_bwa/{group}_{chr}_betas_pval.bed"),chr=CHRS,group=GROUPS),
      expand(join(working_dir, "combP_bwa/{group}_{chr}.regions-p.bed.gz"),group=GROUPS,chr=CHRS),
      #homer files
      expand(join(working_dir, "homer_bwa/{group}_{chr}.homerInput.txt"),group=GROUPS,chr=CHRS),
      expand(join(working_dir, "homer_bwa/{group}_{chr}.homerOutput.txt"),group=GROUPS,chr=CHRS),
      expand(join(working_dir, "homer_bwa/{group}_{chr}.homerOutput2.txt"),group=GROUPS,chr=CHRS),
      expand(join(working_dir,"homer_bwa/{group}_{chr}.homer.annStats.txt"),group=GROUPS,chr=CHRS),
      # bismark align to human reference genomes
      expand(join(working_dir, "bismarkAlign/{samples}.bismark_bt2_pe.bam"),samples=SAMPLES),
      expand(join(working_dir, "bismarkAlign/{samples}.bismark_bt2_pe.deduplicated.bam"),samples=SAMPLES),
      expand(join(working_dir, "CpG_bismark/{samples}.bismark_bt2_pe.deduplicated_CpG.bedGraph"),samples=SAMPLES),
      # lm methylation sites from bismark alignments
      expand(join(working_dir, "bsseq_bismark/{group}_{chr}_lm.txt"),chr=CHRS,group=GROUPS),
      expand(join(working_dir, "bsseq_bismark/{group}_{chr}_betas_pval.bed"),chr=CHRS,group=GROUPS),
      expand(join(working_dir, "combP_bismark/{group}_{chr}.regions-p.bed.gz"),chr=CHRS,group=GROUPS),
    output:
      "multiqc_report.html"

    params:
      projname="MethylSeq",
      dir=directory(join(working_dir,"multiqc")),
    shell:
      """
      module load multiqc/1.8
      mkdir -p {params.dir}
      cd working_dir
      multiqc -d . --data-dir {params.dir}
      """

## Copy raw data to working directory
rule raw_data_links:
    input:
      join(rawdata_dir, "{samples}.{rn}.fastq.gz")
    output:
      join(working_dir, "raw/{samples}.{rn}.fastq.gz")
    params:
      rname="raw_data_links",
      dir=directory(join(working_dir, "raw")),
    shell:
      """
      mkdir -p {params.dir}
      ln -s {input} {output}
      """

## Run fastqc on raw data to visually assess quality
rule raw_fastqc:
    input:
      join(working_dir, "raw/{samples}.{rn}.fastq.gz")
    output:
      join(working_dir, "rawQC/{samples}.{rn}_fastqc.html")
    params:
      rname="raw_fastqc",
      dir=directory(join(working_dir, "rawQC")),
      batch='--cpus-per-task=2 --mem=8g --time=8:00:00',
    threads:
      2
    shell:
      """
      module load fastqc/0.11.9
      mkdir -p {params.dir}
      fastqc -o {params.dir} -f fastq --threads {threads} --extract {input}
      """

## Trim raw data
rule trimmomatic:
    input:
      F1=join(working_dir, "raw/{samples}.R1.fastq.gz"),
      F2=join(working_dir, "raw/{samples}.R2.fastq.gz"),
    output:
      PE1=temp(join(working_dir, "trimmed_reads/{samples}.R1.pe.fastq.gz")),
      UPE1=temp(join(working_dir, "trimmed_reads/{samples}.R1.ue.fastq.gz")),
      PE2=temp(join(working_dir, "trimmed_reads/{samples}.R2.pe.fastq.gz")),
      UPE2=temp(join(working_dir, "trimmed_reads/{samples}.R2.ue.fastq.gz"))
    params:
      rname="trimmomatic",
      dir=directory(join(working_dir, "trimmed_reads")),
      batch='--cpus-per-task=8 --partition=norm --gres=lscratch:180 --mem=25g --time=20:00:00',
      command='ILLUMINACLIP:/usr/local/apps/trimmomatic/Trimmomatic-0.39/adapters/TruSeq3-PE-2.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:50'
    threads:
      8
    shell:
      """
      module load trimmomatic/0.39
      mkdir -p {params.dir}
      java -jar $TRIMMOJAR PE -phred33 -threads {threads} {input.F1} {input.F2} {output.PE1} {output.UPE1} {output.PE2} {output.UPE2} {params.command}
      """

## Second round of trimming/filtering
rule trimGalore:
    input:
      F1=join(working_dir, "trimmed_reads/{samples}.R1.pe.fastq.gz"),
      F2=join(working_dir, "trimmed_reads/{samples}.R2.pe.fastq.gz"),
    output:
      join(working_dir, "trimGalore/{samples}_val_1.fq.gz"),
      join(working_dir, "trimGalore/{samples}_val_2.fq.gz")
    params:
      rname="trimGalore",
      dir=directory(join(working_dir, "trimGalore")),
      tag='{samples}',
      fastqcdir=directory(join(working_dir, "postTrimQC")),
      command="--fastqc --clip_R1 10 --clip_R2 10 --three_prime_clip_R1 10 --three_prime_clip_R2 10 --length 50 --gzip",
      batch='--cpus-per-task=16 --partition=norm --gres=lscratch:100 --mem=25g --time=10:00:00',
    threads:
      16
    shell:
      """
      module load trimgalore/0.6.7
      module load fastqc/0.11.9
      mkdir -p {params.dir}
      trim_galore --paired --cores {threads} {params.command} --basename {params.tag} --output_dir {params.dir} --fastqc_args "--outdir {params.fastqcdir}"  {input.F1} {input.F2}
      """

## Prep genome for bwa, not always necessary
#rule prep_bwa_ref:
#  input:
#    F1=join(reference_path, "genome.fa"),
#    F2=join(reference_path, "phageDNA.sequence.fasta"),
#  output:
#    F1=join(reference_path, "genome.fa.bwameth.c2t"),
#    F2=join(reference_path, "phageDNA.sequence.fasta.bwameth.c2t"),
#  params:
#    rname="prep_bwa_ref",
#  shell:
#    """
#    module load bwa samtools python
#    source /data/hillts/conda/etc/profile.d/conda.sh
#    conda activate meth
#    bwameth.py index {input.F1}
#    bwameth.py index {input.F2}
#    """

rule bwa_meth:
  input:
    F1=join(working_dir, "trimGalore/{samples}_val_1.fq.gz"),
    F2=join(working_dir, "trimGalore/{samples}_val_2.fq.gz"),
  output:
    B1=temp(join(working_dir, "bwaMethAlign/{samples}.bm_pe.bam")),
    B2=join(working_dir, "bwaMethAlign/{samples}.bm_pe.flagstat"),
  params:
    rname="bwa_meth",
    dir=directory(join(working_dir,"bwaMethAlign")),
    genome=hg38_fa,
  threads:
    16
  shell:
    """
      module load bwa samtools/1.9 python
      source /data/hillts/conda/etc/profile.d/conda.sh
      conda activate meth
      mkdir -p {params.dir}
      module load samtools/1.9
      bwameth.py  --threads {threads} --reference {params.genome} {input.F1} {input.F2} | samtools view -@ {threads} -hb | samtools sort -@ {threads} -o {output.B1}
      samtools flagstat -@ {threads} {output.B1} > {output.B2}
    """

rule bwa_meth_phage:
  input:
    F1=join(working_dir, "trimGalore/{samples}_val_1.fq.gz"),
    F2=join(working_dir, "trimGalore/{samples}_val_2.fq.gz"),
  output:
    B1=join(working_dir, "bwaMethPhage/{samples}.bm_pe.bam"),
  params:
    rname="bwa_meth_phage",
    dir=directory(join(working_dir,"bwaMethPhage")),
    genome=phage_fa,
  threads:
    16
  shell:
    """
      module load bwa samtools python
      source /data/hillts/conda/etc/profile.d/conda.sh
      conda activate meth
      module load samtools/1.9
      mkdir -p {params.dir}
      bwameth.py  --threads {threads} --reference {params.genome} {input.F1} {input.F2} | samtools view  -F 4 -@ {threads} -hb | samtools sort -@ {threads} -o {output.B1}
    """

rule bwa_meth_dedup:
    input:
      B1=join(working_dir, "bwaMethAlign/{samples}.bm_pe.bam"),
    output:
      B1=join(working_dir, "bwaMethAlign/{samples}.bm_pe.deduplicated.bam"),
      M1=join(working_dir, "bwaMethAlign/{samples}.bm_pe.metrics.txt"),
      B2=join(working_dir, "bwaMethAlign/{samples}.bm_pe.deduplicated.flagstat"),
    params:
      rname="bwa_meth_dedup",
      dir=directory(join(working_dir, "bwaMethAlign")),
    threads:
      16
    shell:
      """
      module load picard
      mkdir -p {params.dir}
      java -Xmx20g -XX:ParallelGCThreads={threads} -jar $PICARDJARPATH/picard.jar MarkDuplicatesWithMateCigar -I {input.B1} -O {output.B1} -M {output.M1}
      samtools flagstat -@ {threads} {output.B1} > {output.B2}
      """

rule extract_CpG_bwa_meth:
    input:
      F1=join(working_dir, "bwaMethAlign/{samples}.bm_pe.deduplicated.bam"),
    output:
      B1=join(working_dir, "CpG_bwa/{samples}.bm_pe.deduplicated_CpG.bedGraph"),
    params:
      rname="extract_CpG_bwa_meth",
      dir=directory(join(working_dir, "CpG_bwa")),
      genome=hg38_fa,
      prefix=join(working_dir,"CpG_bwa/{samples}.bm_pe.deduplicated"),
    threads:
      16
    shell:
      """
      module load python
      module load samtools
      mkdir -p {params.dir}
      source /data/hillts/conda/etc/profile.d/conda.sh
      conda activate meth
      module load samtools/1.9
      MethylDackel extract --CHH --CHG -o {params.prefix} -@ {threads} {params.genome} {input.F1}
      """

rule bsseq_inputs:
  input:
    G1=join(working_dir,"groupings.txt"),
  output:
    C1=join(working_dir,"phenofiles/{group}_bwa.txt"),
    B1=join(working_dir,"phenofiles/{group}_bismark.txt"),
  params:
    rname="bsseq_inputs",
    groupComp='{group}',
    dir=working_dir,
    script_dir=join(working_dir,"scripts"),
    p_dir=directory(join(working_dir, "phenofiles")),
  run:
    """
    import pandas as pd
    import os

    path = params.p_dir
    isExist = os.path.exists(path)
    if not isExist:
      os.makedirs(path)
      print("The new directory is created!")

    df = pd.read_csv(input.G1, header=0, sep='\t')

    df2 = df.loc[df['comp'] == params.groupComp]
    df2['path'] = df2['sample']
    df2['path'] = params.dir + "/CpG_bwa/" + df2['path'] + ".bm_pe.deduplicated_CpG.bedGraph"
    df2.to_csv(output.C1, sep="\t",index=False)

    df3 = df.loc[df['comp'] == params.groupComp]]
    df3['path'] = df3['sample']
    df3['path'] = params.dir + "/CpG_bismark/" + df3['path'] + ".bismark_bt2_pe.deduplicated_CpG.bedGraph"
    df3.to_csv(output.B1, sep="\t",index=False)
    """

rule bsseq_bwa:
  input:
    bizfile=join(working_dir,"phenofiles/{group}_bwa.txt"),
    B1=expand(join(working_dir, "CpG_bwa/{samples}.bm_pe.deduplicated_CpG.bedGraph"),samples=SAMPLES),
  output:
    bsseq=join(working_dir, "bsseq_bwa/{group}_{chr}_lm.txt"),
    bed=join(working_dir, "bsseq_bwa/{group}_{chr}_betas_pval.bed"),
  params:
    rname="bsseq_bwa",
    chr='{chr}',
    dir=directory(join(working_dir, "bsseq_bwa")),
    cov="2",
    sample_prop="0.25",
  threads:
    4
  shell:
    """
      module load R
      mkdir -p {params.dir}
      Rscript bsseq_lm.R {params.chr} {input.bizfile} {output.bsseq} {output.bed} {params.sample_prop} {params.cov}
    """

rule combP_bwa:
  input:
    join(working_dir, "bsseq_bwa/{group}_{chr}_betas_pval.bed"),
  output:
    join(working_dir, "combP_bwa/{group}_{chr}.regions-p.bed.gz"),
  params:
    rname="CombP",
    groups='{group}_{chr}',
    dir=join(working_dir, "combP_bwa"),
  shell:
    """
      mkdir -p {params.dir}
      comb-p pipeline -c 4 --dist 300 \
      --step 60 --seed 0.01 \
      -p {params.dir}/{params.groups}  \
      --region-filter-p 0.05 \
      --region-filter-n 3 \
      {input}
    """

rule homer_bwa:
  input:
    join(working_dir, "combP_bwa/{group}_{chr}.regions-p.bed.gz"),
  output:
    homerInput=join(working_dir, "homer_bwa/{group}_{chr}.homerInput.txt"),
    homerOutput=join(working_dir, "homer_bwa/{group}_{chr}.homerOutput.txt"),
    homerOutput2=join(working_dir, "homer_bwa/{group}_{chr}.homerOutput2.txt"),
    homerAnn=join(working_dir,"homer_bwa/{group}_{chr}.homer.annStats.txt"),
  params:
    dir=join(working_dir, "homer_bwa"),
    annStat=join(working_dir,"homer_bwa/blank.homer.annStats.txt"),
  shell:
    """
    module load homer
    mkdir -p {params.dir}
    cp {params.annStat} {output.homerAnn}
    zcat {input} | sed "1,1d" | awk "{{print$1"\t"$2"\t"$3"\t"$1"_"$2"_"$3"\t"$4"|"$5"|"$6"|"$7"\t""*"}}" > {output.homerInput}

    annotatePeaks.pl {output.homerInput} hg38 -annStats {output.homerAnn} > {output.homerOutput}

    awk "NR==FNR{{a[$4]=$5;next}}NR!=FNR{{c=$1; if(c in a){{print $0"\t"a[c]}}}}" {output.homerInput} {output.homerOutput} > {output.homerOutput2}

    """

rule prep_bisulphite_genome:
    input:
      bisulphite_fa
    output:
      join(bisulphite_genome_path, species, "Bisulfite_Genome/CT_conversion/genome_mfa.CT_conversion.fa"),
      join(bisulphite_genome_path, species, "Bisulfite_Genome/GA_conversion/genome_mfa.GA_conversion.fa"),
    params:
      rname="prep_bisulphite_genome",
      dir=directory(join(bisulphite_genome_path, species)),
      batch='--cpus-per-task=16 --partition=norm --gres=lscratch:100 --mem=20g --time=2:00:00',
    threads:
      16
    shell:
      """
      module load bismark/0.23.0
      mkdir -p {params.dir}
      cd {params.dir}
      #cp reference_genome {params.dir}/genome.fa
      bismark_genome_preparation --verbose --parallel {threads} {params.dir} #--single_fasta
      """

rule bismark_align:
    input:
      F1=join(working_dir, "trimGalore/{samples}_val_1.fq.gz"),
      F2=join(working_dir, "trimGalore/{samples}_val_2.fq.gz"),
    output:
      join(working_dir, "bismarkAlign/{samples}.bismark_bt2_pe.bam"),
    params:
      rname="bismark_align",
      dir=directory(join(working_dir, "bismarkAlign")),
      genome_dir=directory(join(bisulphite_genome_path, species)),
      command="--bowtie2 -N 1 --bam -L 22 --X 1000 --un --ambiguous -p 4 --score_min L,-0.6,-0.6",
      batch='--cpus-per-task=16 --partition=norm --gres=lscratch:100 --mem=100g --time=10:00:00',
      outbam=join(working_dir, "bismarkAlign/{samples}_val_1_bismark_bt2_pe.bam"),
    threads:
      16
    shell:
      """
      module load bismark/0.23.0
      mkdir -p {params.dir}
      bismark --multicore {threads} --temp_dir /lscratch/$SLURM_JOBID/ {params.command} --output_dir {params.dir} --genome {params.genome_dir} -1 {input.F1} -2 {input.F2}
      mv {params.outbam} {output}
      """

rule bismark_dedup:
    input:
      F1=join(working_dir, "bismarkAlign/{samples}.bismark_bt2_pe.bam"),
    output:
      T1=temp(join(working_dir, "bismarkAlign/{samples}.bismark_bt2_pe.deduplicated.deduplicated.bam")),
      B1=join(working_dir, "bismarkAlign/{samples}.bismark_bt2_pe.deduplicated.bam"),
    params:
      rname="bismark_dedup",
      dir=directory(join(working_dir, "bismarkAlign")),
    threads:
      16
    shell:
      """
      module load bismark/0.23.0
      module load samtools
      deduplicate_bismark --paired --bam --outfile {output.B1} {input.F1}
      samtools view -h {output.T1} | samtools sort -@ {threads} -o {output.B1}
      """

rule extract_CpG_bismark:
    input:
      F1=join(working_dir, "bismarkAlign/{samples}.bismark_bt2_pe.deduplicated.bam"),
    output:
      B1=join(working_dir, "CpG_bismark/{samples}.bismark_bt2_pe.deduplicated_CpG.bedGraph"),
    params:
      rname="extract_CpG_bismark",
      dir=directory(join(working_dir, "CpG_bismark")),
      genome=hg38_fa,
      prefix=join(working_dir,"CpG_bismark/{samples}.bismark_bt2_pe.deduplicated"),
    threads:
      16
    shell:
      """
      module load python
      module load samtools
      mkdir -p {params.dir}
      source /data/hillts/conda/etc/profile.d/conda.sh
      conda activate meth
      MethylDackel extract --CHH --CHG -o {params.prefix} -@ {threads} {params.genome} {input.F1}
      """

rule bsseq_bismark:
  input:
    B1=expand(join(working_dir, "CpG_bismark/{samples}.bismark_bt2_pe.deduplicated_CpG.bedGraph"),samples=SAMPLES),
    bizfile=join(working_dir,"phenofiles/{group}_bismark.txt"),
  output:
    bsseq=join(working_dir, "bsseq_bismark/{group}_{chr}_lm.txt"),
    bed=join(working_dir, "bsseq_bismark/{group}_{chr}_betas_pval.bed"),
  params:
    rname="bsseq_bismark",
    chr='{chr}',
    dir=directory(join(working_dir, "bsseq_bismark")),
    cov="2",
    sample_prop="0.25",
  threads:
    4
  shell:
    """
      module load R
      mkdir -p {params.dir}
      Rscript bsseq_lm.R {params.chr} {input.bizfile} {output.bsseq} {output.bed} {params.sample_prop} {params.cov}
    """

rule combP_bismark:
  input:
    join(working_dir, "bsseq_bismark/{group}_{chr}_betas_pval.bed"),
  output:
    join(working_dir, "combP_bismark/{group}_{chr}.regions-p.bed.gz"),
  params:
    rname="CombPbis",
    groups='{group}_{chr}',
    dir=join(working_dir, "combP_bismark"),
  shell:
    """
      mkdir -p {params.dir}
      comb-p pipeline -c 4 --dist 300 \
      --step 60 --seed 0.01 \
      -p {params.dir}/{params.groups}  \
      --region-filter-p 0.05 \
      --region-filter-n 3 \
      {input}
    """

rule homer_bismark:
  input:
    join(working_dir, "combP_bismark/{group}_{chr}.regions-p.bed.gz"),
  output:
    homerInput=join(working_dir, "homer_bismark/{group}_{chr}.homerInput.txt"),
    homerOutput=join(working_dir, "homer_bismark/{group}_{chr}.homerOutput.txt"),
    homerOutput2=join(working_dir, "homer_bismark/{group}_{chr}.homerOutput2.txt"),
    homerAnn=join(working_dir,"homer_bismark/{group}_{chr}.homer.annStats.txt"),
  params:
    dir=join(working_dir, "homer_bismark"),
    annStat=join(working_dir,"homer_bismark/blank.homer.annStats.txt"),
  shell:
    """
    module load homer
    mkdir -p {params.dir}
    cp {params.annStat} {output.homerAnn}
    zcat {input} | sed "1,1d" | awk "{{print$1"\t"$2"\t"$3"\t"$1"_"$2"_"$3"\t"$4"|"$5"|"$6"|"$7"\t""*"}}" > {output.homerInput}

    annotatePeaks.pl {output.homerInput} hg38 -annStats {output.homerAnn} > {output.homerOutput}

    awk "NR==FNR{{a[$4]=$5;next}}NR!=FNR{{c=$1; if(c in a){{print $0"\t"a[c]}}}}" {output.homerInput} {output.homerOutput} > {output.homerOutput2}

    """