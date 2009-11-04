package Finance::PDF2Text;
use strict;

require File::Temp;
require IO::File;

sub new {
    my ($class) = @_;
    my $me = {};
    my $being = bless $me, $class;

    return $being;
}

sub pdf2text {
    my ($self, $pdf) = @_;
    my $f = File::Temp->new(
        TEMPLATE => "pdf2text.XXXXXX",
        TMPDIR => 1,
        UNLINK => 1
    );
    $f->write($pdf);
    $f->close();

    my $output;
    open( PDF, "pdftotext -raw ".$f->filename." - |" );
    while(<PDF>) {
        $output .= $_;
    }
    return $output;
}

1;
