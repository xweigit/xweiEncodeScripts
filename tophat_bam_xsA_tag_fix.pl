#!/usr/bin/perl
#
# tophat_bam_xsA_tag_fix.pl
# xwei 03/24/2014
# reads a bam file generated by tophat and fix the XS:A:+ or XS:A:- tags for tophat version 2.0.8


# check the flag field to decide "+" or "-"
#for cases where the mate is unmapped (flag 8) if the read is the first in the pair (flag 64), and maps to the reverse strand (flag 16), then that read should be assigned to the plus strand.
#if the read is the first in the pair (flag 64), and does not map to the reverse strand (does not have flag 16), then that read should be assigned to the minus strand.
#
#if the read is the second in the pair (flag 128), and the read maps to the reverse strand (flag 16), then that read should be assigned to the minus strand. 
#if the read is the second in the pair (flag 128), and does not map to the reverse strand (does not have flag 16), then that read should be assigned to the plus strand. 

### usage: perl tophat_bam_xsA_tag_fix.pl <input bam file> <out bam file>




use strict;
use FileHandle;

if(@ARGV < 2 && ($ARGV[0] eq "--version" || $ARGV[0] eq "-v")){ 
    print STDERR "v1.0 xwei 04/07/2014\n";
    exit(0);
}elsif(@ARGV < 1 || $ARGV[0] =~ m/^-/){
    print STDERR "usage: tophat_bam_xsA_tag_fix.pl <in.bam> [out.bam | out.sam]\n  If output file name wasn't provided, sam output will be sent to STDOUT.\n\n";
    exit(0);
}


my $INBAM = $ARGV[0];
my $OUTFILE = $ARGV[1];

my $is_output_bam = 0; 
my $all_sam = "";
my $ALL = *STDOUT;
if($OUTFILE ne ""){ ## if output file name was provided, write output to a file.
    if ($OUTFILE =~ m/\.[bB][aA][mM]$/){ ## output bam file
        $all_sam = $INBAM . ".all.sam";
        $ALL = new FileHandle ">$all_sam" or die "can't open $all_sam";
        $is_output_bam = 1;
    }else {
        $all_sam = $OUTFILE;
        $ALL = new FileHandle ">$all_sam" or die "can't open $all_sam"; 
    }
}

my @f;
my $line;
my $count = 0;
open(BAM, "samtools view -h $INBAM |")or die("can't open $INBAM file\n"); # use samtools to read bam file
while ($line = <BAM>) {
    chomp($line);
    if ($line =~ m/^\@/){ ## header
         $ALL ->print("$line\n");
    }else{
        @f = split /\t/, $line;
        if($f[1] & 64){ ##if read is the first in the pair (flag 64)
            if($f[1] & 16){ ## if the read maps to the reverse strand (flag 16), then that read should be assigned to the plus strand.
                plus_line($line);
            }else{ 
                minus_line($line);
            }
        }elsif($f[1] & 128){ ##if read is the second in the pair (flag 128)
            if($f[1] & 16){ ## if the read maps to the reverse strand (flag 16), then that read should be assigned to the minus strand. 
                minus_line($line);
            }else{
                plus_line($line);
            }
        }else{
        }
    }
}

if ($is_output_bam){
    ##### convert sam to bam after correct the +/- tags
    #print "samtools view -bS $all_sam > $OUTFILE\n";
    `samtools view -bS $all_sam > $OUTFILE`;
    
    ## remove the sam file
    `rm $all_sam`;
}

###################
sub plus_line{
    my ($line) = @_;
    
    $line = correct_tag($line, "+");
    $ALL ->print("$line\n");
}

###################
sub minus_line{
    my ($line) = @_;
    
    $line = correct_tag($line, "-");
    $ALL ->print("$line\n");
}

########
sub correct_tag{
    my ($line, $tag) = @_;
    ## XS:A:+ or XS:A:-
    
    if($tag eq "+"){ ## if assigned to "+"
        $line =~ s/XS\:A\:\-/XS\:A\:\+/g; ## change all "-" tags to "+"
        $line =~ s/\n/\tXS\:A\:\+\n/; ## add a "+" tag at the end of the line in case if no tags in the line
    }elsif($tag eq "-"){ ## if assigned to "-"
        $line =~ s/XS\:A\:\+/XS\:A\:\-/g; ## change all "+" tags to "-"
        $line =~ s/\n/\tXS\:A\:\-\n/; ## add a "-" tag at the end of the line in case if no tags in the line
    }else{}
    
    ### remove the extra tags derictly
    $line = remove_extra_tags($line, $tag);
    
    return $line;
}

########
sub remove_extra_tags{
    my ($line, $tag) = @_;
    
    my $new_line = "";
    my @tmp = ();
    if($tag eq "+"){ ## if assigned to "+"
        @tmp = split /\tXS\:A\:\+/, $line;
        $new_line = $tmp[0]. "\tXS\:A\:\+".$tmp[1];
    }elsif($tag eq "-"){ ## if assigned to "-"
        @tmp = split /\tXS\:A\:\-/, $line;
        $new_line = $tmp[0]. "\tXS\:A\:\-".$tmp[1];
    }
    for(my $i = 2; $i <= $#tmp; $i++){
        $new_line .= $tmp[$i];
    }
    
    return $new_line;
}


