package Finance::Barclaycard;
require Finance::GenericWebBot;
@ISA = ("Finance::GenericWebBot");

use strict;

require HTML::TreeBuilder;
require Digest::MD5;

our $start_url = "https://www.barclaycard.de/";

sub credentials {
    my ($self, $id, $pin, $surname, $password) = @_;
    
    $self->{credentials}{surname} = $surname if defined $surname;
    $self->{credentials}{password} = $password if defined $password;

    return 
        $self->SUPER::credentials($id, $pin) &&
        defined $self->{credentials}{surname} &&
        defined $self->{credentials}{password};
}

sub init {
    my ($self) = @_;
    $self->SUPER::init();
}

sub login {
    my ($self) = @_;
    my $m = $self->{mech};
    
    $m->get($start_url);
    $m->follow_link( text => "Online-Kundenservice" );


    $m->submit_form(
        form_name => "FORM1",
        fields    => {
            F_CSP1_1_FE_LOGIN_ID   => $self->{credentials}{id},
            F_CSP1_1_FE_LOGIN_NAME => $self->{credentials}{surname},
        }
    );
    
    my $data = $m->content();
    my @mem; 
    while ( $data =~ /(for="F_CSP1_2_FE_LOGIN_MEMWORD([12])">Stelle Nr\. ([0-9]+)<\/label>)/g) {
        $mem[$2-1] = substr($self->{credentials}{password}, $3-1, 1);
    }

    $m->submit_form( 
        form_name => "FORM1",
        fields    => {
            F_CSP1_2_FE_LOGIN_PIN => $self->{credentials}{pin},
            F_CSP1_2_FE_LOGIN_MEMWORD1 => $mem[0],
            F_CSP1_2_FE_LOGIN_MEMWORD2 => $mem[1]
        }
    );  

    $m->follow_link( text => "HERE" );
}

sub extract_transactions {
    my ($self) = @_;
    my $data = $self->{mech}->content();
    # fix typo of barclays
    $data =~ s/<dv /<div /g;

    my @book;
    my $tree = new HTML::TreeBuilder;

    $tree->parse($data);

    for my $table ( $tree->look_down( "_tag" => "table", "class" => "transActList" ) ) {
        my @rows = ( $table->look_down( "_tag" => "tr", "valign" => "top", "class" => qr/odd|even/ ) );
        for my $row ( @rows ) {
            my ($receipt, $booked, $desc, $value);
            my @cells = ( $row->look_down( "_tag" => "td" ) );
            if ($#cells == 2) {
                ($receipt, $desc, $value) = map { $_->as_trimmed_text; } @cells;
                $booked = $receipt;
            } elsif ($#cells == 3) {
                ($receipt, $booked, $desc, $value) = map { $_->as_trimmed_text; } @cells;
            } else {
                next;
            }
            # change date format to simplify sorting (let's hope we won't still use this script in 100 years)
            $receipt =~ s/([0-9]{2})\.([0-9]{2})\.([0-9]{2})/20\3-\2-\1/;
            $booked =~ s/([0-9]{2})\.([0-9]{2})\.([0-9]{2})/20\3-\2-\1/;
            $value =~ s/[.,]//g;
            my ($amount, $sign) = ($value =~ m/([0-9]+)([^[:digit:]]+)/);
            $amount /= 100;
            $amount *= -1 unless ($sign eq "+");
            #push @book, { md5 => Digest::MD5->md5_hex($receipt.$booked.$desc.$amount), receipt => $receipt, booked => $booked, desc => $desc, amount => $amount };
            push @book, $self->construct_transaction( $receipt, $booked, $amount, $desc );
        }
    }
    return @book;
}

sub statements {
    my ($self) = @_;

    my $m = $self->{mech};
    my @statements;
    push @statements, "current", "latest";
    $m->follow_link( text => "Umsätze seit dem letzten Kontoauszug" );
    $m->follow_link( text => "Vorherige Kontoauszüge" );
    my $page = $m->content();
    while ($page =~ m!<option value="[0-9]+">([0-9]{4}-[0-9]{2})</option>!g) {
        push @statements, $1;
    }
    return @statements;
}

sub transactions {
    my ($self, @labels) = @_;
    my @transactions;
    my $m = $self->{mech};

    my %fetch;
    LABEL: for my $l (@labels) {
        if ($l eq "default") {
            $fetch{current} = 1;
            $fetch{latest} = 1;
            next LABEL;
        }
        $fetch{$l} = 1;
    }
    $m->follow_link( text => "Umsätze seit dem letzten Kontoauszug" );

    if ($fetch{current} || $fetch{all}) {
        $m->follow_link( text => "Umsätze seit dem letzten Kontoauszug" );
        push @transactions, $self->extract_transactions();
        $fetch{current} = 0;
    }
    if ($fetch{latest} || $fetch{all}) {
        $m->follow_link( text => "Letzter Kontoauszug" );
        push @transactions, $self->extract_transactions();
        $fetch{latest} = 0;
    }
    
    for my $k (keys %fetch) {
        next unless $fetch{$k};
        # if there are still unfetched statements, we have to check all of them
        $m->follow_link( text => "Vorherige Kontoauszüge" );
        my $page = $m->content();
        while ($page =~ m!<option value="[0-9]+">([0-9]{4}-[0-9]{2})</option>!g) {
            my $date = $1;
            next unless ($fetch{all} || $fetch{$date});
            $m->form_name("FORM1");
            $m->select("F_C2_2_FE_STATEMENT_DATE", $date);
            $m->submit();
            push @transactions, $self->extract_transactions();
            $fetch{$date} = 0;
        }
    }

    $fetch{all} = 0 if defined $fetch{all};
    
    # any statements left?
    for my $k (keys %fetch) {
        next unless $fetch{$k};
        print STDERR "Unable to retrieve data for '$k'.\n";
    }

    print STDERR "returning $#transactions transactions\n";
    return [ sort {$a->{booked} cmp $b->{booked}} @transactions ];
}

1;
