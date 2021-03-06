#############################
#       RUSEARCH.R          #
#    Kazuyuki Ooi (KEEA)    #
#############################

# 使用するパッケージのインストール
install.packages("tidyr")
install.packages("stringr")
install.packages("BiocManager")
BiocManager::install("Biostrings")

# usearchはwindows用の実行ファイルを https://www.drive5.com/usearch/download.html から入手し
# 適当なフォルダ（例：C:\usearch）におく。そのフォルダにpathを通しておく。
# （設定の検索に「システムの詳細設定」と入力して検索→右下の環境変数のボタンをクリック→新規でpathを追加）
# usearchの実行ファイルのファイル名をusearch.exeにリネームしておく。

workpath<-"D:/NGS/Rusearch/"  #作業フォルダ名を入れる
setwd(workpath)

#作業フォルダ内に解析したいdemultiplicateしたNGS(illumina)の出力のfastqファイルを入れる
#fastq.gzは7-zip等を使用して.fastq形式に展開しておく

# 以下5行は DADA2 tutorial から引用
# Forward and reverse fastq filenames have format: SAMPLENAME_R1_001.fastq and SAMPLENAME_R2_001.fastq
fnFs <- sort(list.files(workpath, pattern="_R1_001.fastq", full.names =  TRUE))
fnRs <- sort(list.files(workpath, pattern="_R2_001.fastq", full.names = TRUE))
# Extract sample names, assuming filenames have format: SAMPLENAME_XXX.fastq
sample.names <- sapply(strsplit(basename(fnFs), "_"), `[`, 1)

# 解析するFASTQファイル（ペア）数
len.sample <- length(sample.names)

# merge pairends　ペアエンドがオーバーラップしている場合のペアエンドのマージ
# fnFs[],fnRs[]にはファイル名だけでなくworkpathも含まれているので注意
for(i in 1:len.sample){
  com001 <- paste("usearch -fastq_mergepairs ",fnFs[i],
                  " -reverse ",fnRs[i]," -fastqout ",
                  workpath,sample.names[i],"_merged.fastq",sep="")
  log001 <- system(com001,intern=T)
}

# join pairends　オーバーラップなし、NNNNNNNNを挟んで結合
# fnFs[],fnRs[]にはファイル名だけでなくworkpathも含まれているので注意
#for(i in 1:len.sample){
#  com001 <- paste("usearch -fastq_join ",fnFs[i],
#                  " -reverse ",fnRs[i]," -fastqout ",
#                  workpath,sample.names[i],"_merged.fastq",sep="")
#  log001 <- system(com001,intern=T)
#}

# trim primers　USEARCHのtruncateを使う場合（プライマー部分固定長）
# MiFish-U-F NNNNNNGTCGGTAAAACTCGTGCCAGC (27)
# MiFish-U-R NNNNNNCATAGTGGGGTATCTAATCCCAGTTTG (33)
for(i in 1:len.sample){
  com002 <- paste("usearch -fastx_truncate ",sample.names[i],
                  "_merged.fastq -stripleft 27 -stripright 33 -fastqout ",
                  sample.names[i],"_stripped.fastq",sep="")
  log002 <- system(com002,intern=T)
}

# trim Primers　pythonのcutPrimers.pyを使う場合（プライマー位置が変わる可能性がある場合）
# python3系の実行ファイルにpathが通っていて、workpathにcutPrimers.pyがあること
#for(i in 1:len.sample){
#  pycom1 <- paste("python cutPrimers.py -r1 ",sample.names[i],"_merged.fastq ",
#                  "-pr15 MiFishPrimerF.fas -pr13 MiFishPrimerRrev.fas -tr1 ",
#                  sample.names[i],"_stripped.fastq -utr1 ",sample.names[i],
#                  "_untrimmed.fastq.gz -t 4",sep="")
#  pylog1 <- system(pycom1,intern=T)
#}

# filter　低品質配列のフィルタリング
for(i in 1:len.sample){
  com003 <- paste("usearch -fastq_filter ",sample.names[i],
                  "_stripped.fastq -fastq_minlen 140 -fastq_maxee 1.0 -fastqout ",
                  sample.names[i],"_filtered.fastq",sep="")
  log003 <- system(com003,intern=T)
}

# unique sequence (dereplication)　重複配列のカウント
for(i in 1:len.sample){
  com004 <- paste("usearch -fastx_uniques ",sample.names[i],"_filtered.fastq -fastaout ",
                  sample.names[i],"_uniques.fasta -sizeout -relabel Uniq",sep="")
  log004 <- system(com004,intern=T)
}

# UNOISE3　デノイジング
# ノイジー配列が多く残ってしまう場合は-unoise_alphaを1.0などに下げると改善する
for(i in 1:len.sample){
  com006 <- paste("usearch -unoise3 ",sample.names[i],"_uniques.fasta -zotus ",
                  sample.names[i],"_zotus.fas -unoise_alpha 2.0 -relabel Zotu",sep="")
  log006 <- system(com006,intern=T)
}

for(i in 1:len.sample){
  com008 <- paste("usearch -otutab ",sample.names[i],"_filtered.fastq -zotus ",
                  sample.names[i],"_zotus.fas -otutabout ",sample.names[i],
                  "_zotutab.txt -mapout ",sample.names[i],"_zmap.txt",sep="")
  log008 <- system(com008,intern=T)
}

# UPARSE　クラスタリング
for(i in 1:len.sample){
  com005 <- paste("usearch -cluster_otus ",sample.names[i],"_uniques.fasta -otus ",
                  sample.names[i],"_otus.fas -relabel Otu",sep="")
  log005 <- system(com005,intern=T)
}

for(i in 1:len.sample){
  com007 <- paste("usearch -otutab ",sample.names[i],"_filtered.fastq -otus ",
                  sample.names[i],"_otus.fas -otutabout ",sample.names[i],
                  "_otutab.txt -mapout ",sample.names[i],"_map.txt",sep="")
  log007 <- system(com007,intern=T)
}


# 集計　デノイジングとクラスタリングで集約した塩基配列ごと（OTU）にサンプル別のリード数を一覧表化
# エクセルのピボット集計と同様の集計表を作成

library(tidyr)
library(stringr)
library("Biostrings")

# UNOISE　デノイジング
df <- data.frame()

for(i in 1:len.sample){
  ZotuTab <- read.table(paste0(sample.names[i],"_zotutab.txt"), skip=1)
  seq_name = ZotuTab[,1]
  zotu_size = ZotuTab[,2]
  dfZotu <- data.frame(seq_name, zotu_size)
  dfZotu <- dfZotu %>% dplyr::mutate(sample = sample.names[i], 
                                     sample_seq_name = paste0(sample, "_", str_sub(seq_name,start=1,end=4), 
                                                              str_pad(str_sub(seq_name,start=5,end=str_length(seq_name)),width=3,side="left","0")))

  fastaFile <- readDNAStringSet(paste0(sample.names[i],"_zotus.fas"))
  seq_name = names(fastaFile)
  sequence = paste(fastaFile)
  dfZseq <- data.frame(seq_name, sequence)

  df <- rbind(df, dplyr::full_join(dfZotu,dfZseq,by="seq_name"))
}

ResultTable <- df %>% dplyr::group_by(sequence,sample) %>% 
  dplyr::summarize(read_size=sum(zotu_size)) %>% spread(sample,read_size)

write.csv(ResultTable, "ResultTable_zotus.csv")

# UPARSE　クラスタリング
df <- data.frame()

for(i in 1:len.sample){
  ZotuTab <- read.table(paste0(sample.names[i],"_otutab.txt"), skip=1)
  seq_name = ZotuTab[,1]
  zotu_size = ZotuTab[,2]
  dfZotu <- data.frame(seq_name, zotu_size)
  dfZotu <- dfZotu %>% dplyr::mutate(sample = sample.names[i], 
                                     sample_seq_name = paste0(sample, "_", str_sub(seq_name,start=1,end=4), 
                                                              str_pad(str_sub(seq_name,start=5,end=str_length(seq_name)),width=3,side="left","0")))
  
  fastaFile <- readDNAStringSet(paste0(sample.names[i],"_otus.fas"))
  seq_name = names(fastaFile)
  sequence = paste(fastaFile)
  dfZseq <- data.frame(seq_name, sequence)
  
  df <- rbind(df, dplyr::full_join(dfZotu,dfZseq,by="seq_name"))
}

ResultTable <- df %>% dplyr::group_by(sequence,sample) %>% 
  dplyr::summarize(read_size=sum(zotu_size)) %>% spread(sample,read_size)

write.csv(ResultTable, "ResultTable_otus.csv")

# 塩基配列を生物種名に対応づけるためには、BLAST検索を行う。
# ResultTable_(z)otus.csvの1,2列目からfasta形式の塩基配列一覧を作る。
# （エクセルで開いて、1,2列目をテキストエディタにコピー→"\n"（改行）を"\n>"に置換、"\t"（タブ）を"\n"に置換）
# NCBIのBLASTn https://blast.ncbi.nlm.nih.gov/Blast.cgi?PROGRAM=blastn&PAGE_TYPE=BlastSearch&LINK_LOC=blasthome に
# fasta形式の一覧をコピー&ペースト、Database Others, Optimize for blastnを選択してBLASTボタンを押す。
# 検索結果のRIDのDownload AllからTextとHitTable(csv)をダウンロードして、テキストエディタ等で各配列ごとに確認することができる。

