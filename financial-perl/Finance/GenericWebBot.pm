package Finance::GenericWebBot;
use strict;

require WWW::Mechanize;
require Digest::MD5;

sub new {
    my ($class) = @_;
    my $me = {};
    $me->{mech} = new WWW::Mechanize;
    bless $me, $class;
}

sub credentials {
    my ($self, $id, $pin) = @_;
    
    $self->{credentials}{id} = $id if defined $id;
    $self->{credentials}{pin} = $pin if defined $pin;
    return 
        defined $self->{credentials}{id} &&
        defined $self->{credentials}{pin};
}

sub init {
    my ($self) = @_;
    my $m = $self->{mech};
    $m->agent_alias("Linux Mozilla");
    $self->login();
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
    return Digest::MD5::md5_hex(join "", $self->{credentials}{id}, @data);
}

sub construct_transaction {
    my ($self, $receipt, $booked, $amount, $description) = @_;
    my $hash = $self->create_checksum($receipt, $booked, $amount, $description);
    return { checksum => $hash, booked => $booked, desc => $description, amount => $amount, receipt => $receipt };
}

1;
