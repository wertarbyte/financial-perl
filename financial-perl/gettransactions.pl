#!/usr/bin/perl

use strict;
use Finance::Barclaycard;
use Finance::SantanderCC;
use Data::Dumper;
use Getopt::Long;

my $module;

my @credentials;
my $read_credentials = 0;

my @statements = ();
my $output_format = "csv";
my $list_statements = 0;

my $result = GetOptions (
    "m|module=s"     => \$module,
    "credentials=s"  => \@credentials,
    "read-credentials" => \$read_credentials,
    "l|list"       => \$list_statements,
    "format|f=s"   => \$output_format,
    "s|statements=s" => \@statements
);

push @statements, "default" unless @statements;

@credentials = split(/,/,join(',',@credentials));

if ($read_credentials) {
    while (<STDIN>) {
        chop;
        push @credentials, $_;
    }
}

my %mods = (
    barclaycard => "Finance::Barclaycard",
    santandercc => "Finance::SantanderCC"
);

unless (defined $mods{$module}) {
    print STDERR "Unknown module '$module'.\n";
    exit 1;
}
unless (@credentials) {
    print STDERR "I need your credentials! Either specify --credentials or feed them through STDIN using --read-credentials.\n";
    exit 1;
}

unless (lc $output_format eq "csv" || lc $output_format eq "qif") {
    print STDERR "Unknown output format '$output_format'.\n";
    exit 1;
}

my $cc = $mods{$module}->new;
$cc->credentials( @credentials );
$cc->init();

my @transactions;
push @transactions, @{ $cc->transactions( @statements ) };

for my $entry ( @transactions ) {
    my $val = sprintf("% 8.2f EUR", abs $entry->{amount});
    $val =~ y/./,/;
    my $sign = ($entry->{amount} < 0) ? '-' : '+';
    if (lc $output_format eq "csv") {
        print $entry->{checksum}."\t".$entry->{booked}."\t".$entry->{receipt}."\t".$sign."\t".$val."\t".$entry->{desc}."\n";
    } elsif (lc $output_format eq "qif") {
        print "!Type:CCard\n";
        print "D".$entry->{booked}."\n";
        print "P".$entry->{desc}."\n";
        print "T".$sign.sprintf("%.2f", abs($entry->{amount}))."\n";
        print "^\n";
    }
}
