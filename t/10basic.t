use strict;
use FindBin;
use Test::More qw(no_plan);

use Tk;
use Tk::FreeDesktop::Wm;

my $mw = tkinit;
$mw->update;
my($wr) = $mw->wrapper;
my $fd = Tk::FreeDesktop::Wm->new(mw => $mw);
isa_ok($fd, "Tk::FreeDesktop::Wm");
my @supported = $fd->supported;
warn "@supported";
my %supported = map {($_,1)} @supported;
SKIP: {
    skip("Probably not a freedesktop compliant wm", 1) # XXX no of tests
	if !@supported;

    my @windows;

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

 SKIP: {
	skip("_NET_NUMBER_OF_DESKTOPS not supported", 2)
	    if !$supported{_NET_NUMBER_OF_DESKTOPS};

	my $no = $fd->number_of_desktops;
	cmp_ok($no, ">=", 1, "At minimum one desktop: $no");

	$fd->set_number_of_desktops($no + 1);
	$mw->update;
	# The wm may ignore this
	$fd->set_number_of_desktops($no);
	$mw->update;
	# But now we should be at the old number again
	my $no2 = $fd->number_of_desktops;
	is($no, $no2, "Same desktop number again: $no");
    }

 SKIP: {
	skip("_NET_DESKTOP_GEOMETRY not supported", 2)
	    if !$supported{_NET_DESKTOP_GEOMETRY};
	my($dw,$dh) = $fd->desktop_geometry;
	cmp_ok($dw, ">=", $mw->screenwidth, "Desktop geometry width");
	cmp_ok($dh, ">=", $mw->screenheight, "Desktop geometry height");
    }

    # XXX SKIP?
    {
	my($oldx,$oldy) = ($mw->rootx, $mw->rooty);
	my($px,$py) = $mw->pointerxy;
	# feels hacky...
	$mw->geometry("+".($px-10)."+".($py-10));
	$mw->focus;
	$mw->update;
	is($fd->active_window, $wr, "This window is the active one");
	$mw->geometry("+$oldx+$oldy");
    }

    # XXX SKIP?
    {
	my $cd = $fd->current_desktop;
	cmp_ok($cd, ">=", 0, "Current desktop is $cd");
    }

    # XXX SKIP?
    {
	local $TODO = "fvwm 2.5.16 claims to support it, but fails!";
	warn $fd->desktop_names;
    }

    # XXX SKIP?
    {
	warn join(",", $fd->desktop_viewport); # XXX???
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

    # XXX SKIP?
    {
	warn join(",", $fd->workarea); # XXX???
    }

    {
	# Without transparency
	$fd->set_wm_icon("$FindBin::RealBin/srtbike16.gif");
	$mw->update;
	$mw->tk_sleep(0.2);
	# With transparency
	$fd->set_wm_icon("$FindBin::RealBin/srtbike32.xpm");
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
MainLoop;

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

