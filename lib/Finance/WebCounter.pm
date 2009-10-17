package Finance::WebCounter;
use base 'Finance::BankCounter';
use strict;

require WWW::Mechanize;

sub new {
    my ($class) = @_;
    my $me = $class->SUPER::new();

    $me->{mech} = new WWW::Mechanize(
        autocheck => 1,
        onerror => sub { $me->mech_error(@_) }
    );
    $me->{credentials} = ();
    return $me;
}

sub add_credential {
    my ($self, $name, $value) = @_;

    for my $c ($self->required_credentials()) {
        next unless $c eq $name;
        $self->{credentials}{$name} = $value;
        return 1;
    }
    # credential not accepted
    return 0;
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

1;
