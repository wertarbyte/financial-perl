package Finance::Barclaycard;
use base "Finance::WebCounter";

use strict;

require HTML::TreeBuilder::XPath;

our $start_url = "https://www.barclaycard.de/";

sub id {
    my ($self) = @_;
    return $self->{credentials}{"Online ID"};
}

sub required_credentials {
    return ("Online ID", "PIN", "Surname", "Password");
}

sub login {
    my ($self) = @_;
    $self->SUPER::login();
    my $m = $self->{mech};
    
    $m->get($start_url);
    $m->follow_link( url_regex => qr/login\.php\?page=CSP1\.0/ );
    
    my $data = $m->content();

    $m->form_name("FORM1");

    $m->field("F_CSP1_0_FE_LOGIN_ID", $self->{credentials}{"Online ID"});
    $m->field("F_CSP1_0_FE_LOGIN_NAME", $self->{credentials}{"Surname"});
    $m->field("F_CSP1_0_FE_LOGIN_PIN", $self->{credentials}{"PIN"});

    while ( $data =~ /for="(F_CSP1_0_FE_LOGIN_MEMWORD[12])">Stelle Nr\. ([0-9]+)<\/label>/g) {
        $m->field($1, substr($self->{credentials}{"Password"}, $2-1, 1));
    }

    $m->submit();

    $m->follow_link( text => "HERE" );
}

sub extract_transactions {
    my ($self) = @_;
    my $data = $self->{mech}->content();
    #print $data;

    my @book;
    my $tree = new HTML::TreeBuilder::XPath;

    $tree->parse($data);
   
    my $path = '//table[@class="umsaetze"]/tbody/tr/td';
    my $col = 0;
    my @set;
    for my $node ( $tree->findnodes($path) ) {
        my $t = $node->as_trimmed_text();
        if ($col == 0 || $col == 1) {
            $t =~ s/([0-9]{2})\.([0-9]{2})\.([0-9]{2})/20\3-\2-\1/;
            $set[$col] = $t;
        } elsif ($col == 2) {
            $set[3] = $t;
        } elsif ($col == 3) {
            $t =~ s/[.,]//g;
            my ($amount, $sign) = ($t =~ m/([0-9]+)([^[:digit:]]+)/);
            $amount /= 100;
            $amount *= -1 unless ($sign eq "+");
            $set[2] = $amount;

            push @book, $self->construct_transaction( @set );
        }
        $col = ($col+1)%4;
    }

    return @book;
}

sub statements {
    my ($self) = @_;
    my @statements;
    push @statements, $self->SUPER::statements();

    my @statements;
    push @statements, "current";
    return @statements;
}

sub transactions {
    my ($self, @labels) = @_;
    my @transactions;
    push @transactions, $self->SUPER::transactions(@labels);
    my $m = $self->{mech};

    my %fetch;
    LABEL: for my $l (@labels) {
        if ($l eq "default") {
            $fetch{current} = 1;
            next LABEL;
        }
        $fetch{$l} = 1;
    }
    $m->follow_link( text_regex => qr/Konto anzeigen/ );

    if ($fetch{current} || $fetch{all}) {
        $m->follow_link( text_regex => qr/seit der letzten Konto.+bersicht/ );
        push @transactions, $self->extract_transactions();
        $fetch{current} = 0;
    }

    $fetch{all} = 0 if defined $fetch{all};
    
    # any statements left?
    for my $k (keys %fetch) {
        next unless $fetch{$k};
        print STDERR "Unable to retrieve data for '$k'.\n";
    }

    return [ sort {$a->{booked} cmp $b->{booked}} @transactions ];
}

1;
