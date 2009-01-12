package Finance::Paypal;
require Finance::GenericWebBot;
require HTML::TreeBuilder;
@ISA = ("Finance::GenericWebBot");

use strict;

our $start_url = "https://www.paypal.de/";

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
    $m->field( "login_email", $self->{credentials}{id} );
    $m->field( "login_password", $self->{credentials}{pin} );
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
    $m->field( "from_c", 2000 );
    $m->select( "custom_file_type", "tabdelim_allactivity" );
    $m->click("submit.x");
    
    my $csvdata = $m->content();
    
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

        my $currency = $l[7];
        
        my $description = $l[4].", ".$l[5].": ".$l[16];
        my $entry = $self->construct_transaction( $date, $date, $amount, $description, $currency);
        push @book, $entry;
    }

    $m->back;
    return \@book;
}

1;
