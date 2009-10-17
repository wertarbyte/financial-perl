package Finance::Paypal;
use base "Finance::WebCounter";

require Finance::WebCounter;
require HTML::TreeBuilder;

use strict;

our $start_url = "https://www.paypal.de/";

sub id {
    my ($self) = @_;
    return $self->{credentials}{"e-mail address"};
}

sub required_credentials {
    my ($class) = @_;
    return ("e-mail address", "password");
}

sub login {
    my ($self) = @_;
    $self->SUPER::login();
    my $m = $self->{mech};
    $m->get($start_url);
    $m->follow_link( text => "Einloggen");
    $m->form_name("login_form");
    $m->field( "login_email", $self->{credentials}{"e-mail address"} );
    $m->field( "login_password", $self->{credentials}{"password"} );
    $m->click( 'submit.x' );

    $m->follow_link( url_regex => qr{cmd=_login-done} );
    $m->follow_link( url_regex => qr{cmd=_history} );
    $m->follow_link( url_regex => qr{cmd=_history-download} );
}

sub statements {
    my ($self) = @_;
    my @s = $self->SUPER::statements();
    return @s;
}

sub transactions {
    my ($self, @trans) = @_;
    my @book;
    push @book, $self->SUPER::transactions(@trans);

    my $m = $self->{mech};
    $m->form_name( "form1" );
    $m->field( "from_b", 1 );
    $m->field( "from_a", 1 );
    $m->field( "from_c", 2008 );
    $m->select( "custom_file_type", "tabdelim_allactivity" );
    $m->click("submit.x");
    
    my $csvdata = $m->content();
    print $csvdata, "\n";
    
    my $i = 0;
    for my $line (split /\n/, $csvdata) {
        my @l = split /\t/, $line;
        map {s/(^")|("$)//g} @l;
        if ($i++ == 0) {
            last unless $l[0] eq "Datum";
            next;
        }
        my $date = $l[0];
        $date =~ s/^([0-9]{2})\.([0-9]{2})\.([0-9]{4})$/$3-$2-$1/;
        my $amount = $l[9];
        $amount =~ s/,/./;
        $amount *= 1;

        my $currency = $l[6];
        
        my $description = $l[3].", ".$l[6].": ".$l[15];
        my $entry = $self->construct_transaction( $date, $date, $amount, $description, $currency);
        push @book, $entry;
    }

    $m->back;
    return \@book;
}

1;
