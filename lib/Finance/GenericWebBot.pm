package Finance::GenericWebBot;
use strict;

require WWW::Mechanize;
require Digest::MD5;

sub new {
    my ($class) = @_;
    my $me = {};
    my $being = bless $me, $class;
    $me->{mech} = new WWW::Mechanize(
        autocheck => 1,
        onerror => sub { $being->mech_error(@_) }
    );
    $me->{credentials} = ();
    $me->{mech}->agent_alias("Linux Mozilla");
    return $being;
}

sub add_credential {
    my ($self, $name, $value) = @_;
    # TODO check the credentials name for validity
    $self->{credentials}{$name} = $value;
}

sub credentials_sufficient {
    my ($self) = @_;
    # return whether all credentials are entered
    for my $c ($self->required_credentials()) {
        return 0 unless defined $self->{credentials}{$c};
    }
    return 1;
}

sub required_credentials {
    my ($class) = @_;
    return ();
}

sub init {
    my ($self) = @_;
    my $m = $self->{mech};
    $m->agent_alias("Linux Mozilla");
    $self->login();
}

sub mech_error {
    my ($self, @args) = @_;
    print "WWW::Mechanize error: ", @args, "\n";
    exit 1;
}

sub login {
}

sub statements {
    return ();
}

sub transactions {
    return ();
}

sub create_checksum {
    my ($self, @data) = @_;
    return Digest::MD5::md5_hex(join "", ref $self, $self->{credentials}{id}, @data);
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
