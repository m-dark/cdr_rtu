#!/usr/bin/perl -w
#########################################################################################################################################################
# Скрипт написал Крук Иван Александрович <kruk.ivan@itmh.ru><--><------><------><------><------><------><------><------><------><------><------><------>#
#########################################################################################################################################################

use strict;
use Cwd;
use warnings;
use Time::Local;
use POSIX qw(strftime);
use Sys::Hostname;
use Data::Dumper;
use utf8;
use LWP::UserAgent;
binmode(STDOUT,':utf8');

my $dir		= '/itmh/scripts';
my $history_dir = "$dir/history";
my $tmp_dir	= '/tmp';
my $log_dir	= '/itmh/log/DEF_sverdl';
my $date_directory = strftime "%Y%m", localtime(time);			#Имя каталога для файлов .diff
my $date_script_log = strftime "%Y-%m-%d %H:%M:%S", localtime(time);	#Время запуска скрипта для лога .log
my $date_time_file = strftime "%Y-%m-%d_%H%M%S", localtime(time);	#Переменная хранит в себе дату и время запуска скрипта, для понимания, когда вносились изменения.
my $login	= 'api';
my $pass	= 'n4ivF60N';
my $host	= 'https://127.0.0.1:8448/mobile_request/get.aspx?admin';
#my $port	= '8448';
my $file	= "$history_dir/regular.cfg";
my $data;
my $name	= $ARGV[0];	#Create
my $table	= $ARGV[1];	#Preroute

if(($name eq 'Create') && ($table eq 'Preroute')){
	if($ARGV[2]){
		$file = $ARGV[2];
	}else{
		$file = "$history_dir/regular.cfg";
	}
}
open (my $file_config, '<:encoding(UTF-8)', "$file") || die "Error opening file: $file $!";
	while (defined(my $line_file_config = <$file_config>)){
		&parser_to_xml($file, $line_file_config);
	}
close($file_config);

sub parser_to_xml{
	my ($file, $string) = @_;
	if($file =~ /regular.cfg$/){
		my $priority = '1700';
		my $name_group = 'block_mobil_sverdl_ktc';
		my $dst_pattern = '^(.*)$';
		my $dst_result = '90002';
		my $string_new = substr($string,1);
		$string_new = "850"."$string_new";
		&create_preroute ($priority, $name_group, $string_new, $dst_pattern, $dst_result);
		$priority = '1690';
		$name_group = 'block_mobil_sverdl';
		$dst_pattern = '^(.*)$';
		$dst_result = '90002';
		&create_preroute ($priority, $name_group, $string, $dst_pattern, $dst_result);
		$priority = '1680';
		$name_group = 'mobil_sverdl';
		$dst_pattern = '^(.*)$';
		$dst_result = '$1';
		&create_preroute ($priority, $name_group, $string, $dst_pattern, $dst_result);
		$priority = '1670';
		$name_group = 'mobil_sverdl_ktc';
		$dst_pattern = '^8(.*)$';
		$dst_result = '850$1';
		&create_preroute ($priority, $name_group, $string, $dst_pattern, $dst_result);
	}elsif($file =~ /regular.cfg.diff$/){
		if($string =~ /^\+\d/){
			$file = 'regular.cfg';
			$string = substr($string,1);
			&parser_to_xml($file, $string);
		}elsif($string =~ /^\-\d/){
			$string = substr($string,1);
			my $name_group = 'block_mobil_sverdl_ktc';
			my $string_new = substr($string,1);
			$string_new = "850"."$string_new";
			&delete_preroute ($name_group, $string_new);
			$name_group = 'block_mobil_sverdl';
			&delete_preroute ($name_group, $string);
			$name_group = 'mobil_sverdl';
			&delete_preroute ($name_group, $string);
			$name_group = 'mobil_sverdl_ktc';
			&delete_preroute ($name_group, $string);
		}
	}
}

sub create_preroute{
	my ($priority, $name_group, $dst_match, $dst_pattern, $dst_result) = @_;
	my @name_count = split (/\(/,$dst_match,-1);
	my $data = <<__TEXT__;
<commands>
    <authorize>
	<login>$login</login>
	<password>$pass</password>
    </authorize>
    <command name="Create" table="Preroute">
	<item>
	    <priority>$priority</priority>
	    <enabled>true</enabled>
	    <name>${name_group}_${name_count[0]}</name>
	    <source_type>user</source_type>
	    <command>Continue</command>
	    <stop_after_this_record>true</stop_after_this_record>
	    <real_src_number>true</real_src_number>
	    <reg_exp_route>true</reg_exp_route>
	    <src_match>^7343[2359][0-9]{6}\$</src_match>
	    <src_pattern>^(.*)\$</src_pattern>
	    <src_result>\$1</src_result>
	    <dst_match>^$dst_match.*</dst_match>
	    <dst_pattern>$dst_pattern</dst_pattern>
	    <dst_result>$dst_result</dst_result>
	    <groups>
		<group>
		    <name>$name_group</name>
		    <enabled>true</enabled>
		</group>
	    </groups>
	</item>
    </command>
</commands>
__TEXT__
&api_rtu($data);
}

sub delete_preroute{
	my ($name_group, $dst_match) = @_;
	my @name_count = split (/\(/,$dst_match,-1);
	my $data = <<__TEXT__;
<commands>
    <authorize>
	<login>$login</login>
	<password>$pass</password>
    </authorize>
    <command name="Delete" table="Preroute">
	<item>
	    <name>${name_group}_${name_count[0]}</name>
	</item>
    </command>
</commands>
__TEXT__
&api_rtu($data);
}

sub api_rtu{
	my $data = shift;
	my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 }, );
	$ua->agent("Kruk/0.1 " . $ua->agent);
	$ua->timeout(60);
	my $req = HTTP::Request->new(POST => "$host");
	$req -> content_type ('text/xml');
#print $data;
	$req -> content ("$data");
	my $res = $ua->request($req);

	print $res->content;
}

#if ($res->is_success) {
#	print $res->as_string;
#} else {
#	print "Failed: ", $res->status_line, "\n";
#}
