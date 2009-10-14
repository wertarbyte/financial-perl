package Finance::MercedesBenzBank;
use base "Finance::GenericWebBot";

require HTML::TreeBuilder;
require Unicode::String;

use strict;

our $start_url = "https://www.mercedes-benz-bank.de/";

sub required_credentials {
    return ("customer number", "PIN", "account number");
}

sub login {
    my ($self) = @_;
    $self->SUPER::login();
    my $m = $self->{mech};
    $m->get($start_url);
    $m->follow_link( text => "Login Online Banking");
    $m->form_number(2);
    $m->field( "username", $self->{credentials}{"customer number"} );
    $m->field( "password", $self->{credentials}{"PIN"} );
    $m->click( '$$event_login' );
    my $acc = $self->{credentials}{"account number"};
    $m->follow_link( url_regex => qr/accountNo=\Q$acc\E/ );
}

sub credentials {
    my ($self, $id, $pin, $account) = @_;
    $self->{credentials}{account} = $account if defined $account;

    return $self->SUPER::credentials($id, $pin) &&
           defined $account;
}

sub statements {
    my ($self) = @_;
    my @s = $self->SUPER::statements();
    return (@s, "48");
}

our %key_table = (
    valutaDate => "booked",
    description => "desc",
    value  => "amount"
);

sub transactions {
    my ($self, @trans) = @_;
    my @book;
    push @book, $self->SUPER::transactions(@trans);

    my $m = $self->{mech};
    #$m->form_with_fields( "period" );
    $m->form_number( 3 );
    $m->set_visible( [ option => "48 Monate" ] );
    $m->click( '$$event_refresh' );
    $m->follow_link( text_regex => qr{Drucken} );
    

    my $tree = new HTML::TreeBuilder;
    $tree->parse($m->content);
    my @rows = $tree->look_down( _tag => "tr", class => qr{(even|odd)-row} );
    for my $r (@rows) {
        my %t;
        for my $c ( $r->look_down( _tag => "td" ) ) {
            my $content = Unicode::String::latin1($c->as_trimmed_text)->utf8;
            my ($key) = ($c->attr('headers') =~ m/^[^:]+:(.*)$/);
            if (defined $key_table{$key}) {
                if ($key eq "valutaDate") {
                    $content =~ s/([0-9]{2})\.([0-9]{2})\.([0-9]{4})/\3-\2-\1/;
                }
                if ($key eq "description") {
                }
                if ($key eq "value") {
                    # convert value to a true number
                    $content =~ s/ EUR$//;
                    $content =~ s/\.//g;
                    $content =~ s/,/./g;
                    $content *= 1;
                }
                $t{ $key } = $content;
            }
        }
        push @book, $self->construct_transaction( $t{valutaDate}, $t{valutaDate}, $t{value}, $t{description} );
    }
    return \@book;
}

1;
