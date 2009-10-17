package Finance::BankCounter;
use strict;

require Digest::MD5;

sub new {
    my ($class) = @_;
    my $me = {};
    my $being = bless $me, $class;
    return $being;
}

sub id {
    # overload this method to pass a unique ID for each account
    return 0;
}

sub statements {
    return ();
}

sub transactions {
    return ();
}

sub create_checksum {
    my ($self, @data) = @_;
    return Digest::MD5::md5_hex(join "", ref $self, $self->id(), @data);
}

sub construct_transaction {
    my ($self, $receipt, $booked, $amount, $description, $currency) = @_;
    $currency = "EUR" unless defined $currency;
    my $hash = $self->create_checksum($receipt, $booked, $amount, $description, $currency);
    return { checksum => $hash, booked => $booked, desc => $description, amount => $amount, receipt => $receipt, currency => $currency };
}

sub csv {
    my ($self, @args) = @_;
    return $self->formatted_output("csv", @args);
}

sub qif {
    my ($self, @args) = @_;
    return $self->formatted_output("qif", @args);
}

sub formatted_output {
    my ($self, $format, @args) = @_;
    my $data = "";
    
    for my $entry ( @{ $self->transactions( @args ) } ) {
        my $sign = ($entry->{amount} < 0) ? '-' : '+';
        my $val = sprintf("% 8.2f %s", abs $entry->{amount}, $entry->{currency});
        $val =~ y/./,/;
        if ($format eq "csv") {
            $data .= $entry->{checksum}."\t".$entry->{booked}."\t".$entry->{receipt}."\t".$sign."\t".$val."\t".$entry->{desc}."\n";
        }
        elsif ($format eq "qif") {
            $data .= "!Type:CCard\n";
            $data .= "D".$entry->{booked}."\n";
            $data .= "P".$entry->{desc}."\n";
            $data .= "T".$sign.sprintf("%.2f", abs($entry->{amount}))."\n";
            $data .= "^\n";
        }
    }

    return $data;
}

1;
