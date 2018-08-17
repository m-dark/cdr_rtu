#!/usr/bin/perl -w
#########################################################################################################################################################
# Скрипт написал Крук Иван Александрович <kruk.ivan@itmh.ru><--><------><------><------><------><------><------><------><------><------><------><------>#
#<-----><------><------><------><------><------><------><------><------><------><------><------><------><------><------><------><------><------><------>#
#########################################################################################################################################################

use strict;
use Cwd;
use warnings;
use Time::Local;
use POSIX qw(strftime);
use Sys::Hostname;
use Data::Dumper;
use utf8;
use LWP::Simple;
binmode(STDOUT,':utf8');

my $dir = '/itmh/scripts';
my $tmp_dir = '/tmp';
my $history_dir = "$dir/history";
my $log_dir = "/itmh/log/DEF_sverdl";
my $date_directory = strftime "%Y%m", localtime(time);			#Имя каталога для файлов .diff
my $date_script_log = strftime "%Y-%m-%d %H:%M:%S", localtime(time);	#Время запуска скрипта для лога .log
my $date_time_file = strftime "%Y-%m-%d_%H%M%S", localtime(time);	#Переменная хранит в себе дату и время запуска скрипта, для понимания, когда вносились изменения.
my $url = "https://rossvyaz.gov.ru/docs/articles/DEF-9x.html";
my $file = 'DEF-9x.html';
my $new_start = 0;
my $new_end = 0;
my %hash_number_pools = ();
my %hash_number_pools_new = ();
my %hash_prefix = ();
my $level_of_detail = 3;						#уровень детальности регулярного выражения(рекомендованные значения: 1..4)
my $regular = 9;
for(my $r = 1; $r < $level_of_detail; $r++){
	$regular = $regular.0;
}
print "$regular\n";
opendir (CD, "$history_dir") || mkdir "$history_dir", 0744;
closedir (CD);
opendir (HIS, "$log_dir") || mkdir "$log_dir", 0744;
closedir (HIS);
opendir (HIS, "$history_dir/$date_directory") || mkdir "$history_dir/$date_directory", 0744;
closedir (HIS);

&log_file ("Start");
#`wget $url $dir`;
#my $curl = `curl -O $url`;
#my $content = get $url || die "Couldn't get $url" unless defined $content;

#my $content = get $url || &log_file ("Couldn\'t get $url");

open (my $file_html, '<:encoding(windows-1251)', "$dir/$file") || die "Error opening file: $file $!";
        while (defined(my $lime_file_html = <$file_html>)){
#        foreach my $lime_file_html (split (/\n/,$content,-1)){
		if ($lime_file_html =~ /Свердловская обл/){
			chomp ($lime_file_html);
			$lime_file_html =~ s/\<\/td\>//g;
			$lime_file_html =~ s/\t//g;
			my @number_pools = split (/\<td\>/,$lime_file_html,-1);
			my $start = $number_pools[1].$number_pools[2];
			my $end = $number_pools[1].$number_pools[3];
			if ($end < $start){
				&log_file ("Error_01: Начальный номер пула $start-$end больше конечного.");
				next;
			}
			if (($number_pools[1] !~ /^9\d\d$/) || ($number_pools[2] !~ /^\d{7}$/) || ($number_pools[3] !~ /^\d{7}$/)){
				&log_file ("Error_02: Не верный формат у одного из параметров $number_pools[1]\t$number_pools[2]\t$number_pools[3]");
				next;
			}
			$hash_number_pools{$start} = $end;
		}
	}
close ($file_html);

foreach my $key (sort keys %hash_number_pools){
	if ($new_start == 0){
		$new_start = $key;
		$new_end = $hash_number_pools{$key};
	}else{
		if (($key - $new_end) == 1){
			$new_end = $hash_number_pools{$key};
		}else{
			$hash_number_pools_new{$new_start} = $new_end;
			$new_start = $key;
			$new_end = $hash_number_pools{$key};
		}
	}
}
$hash_number_pools_new{$new_start} = $new_end;

open (my $file_pools, '>>:encoding(UTF-8)', "$tmp_dir/${date_time_file}_pools.cfg") || die "Error opening file: ${date_time_file}_pools.cfg $!";
foreach my $key_new (sort keys %hash_number_pools_new){
	print $file_pools "$key_new-$hash_number_pools_new{$key_new}\n";
	&mask_pool($key_new, $hash_number_pools_new{$key_new});
}
close($file_pools);
&diff_file("$dir", "$tmp_dir", 'pools.cfg');

open (my $file_out, '>>:encoding(UTF-8)', "$tmp_dir/${date_time_file}_prefix.cfg") || die "Error opening file: ${date_time_file}_prefix.cfg $!";
open (my $file_regular, '>>:encoding(UTF-8)', "$tmp_dir/${date_time_file}_regular.cfg") || die "Error opening file: ${date_time_file}_regular.cfg $!";
	print $file_regular "\^8".$regular."\(";
	my $delimiter = 0;
	foreach my $key_prefix (sort keys %hash_prefix){
		print $file_out "$key_prefix\n";
		if(substr($key_prefix,0,$level_of_detail) == $regular){
			if($delimiter == 0){
				print $file_regular substr($key_prefix,$level_of_detail);
				$delimiter = 1;
			}else{
				print $file_regular "|".substr($key_prefix,$level_of_detail);
			}
		}else{
			$regular = substr($key_prefix,0,$level_of_detail);
			print $file_regular ")\.\*\n";
			print $file_regular "\^8".$regular."\(".substr($key_prefix,$level_of_detail);
		}
	}
	print $file_regular ")\n";
close($file_out);
close ($file_regular);

&diff_file("$dir", "$tmp_dir", 'prefix.cfg');
&diff_file("$dir", "$tmp_dir", 'regular.cfg');
&log_file ("Stop");

sub mask_pool{
	my ($start, $end) = @_;
	my $konec_stoki_0 = 0;
	my $konec_stoki_9 = 9;
	my $konec_stoki_90 = 9;
	my $inc = 1;
	my $cut_end;
	while($end >= $start){
		if ($end =~ /$konec_stoki_0$/){
			$cut_end = substr($end,0,11-length($inc));
			$hash_prefix{$cut_end} += 1;
			$konec_stoki_0 = $konec_stoki_0.0;
			$konec_stoki_9 = $konec_stoki_9.9;
			$konec_stoki_90 = $konec_stoki_90*10;
			$end = $end - $inc;
			$inc = $inc*10;
		}elsif($end =~ /$konec_stoki_9$/){
			$cut_end = substr($end,0,11-length($inc));
			my $ss = substr(($cut_end.$konec_stoki_0),0,10);
			if($ss > $start){
				$konec_stoki_9 = $konec_stoki_9.9;
				$konec_stoki_0 = $konec_stoki_0.0;
				$konec_stoki_90 = $konec_stoki_90*10;
				$inc = $inc*10;
			}elsif($ss == $start){
				$hash_prefix{$cut_end} += 1;
				last;
			}else{
				$cut_end = $cut_end.9;
				$hash_prefix{$cut_end} += 1;
				$cut_end = $cut_end -1;
				my $ss = substr(($cut_end.$konec_stoki_9),0,10);
				&mask_pool($start,$ss);
				last;
			}
		}elsif($end =~ /$konec_stoki_90$/){
			$end = $end - $inc;
		}else{
			$cut_end = substr($end,0,11-length($inc));
			my $ss = substr(($cut_end.$konec_stoki_0),0,10);
			if($ss > $start){
				$hash_prefix{$cut_end} += 1;
				$end = $end - $inc;
			}elsif($ss == $start){
				$hash_prefix{$cut_end} += 1;
				last;
			}else{
				$cut_end = $cut_end.9;
				$hash_prefix{$cut_end} += 1;
				$cut_end = $cut_end -1;
				my $ss = substr(($cut_end.$konec_stoki_9),0,10);
				&mask_pool($start,$ss);
				last;
			}
		}
	}
}

#Функция обновления файлов конфигураций и фиксации изменений в history.
sub diff_file{
	my $dir_file = shift;
	my $tmp_dir_file = shift;
	my $original_file = shift;
	my $diff_file = `diff -u $dir_file/$original_file $tmp_dir_file/${date_time_file}_${original_file}`;
	if ($diff_file ne ''){
		&log_file ("В $url внесены изменения, детали: $history_dir/$date_directory/${date_time_file}_${original_file}.diff");
		`diff -u $dir_file/${original_file} $tmp_dir_file/${date_time_file}_${original_file} > $history_dir/$date_directory/${date_time_file}_${original_file}.diff`;
		`cat $dir_file/${original_file} > $history_dir/$date_directory/${date_time_file}_${original_file}`;
		`cat $tmp_dir_file/${date_time_file}_${original_file} > $dir_file/$original_file`;
	}
	`rm $tmp_dir_file/${date_time_file}_${original_file}`;
}

sub log_file {
	my $error = shift;
	print "$error\n";
	open (my $file_log, '>>:encoding(UTF-8)', "$log_dir/autoparse_rtu.log") || die "Error opening file: autoparse_rtu.log $!";
		print $file_log "$date_script_log\t$error\n";
	close ($file_log);
}
