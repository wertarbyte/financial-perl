#!/usr/bin/perl

use strict;
use FindBin;
use lib "$FindBin::Bin/";

use Finance::Barclaycard;
use Finance::SantanderCC;
use Finance::MercedesBenzBank;
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

@statements = split(/,/,join(',',@statements));
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
    mercedesbenzbank => "Finance::MercedesBenzBank",
    santandercc => "Finance::SantanderCC"
);

unless (defined $mods{$module}) {
    print STDERR "Unknown module '$module'.\n";
    exit 1;
}

unless (lc $output_format eq "csv" || lc $output_format eq "qif") {
    print STDERR "Unknown output format '$output_format'.\n";
    exit 1;
}

my $cc = $mods{$module}->new;
unless ($cc->credentials( @credentials )) {
    print STDERR "Insufficient credentials for this Module.\n";
    print STDERR "Either specify --credentials or feed them through STDIN using --read-credentials.\n";
    exit 1;
}
$cc->init();

if (lc $output_format eq "csv") {
    print $cc->csv(@statements);
} elsif (lc $output_format eq "qif") {
    print $cc->qif(@statements);
}
