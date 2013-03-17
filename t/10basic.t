use strict;
use FindBin;
use Test::More qw(no_plan);

use Tk;
use Tk::FreeDesktop::Wm;
use Getopt::Long;

use vars qw($DEBUG);
$DEBUG = 0;
GetOptions("d|debug" => \$DEBUG)
    or die "usage: $0 [-debug]\n";

my $mw = tkinit;
$mw->update;
my($wr) = $mw->wrapper;

my $fd = Tk::FreeDesktop::Wm->new(mw => $mw);
isa_ok($fd, "Tk::FreeDesktop::Wm");
my @supported = $fd->supported;
warn "@supported\n" if $DEBUG;
my %supported = map {($_,1)} @supported;
SKIP: {
    skip("Probably not a freedesktop compliant wm", 1) # XXX no of tests
	if !@supported;

    my @windows;

    if (0) { # no effect on metacity:
	my $t = $mw->Toplevel;
	for my $type (qw(_NET_WM_WINDOW_TYPE_DESKTOP
			 _NET_WM_WINDOW_TYPE_DIALOG
			 _NET_WM_WINDOW_TYPE_DOCK
			 _NET_WM_WINDOW_TYPE_MENU
			 _NET_WM_WINDOW_TYPE_NORMAL
			 _NET_WM_WINDOW_TYPE_TOOLBAR
		       )) {
	    diag "Try $type...";
	    $fd->set_window_type($type, $t);
	    $t->update;
	    system("(echo $type; xprop -id " . $t->id . ") >>/tmp/xprop.log &");
	    $t->after(1000);
	}
    }

    my $wm_name;
 SKIP: {
	skip("_NET_SUPPORTING_WM_CHECK not supported", 2)
	    if !$supported{_NET_SUPPORTING_WM_CHECK};
	my $ret = $fd->supporting_wm;
	is(ref($ret), "HASH", "Got a return value");
	$wm_name = $ret->{name};
	ok(defined $wm_name, "You're running $wm_name");
    }

 SKIP: {
	skip("_NET_CLIENT_LIST not supported", 1)
	    if !$supported{_NET_CLIENT_LIST};

	@windows = $fd->client_list;
	ok((grep { $wr eq $_ } @windows),
	   "At least our window's wrapper should list here")
	    or diag "@windows";
    }

 SKIP: {
	skip("_NET_CLIENT_LIST_STACKING not supported", 2)
	    if !$supported{_NET_CLIENT_LIST_STACKING};

	$mw->raise;
	$mw->update;
	@windows = $fd->client_list_stacking;
	ok((grep { $wr eq $_ } @windows),
	   "At least our window's wrapper should list here")
	    or diag "@windows";

	{
	    local $TODO = "Well, if there's no on-top window...";
	    
	    is($windows[-1], $wr,
	       "Our window's wrapper should be on top")
		or diag "@windows";
	}
    }

    my $no_desktops;
 SKIP: {
	skip("_NET_NUMBER_OF_DESKTOPS not supported", 2)
	    if !$supported{_NET_NUMBER_OF_DESKTOPS};

	$no_desktops = $fd->number_of_desktops;
	cmp_ok($no_desktops, ">=", 1, "At minimum one desktop: $no_desktops");

	$fd->set_number_of_desktops($no_desktops + 1);
	$mw->update;
	# The wm may ignore this
	$fd->set_number_of_desktops($no_desktops);
	$mw->update;
	# But now we should be at the old number again
	my $no_desktops2 = $fd->number_of_desktops;
	is($no_desktops, $no_desktops2, "Same desktop number again: $no_desktops");
    }

 SKIP: {
	skip("_NET_DESKTOP_GEOMETRY not supported", 2)
	    if !$supported{_NET_DESKTOP_GEOMETRY};
	my($dw,$dh) = $fd->desktop_geometry;
	cmp_ok($dw, ">=", $mw->screenwidth, "Desktop geometry width");
	cmp_ok($dh, ">=", $mw->screenheight, "Desktop geometry height");
    }

 SKIP: {
	skip("_NET_DESKTOP_VIEWPORT not supported", 2)
	    if !$supported{_NET_DESKTOP_VIEWPORT};

	my($vx,$vy) = $fd->desktop_viewport;
	ok(defined $vx, "Viewport X");
	ok(defined $vy, "Viewport Y");

	$fd->set_desktop_viewport(10, 10);
	$fd->set_desktop_viewport($vx, $vy);
    }

    if (0) {
	local $TODO = "fvwm 2.5.16 claims to support it, but fails!";
	warn $fd->desktop_names;
    }

 SKIP: {
	skip("_NET_ACTIVE_WINDOW not supported", 1)
	    if !$supported{_NET_ACTIVE_WINDOW};

	my($oldx,$oldy) = ($mw->rootx, $mw->rooty);
	my($px,$py) = $mw->pointerxy;
	# feels hacky...
	$mw->geometry("+".($px-10)."+".($py-10));
	$mw->focus;
	$mw->update;
	is($fd->active_window, $wr, "This window is the active one");
	$mw->geometry("+$oldx+$oldy");
    }

 SKIP: {
	skip("_NET_CURRENT_DESKTOP not supported", 2)
	    if !$supported{_NET_CURRENT_DESKTOP};

	my $cd = $fd->current_desktop;
	cmp_ok($cd, ">=", 0, "Current desktop is $cd");

    SKIP: {
	    skip("No number of desktops", 1)
		if !defined $no_desktops;
	    cmp_ok($cd, "<", $no_desktops, "Smaller than number of desktops");
	}
    }

 SKIP: {
	skip("_NET_WORKAREA not supported", 2)
	    if !$supported{_NET_WORKAREA};
	my($x,$y,$x2,$y2) = $fd->workarea;
	ok(defined $x);
	ok(defined $y2);
    }

 SKIP: {
	skip("_NET_VIRTUAL_ROOTS not supported", 0)
	    if !$supported{_NET_VIRTUAL_ROOTS};
	my(@w) = $fd->virtual_roots;
	# no test here
    }

    {
	# Without transparency
	$fd->set_wm_icon("$FindBin::RealBin/srtbike16.gif");
	$mw->update;
	$mw->tk_sleep(0.2);
	# With transparency, and setting multiple icons, and using a png image from file
	use Tk::PNG;
	my $p = $mw->Photo(-file => "$FindBin::RealBin/srtbike48.png");
	$fd->set_wm_icon(["$FindBin::RealBin/srtbike16.gif", "$FindBin::RealBin/srtbike32.xpm", $p]);
    }

    # XXX SKIP?
    {
	warn join(",", $fd->wm_desktop); # XXX???
	# XXX equals current desktop?
    }

    # XXX SKIP?
    {
	warn join(",", $fd->wm_state); # XXX???
    }

    # XXX SKIP?
    {
	warn join(",", $fd->wm_visible_name); # XXX???
    }

    # XXX SKIP?
    {
	warn join(",", $fd->wm_window_type); # XXX???
    }

    if (0) {
	eval {
	    my($wrapper)=$mw->wrapper;
	    $mw->property('set','_NET_WM_STATE','ATOM',32,["_NET_WM_STATE_STICKY"],$wrapper); # sticky
	    $mw->property('set','_NET_WM_LAYER','ATOM',32,["_NET_WM_STATE_STAYS_ON_TOP"],$wrapper); # ontop
	};
	warn $@ if $@;
    }

    eval {
	warn $mw->property('get','_NET_WM_PID',"root");
    };
    warn $@ if $@;

}
$mw->update;
#$mw->tk_sleep(2);
MainLoop if $DEBUG;

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

