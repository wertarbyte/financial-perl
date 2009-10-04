package Finance::SantanderCC;
require Finance::GenericWebBot;
@ISA = ("Finance::GenericWebBot");

use strict;

our $start_url = "https://www.kreditkartenbanking.de/santander";

sub required_credentials {
    my ($class) = @_;
    return ("cardnumber", "PIN");
}

sub __fix_links {
    my $m = shift;
    my $data = $m->content();
    $data =~ s!="(dispatch\.do;[^"]+)"!="./\1"!g;
    $m->update_html($data);
}

sub login {
    my ($self) = @_;
    $self->SUPER::login();
    my $m = $self->{mech};

    $m->get($start_url);

    $m->form_name("preLogonForm");
    __fix_links $m;

    $m->field("user", $self->{credentials}{id} );
    $m->field("password", $self->{credentials}{pin});
    $m->click_button( name => "bt_LOGON");

    __fix_links $m;

    $m->follow_link( url_regex => qr/bt_SERVICECALL=do/ );
    __fix_links $m;
    $m->form_name("service");
    $m->submit();

    __fix_links $m;
}

sub extract_transactions {
    my ($self) = @_;
    my $data = $self->{mech}->content();
    
    my $tree = HTML::TreeBuilder->new;
    $tree->parse($data);

    my @book;

    my @rows = ( $tree->look_down( "_tag" => 'tr', "class" => qr/tabdata2?/ ) );
    my $i=0;
    my ($booked, $receipt, $desc, $value);
    for my $r (@rows) {
        my @cells = $r->look_down( "_tag" => 'td' );
        next unless $#cells == 3;
        if ($i++ % 2 == 0) {
            my $sign;
            ($booked, $desc, $value, $sign) = map { $_->as_trimmed_text() } @cells;
            $value =~ s/,/./;
            $value *= ($sign eq "-") ? -1 : 1;
        } else {
            $receipt = $cells[0]->as_trimmed_text();
            #push @book, { md5 => Digest::MD5->md5_hex($receipt.$booked.$desc.$value), booked => $booked, desc => $desc, amount => $value, receipt => $receipt};
            push @book, $self->construct_transaction( $receipt, $booked, $value, $desc );
        }
    }

    return @book;
}

sub statements {
    my ($self) = @_;
    my @s;
    push @s, $self->SUPER::statements();
    push @s, "current";
    my $m = $self->{mech};
    $m->follow_link( url_regex => qr/bt_STMTLIST=do/ );
    __fix_links($m);
    my $data = $m->content();
    while ($data =~ m!<a href="(\./dispatch\.do.+bt_STMT=do)">([0-9]{2}\.[0-9]{2}\.[0-9]{4})</a>!g) {
        push @s, $2;
    }
    return @s;
}

sub transactions {
    my ($self, @labels) = @_;
    my @transactions;
    push @transactions, $self->SUPER::transactions();
    my $m = $self->{mech};

    my %fetch;
    LABEL: for my $l (@labels) {
        if ($l eq "default") {
            $fetch{current} = 1;
            next LABEL;
        }
        $fetch{$l} = 1;
    }

    if ($fetch{current} || $fetch{all}) {
        $m->follow_link( url_regex => qr/bt_TXN=do/ );
        __fix_links($m);
        push @transactions, $self->extract_transactions();
        $fetch{current} = 0;
    }

    for my $k (keys %fetch) {
        next unless $fetch{$k};

        $m->follow_link( url_regex => qr/bt_STMTLIST=do/ );
        __fix_links($m);
        my $data = $m->content();
        while ($data =~ m!<a href="(\./dispatch\.do.+bt_STMT=do)">([0-9]{2}\.[0-9]{2}\.[0-9]{4})</a>!g) {
            my ($url, $date) = ($1, $2);
            next unless ($fetch{all} || $fetch{$date});
            $m->follow_link( text => $date );
            push @transactions, $self->extract_transactions();
            $fetch{$date} = 0;
            $m->back();
        }
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
