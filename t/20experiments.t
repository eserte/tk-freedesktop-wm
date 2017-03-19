use strict;
use FindBin;
use Test::More;

use Getopt::Long;
use Tk;
use Tk::FreeDesktop::Wm;

my $doit;
my $delay;
GetOptions(
	   'doit' => \$doit,
	   'delay' => \$delay,
	  )
    or die "usage: $0 [-doit] [-delay]\n";

if (!$doit) {
    plan skip_all => 'experiments not activated (try -doit switch)';
}

my $mw = eval { tkinit };
if (!$mw) {
    plan skip_all => 'Cannot create MainWindow';
} else {
    plan 'no_plan';
}
$mw->geometry("+1+1"); # for twm
$mw->Label(-text => 'The Main Window')->pack;

$mw->update;
my($wr) = $mw->wrapper;

my $fd = Tk::FreeDesktop::Wm->new;
ok $fd;

my %supported = map {($_,1)} $fd->supported;

my $another_t = $mw->Toplevel(-title => 'Another toplevel');
$another_t->geometry('+300+1');
$another_t->group($mw);

{
    # no effect on metacity or fvwm (but check again)
    #
    # Window atom is set on marco (mint17 wm).
    # Some observations here:
    # - some types are special and cause the window
    #   to be invisible: DESKTOP, DOCK, TOOLBAR. These are
    #   not tested below
    # - utility and dialog windows are above the mainwindow, regardless
    #   whether transient was set; for a normal window transient has to
    #   set for having this window above the mainwindow
    # - an utility window is not listed in the window list toolbar
    # - a programmatic raise does not seem to be possible, unless
    #   all windows specify their group (see http://wiki.tcl.tk/1461); but
    #   setting the group does have the same effect as setting transient
    #   (mainwindow always below the child windows)
    my $t = $mw->Toplevel(-title => 'WINDOW_TYPE test');
    $t->geometry("+1+1"); # for twm
    $t->Label(-text => 'The WINDOW_TYPE test window')->pack;
    $t->Label(-textvariable => \my $active_win_type)->pack;
    $t->transient($mw);
    $t->group($mw);
    my($t_wr) = $t->wrapper;
    # Not tested:
    #_NET_WM_WINDOW_TYPE_DESKTOP
    #_NET_WM_WINDOW_TYPE_DOCK
    #_NET_WM_WINDOW_TYPE_TOOLBAR
    for my $type (qw(
		     _NET_WM_WINDOW_TYPE_MENU
		     _NET_WM_WINDOW_TYPE_DIALOG
		     _NET_WM_WINDOW_TYPE_NORMAL
		     _NET_WM_WINDOW_TYPE_UTILITY
		  )
		 ) {
	my $win_type_supported = $supported{$type};
	diag "Try $type (" .
	    ($win_type_supported ? "supported" : "unsupported") .
		")...";
	$fd->set_window_type($type, $t);
	$active_win_type = $type;
	$t->update;
	open my $xprop_fh, '-|', 'xprop', '-id', $t_wr
	    or die $!;
	my $got_window_type;
	while(<$xprop_fh>) {
	    if (/^_NET_WM_WINDOW_TYPE\(ATOM\)\s+=\s+(.*)/) {
		my $new_window_type = $1;
		if (!$win_type_supported) {
		    diag "Current window type: $new_window_type";
		} else {
		    if ($got_window_type) {
			fail "Unexpected: got multiple window types ($got_window_type, $new_window_type)";
		    }
		    $got_window_type = $new_window_type;
		}
	    }
	}
	if ($win_type_supported) {
	    is $got_window_type, $type;
	}
	$t->after(100);
    }

    if ($delay) {
	my $sleep_time = 10;
	diag "Wait for $sleep_time seconds";
	$t->after($sleep_time/2 * 1000);
	diag "Now raise the window";
	$t->raise;
	$t->update;
	$t->after($sleep_time/2 * 1000);
    }
}

SKIP: {
    skip '_NET_CLIENT_LIST_STACKING not supported', 2
	if !$supported{_NET_CLIENT_LIST_STACKING};

    $mw->raise;
    $mw->update;
    my @windows = $fd->client_list_stacking;

    local $TODO = "Usually fails if there are other stay-on-top windows";
    is($windows[-1], $wr,
       "Our window's wrapper should be on top (last in list)")
	or diag "@windows";
}

SKIP: {
    skip '_NET_DESKTOP_NAMES not supported', 1
	if !$supported{_NET_DESKTOP_NAMES};

    local $TODO = "fvwm 2.5.16 claims to support it, but fails!";
    my @names = $fd->desktop_names;
    diag "desktop names: " . explain(@names);
}


# XXX SKIP?
{
    diag 'wm_desktop';
    diag explain [$fd->wm_desktop];
    # XXX equals current desktop?
}

# XXX SKIP?
{
    diag 'wm_state';
    diag explain [$fd->wm_state];
}

# XXX SKIP?
{
    diag 'wm_visible_name';
    diag explain [$fd->wm_visible_name]; # XXX???
}

# XXX SKIP?
{
    diag 'wm_window_type';
    diag explain [$fd->wm_window_type]; # XXX???
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

