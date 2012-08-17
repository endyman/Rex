#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Logger - Logging Module

=head1 DESCRIPTION

This module if the logging module. You can define custom logformats.

=head1 SYNOPSIS

 $Rex::Logger::format = '[%D] %s';
 # will output something like
 # [2012-04-12 18:35:12] Installing package vim
    
 $Rex::Logger::format = '%h - %D - %s';
 # will output something like
 # srv001 - 2012-04-12 18:35:12 - Installing package vim

=head1 VARIABLES

=over 4

=cut
 
package Rex::Logger;

use strict;
use warnings;

my $no_color = 0;
eval "use Term::ANSIColor";
if($@) { $no_color = 1; }

# no colors under windows
if($^O =~ m/MSWin/) {
   $no_color = 1;
}

my $has_syslog = 0;
my $log_fh;

=item $debug

Setting this variable to 1 will enable debug logging.

 $Rex::Logger::debug = 1;

=cut
our $debug = 0;

=item $silen

If you set this variable to 1 nothing will be logged.

 $Rex::Logger::silent = 1;

=cut
our $silent = 0;

=item $format

You can define the logging format with the following parameters.

%D - Appends the current date yyyy-mm-dd HH:mm:ss

%h - The target host

%p - The pid of the running process

%l - Loglevel (INFO or DEBUG)

%s - The Logstring

Default is: [%D] %l - %s

=cut

our $format = "[%D] %l - %s";

my $log_opened = 0;

sub init {
   return if $silent;
   eval {
      die if(Rex::Config->get_log_filename || ! Rex::Config->get_log_facility);
      require Sys::Syslog;
      Sys::Syslog->import;
      openlog("rex", "ndelay,pid", Rex::Config->get_log_facility);
      $has_syslog = 1;
   };

   $log_opened = 1;
}

sub info {
   my ($msg, $type) = @_;
   my $color = 'green';

   if (defined($type)) {
     CHECK_COLOR: {
         $type eq 'warn' && do { $color = 'yellow'; last CHECK_COLOR; };
         $type eq 'error' && do { $color = 'red'; last CHECK_COLOR; };
       }
   }

   return if $silent;
   
   $msg = format_string($msg, "INFO");
   # workaround for windows Sys::Syslog behaviour on forks
   # see: #6
   unless($log_opened) {
      init();
      $log_opened = 2;
   }

   if($has_syslog) {
      syslog("info", $msg);
   }
   elsif(Rex::Config->get_log_filename()) {
      open($log_fh, ">>", Rex::Config->get_log_filename()) or die($!);
      flock($log_fh, 2);
      print {$log_fh} "$msg\n" if($log_fh);
      close($log_fh);
   }

   if($no_color) {
      print STDERR "$msg\n" unless($::QUIET);
   }
   else {
      print STDERR colored([$color], "$msg\n") unless($::QUIET);
   }

   # workaround for windows Sys::Syslog behaviour on forks
   # see: #6
   if($log_opened == 2) {
      &shutdown();
   }
}

sub debug {
   my ($msg) = @_;
   return if $silent;
   return unless $debug;

   $msg = format_string($msg, "DEBUG");

   # workaround for windows Sys::Syslog behaviour on forks
   # see: #6
   unless($log_opened) {
      init();
      $log_opened = 2;
   }

   if($has_syslog) {
      syslog("debug", $msg);
   }
   elsif(Rex::Config->get_log_filename()) {
      open($log_fh, ">>", Rex::Config->get_log_filename()) or die($!);
      flock($log_fh, 2);
      print {$log_fh} "$msg\n" if($log_fh);
      close($log_fh);
   }
   
   if($no_color) {
      print STDERR "$msg\n" unless($::QUIET);
   }
   else {
      print STDERR colored(['red'], "$msg\n") unless($::QUIET);
   }

   # workaround for windows Sys::Syslog behaviour on forks
   # see: #6
   if($log_opened == 2) {
      &shutdown();
   }
}

sub get_timestamp {
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   $mon++;
   $year += 1900;

   return "$year-" . sprintf("%02i", $mon) . "-" . sprintf("%02i", $mday) . " " . sprintf("%02i", $hour) . ":" . sprintf("%02i", $min) . ":" . sprintf("%02i", $sec);
}

sub shutdown {
   return if $silent;
   return unless $log_opened;

   if($has_syslog) {
      closelog();
   }
   else {
      close($log_fh) if $log_fh;
   }

   $log_opened = 0;
  
}


# %D - Date
# %h - Host
# %s - Logstring
sub format_string {
   my ($s, $level) = @_;

   my $date = get_timestamp;
   my $host = Rex::get_current_connection() ? Rex::get_current_connection()->{server} : "<local>";
   my $pid = $$;

   my $line = $format;

   $line =~ s/\%D/$date/gms;
   $line =~ s/\%h/$host/gms;
   $line =~ s/\%s/$s/gms;
   $line =~ s/\%l/$level/gms;
   $line =~ s/\%p/$pid/gms;

   return $line;
}

=back

=cut

1;
