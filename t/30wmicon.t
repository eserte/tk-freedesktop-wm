#!perl -w

use strict;
use FindBin;
use Test::More;

use Getopt::Long;

use Tk;
use Tk::FreeDesktop::Wm;

my $interactive;
GetOptions(
	   'interactive' => \$interactive,
	  )
    or die "usage: $0 [-interactive]\n";

my $mw = eval { tkinit };
if (!$mw) {
    plan skip_all => 'Cannot create MainWindow';
} else {
    plan 'no_plan';
}
$mw->geometry("+1+1"); # for twm
$mw->update;
my($wr) = $mw->wrapper;

my $fd = Tk::FreeDesktop::Wm->new;

# Without transparency
$fd->set_wm_icon("$FindBin::RealBin/srtbike16.gif");
$mw->update;
$mw->tk_sleep(0.2);

# With transparency, and setting multiple icons, and using a png image from file
my $p = $mw->Photo(-file => "$FindBin::RealBin/srtbike32.xpm");
$fd->set_wm_icon(["$FindBin::RealBin/srtbike16.gif", $p, "$FindBin::RealBin/srtbike48.png"]);

pass 'set wm icon';

$mw->update;
MainLoop if $interactive;

=head2 tk_sleep

=for category Tk

    $top->tk_sleep($s);

Sleep $s seconds (fractions are allowed). Use this method in Tk
programs rather than the blocking sleep function. The difference to
$top->after($s/1000) is that update events are still allowed in the
sleeping time.

=cut

sub Tk::Widget::tk_sleep {
    my($top, $s) = @_;
    my $sleep_dummy = 0;
    $top->after($s*1000,
                sub { $sleep_dummy++ });
    $top->waitVariable(\$sleep_dummy)
	unless $sleep_dummy;
}

