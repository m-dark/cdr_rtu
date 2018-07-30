#!/usr/bin/perl -w
#########################################################################################################################################################
# Скрипт написал Крук Иван Александрович <kruk.ivan@itmh.ru>												#
# CDR РТУ содержит поля: cdr_id;connect_time;disconnect_time;elapsed_time;src_in;dst_in;call_id_in_proto;remote_src_sig_address;remote_dst_sig_address;	#
# В итоговый CDR для CORDIS добавляем 4-е дополнительных параметра:											#
#	7 Город: (ekb|ntagil|ku|unk)															#
#	8 Целевой оператор - идентификатор оператора, который осуществляет транзит звонка: unk								#
#	9 Стык - идентификатор стыка, через который ушел вызов: unk											#
#	10 КТЦ - булевое значение определяющее наличие на номере 8-ки по агентской схеме: 1								#
#																			#
#	!!!!!!Внимание!!!!!  Для корректного определения города, необходимо добавить в массивы @pool_number_XXX все пулы номеров Комтехцентра		#
#########################################################################################################################################################

use strict;
use Cwd;
use warnings;
use Time::Local;
use POSIX qw(strftime);
use File::Find;
use File::Find qw(finddepth);
use Sys::Hostname;
use Data::Dumper;
use File::Copy;
use Net::FTP;

my $dir_cdr = '/itmh/data/cdr';				#Путь до cdr-файлов, которые выгружаются средствами РТУ. настройка, через web-интерфейс.
my $dir_cdr_transformation = '/itmh/data/cdr_new';	#Путь до преобразованных cdr-файлов, которые в итоге будут загружены на FTP.
my $dir_cdr_old = '/itmh/data/cdr_old';			#Путь до оригинальных файлов cdr, которые были преобразованны ранее. (для истории оставляем).
my $ftp_server = '172.16.80.149';
my $ftp_login = 'ftp-user';
my $ftp_password = 'zxcvbnm';
my %hash_pool_number_all = ();
my %hash_redirects = (
			''		=> '0', #(пустое поле - нет переадресации)
			'unconditional' => '1', #(безусловная переадресация)
			'user-busy'	=> '2', #(по занятости)
			'no-answer'	=> '3', #(по не ответу)
			'unknown'	=> '4', #(неизвестная)
			'unavailable'	=> '5', #(недоступен)
			'time-of-day'	=> '6', #(по времени)
			'do-not-disturb'=> '7', #(не беспокоить)
			'deflection'	=> '8', #(отклонение)
			'follow-me'	=> '9', #(следуй за мной)
			'out-of-service'=> '10',#(отказ в обслуживании)
			'away'		=> '11',#
			);
my @pool_number_ekb = (
			'73433790000-73433790999',
			'73433573000-73433573399',
			'73433856500-73433856999',
			'73433857000-73433859999',
			'73433277000-73433279999',
			'73432957000-73432957039',
			'73432957300-73432957399',
			'73432958200-73432958299'
			);
my @pool_number_ntg = ('73435378100-73435378299','73435384400-73435384699','73435219000-73435219999');
my @pool_number_kur = ('73439540500-73439540999','73439541000-73439541999');

&add_pool_hash(\@pool_number_ekb);
&add_pool_hash(\@pool_number_ntg);
&add_pool_hash(\@pool_number_kur);

chdir "$dir_cdr" or die "No open $dir_cdr $!";
my @dir_cdr_files = glob "*.csv";
@dir_cdr_files = sort @dir_cdr_files;

foreach my $dir_cdr_file (@dir_cdr_files){
#	my $new_file_name = "bil_".substr($dir_cdr_file,4,4)."_".substr($dir_cdr_file,8,2)."_".substr($dir_cdr_file,10,2)."_".substr($dir_cdr_file,13,2)."_".substr($dir_cdr_file,15,2)."_".substr($dir_cdr_file,17,2);
	my $new_file_name = "rtu_".substr($dir_cdr_file,4,15).".csv";
	open (FILE, "< $dir_cdr/$dir_cdr_file")|| die "Error opening file: $dir_cdr_file $!";
	open (FILE_NEW, ">> $dir_cdr_transformation/$new_file_name")|| die "Error opening file: $new_file_name $!";
		while (my $str = <FILE>) {
			if($str !~ /^\d{18}/){
				next;
			}else{
				chomp ($str);
				my @array_str_cdr = split(/,/,$str);
				if ($array_str_cdr[1] eq ''){
					next;
				}elsif (($array_str_cdr[8] =~ /^172.31.255.1/) || ($array_str_cdr[9] =~ /^172.31.255.1/)){
					next;
				}else{
					my @array_ip_port_a = split (/:/,$array_str_cdr[8],-1);
					$array_str_cdr[8] = $array_ip_port_a[0];
					my @array_ip_port_b = split (/:/,$array_str_cdr[9],-1);
					$array_str_cdr[9] = $array_ip_port_b[0];
					print FILE_NEW "$array_str_cdr[0],$array_str_cdr[1],$array_str_cdr[2],$array_str_cdr[3],$array_str_cdr[4],$array_str_cdr[5],$hash_pool_number_all{$array_str_cdr[4]},unk,unk,1,$array_str_cdr[6],$hash_redirects{$array_str_cdr[7]},$array_str_cdr[8],$array_str_cdr[9]\n";
				}
			}
		}
	close(FILE_NEW);
	close(FILE);
	`cat $dir_cdr/$dir_cdr_file > $dir_cdr_old/$dir_cdr_file`;
	`rm $dir_cdr/$dir_cdr_file`;
}
chdir "$dir_cdr_transformation" or die "No open $dir_cdr_transformation $!";
my @cdr_files_put = glob "*.csv";

my $ftp = Net::FTP->new("$ftp_server", Timeout => 30, Debug => 0) || die "Can't connect to ftp server $ftp_server\n";
$ftp->login("$ftp_login", "$ftp_password") || die "Can't login to ftp server.\n";
#$ftp->cwd("переход в директорию") || die "Path $cfg_remote_path not found on ftp server.\n";
$ftp->binary();
foreach my $cdr_file_put (@cdr_files_put){
	my $file_size = -s "$cdr_file_put";
	$ftp->put("$dir_cdr_transformation/$cdr_file_put", "$cdr_file_put");
	my $ftp_file_size = $ftp->size($cdr_file_put);
	if($file_size == $ftp_file_size){
		`rm $dir_cdr_transformation/$cdr_file_put`;
	}else{
		print "Error_03\n";
	}
}
$ftp->quit();

sub add_pool_hash {
	my ($array_pool_number) = @_;
	for my $pool (@$array_pool_number) {
		if ($pool =~ /-/){
			my @array_number_pool = split(/-/,$pool);
			if ($array_number_pool[0] =~ /^7343[23]\d{6}$/){
				&add_number_hash($array_number_pool[0], $array_number_pool[1], 'ekb');
				&add_number_hash(substr($array_number_pool[0],4,7), substr($array_number_pool[1],4,7), 'ekb');
			}elsif($array_number_pool[0] =~ /^73435\d{6}$/){
				&add_number_hash($array_number_pool[0], $array_number_pool[1], 'ntagil');
				&add_number_hash(substr($array_number_pool[0],5,6), substr($array_number_pool[1],5,6), 'ntagil');
			}elsif($array_number_pool[0] =~ /^73439\d{6}$/){
				&add_number_hash($array_number_pool[0], $array_number_pool[1], 'ku');
				&add_number_hash(substr($array_number_pool[0],5,6), substr($array_number_pool[1],5,6), 'ku');
			}else{
				print "Error_01\n";
			}
		}else{
			if ($pool =~ /^7343[23]\d{6}$/){
				$hash_pool_number_all{$pool} = 'ekb';
			}elsif ($pool =~ /^73435\d{6}$/){
				$hash_pool_number_all{$pool} = 'ntagil';
			}elsif ($pool =~ /^73439\d{6}$/){
				$hash_pool_number_all{$pool} = 'ku';
			}else{
				print "Error_02\n";
				$hash_pool_number_all{$pool} = 'unk';
			}
		}
	}
}

sub add_number_hash {
	my $number_start = shift;
	my $number_end   = shift;
	my $town 	 = shift;
	
	while ($number_start <= $number_end){
		$hash_pool_number_all{$number_start} = $town;
		$number_start++;
	}
}
