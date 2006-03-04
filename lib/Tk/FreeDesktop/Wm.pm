package Tk::FreeDesktop::Wm;

use strict;
use vars qw($VERSION);
$VERSION = "0.01";

use Tk;

sub new {
    my($class, %args) = @_;
    my $self = bless {}, $class;
    $self->mw($args{mw});
    $self;
}

sub mw {
    my $self = shift;
    if (@_) {
	my $val = shift;
	if ($val) {
	    $self->{mw} = $val;
	}
    } else {
	if (!$self->{mw}) {
	    $self->{mw} = (Tk::MainWindow::Existing)[0];
	}
	$self->{mw};
    }
}

sub _root_property {
    my($self, $prop) = @_;
    my(undef, @vals) = eval {
	$self->mw->property("get", "_NET_" . uc($prop), "root");
    };
    #warn $@ if $@;
    @vals;
}

sub _win_property {
    my($self, $prop) = @_;
    my(undef, @vals) = eval {
	$self->mw->property("get", "_NET_" . uc($prop), ($self->mw->wrapper)[0]);
    };
    #warn $@ if $@;
    @vals;
}

BEGIN {
    # root properties
    for my $prop (qw(supported client_list client_list_stacking
		     desktop_geometry desktop_names desktop_viewport
		     virtual_roots
		 )) {
	no strict 'refs';
	*{$prop} = sub { shift->_root_property($prop) };
    }

    # ... only returning a scalar
    for my $prop (qw(number_of_desktops active_window current_desktop)) {
	no strict 'refs';
	*{$prop} = sub {
	    my($val) = shift->_root_property($prop);
	    $val;
	};
    }

    # window properties
    for my $prop (qw(
		 )) {
	no strict 'refs';
	*{$prop} = sub { shift->_win_property($prop) };
    }

    # ... only returning a scalar
    for my $prop (qw(wm_desktop wm_state wm_visible_name wm_window_type)) {
	no strict 'refs';
	*{$prop} = sub {
	    my($val) = shift->_win_property($prop);
	    $val;
	};
    }
}

sub workareas {
    my($self) = @_;
    my(undef, @vals) = eval {
	$self->mw->property("get", "_NET_WORKAREA", "root");
    };
    #warn $@ if $@;
    my @ret;
    for(my $i = 0; $i < $#vals; $i+=4) {
	push @ret, [@vals[$i..$i+3]];
    }
    @ret;
}

sub workarea {
    my($self, $desktop) = @_;
    if (!defined $desktop) {
	$desktop = $self->current_desktop;
    }
    die "Cannot figure out current desktop" if !defined $desktop;
    @{ ($self->workareas)[$desktop] };
}

sub supporting_wm {
    my($self) = @_;
    my($win_id, $win_name, @win_class);
    eval {
	my $mw = $self->mw;
	(undef, $win_id) = $mw->property("get", "_NET_SUPPORTING_WM_CHECK", "root");
	my(undef, $win_check_id) = $mw->property("get", "_NET_SUPPORTING_WM_CHECK", $win_id);
	if ($win_id != $win_check_id) {
	    die "_NET_SUPPORTING_WM_CHECK mismatch: $win_id != $win_check_id";
	}
	if (defined $win_id) {
	    my($wm_name_utf8) = $mw->property("get", "_NET_WM_NAME", $win_id);
	    if (defined $wm_name_utf8) {
		require Encode;
		$win_name = Encode::decode("utf8", $wm_name_utf8, $win_id);
	    } else {
		($win_name) = $mw->property("get", "WM_NAME", $win_id);
	    }
	    my($raw_win_class) = $mw->property("get", "WM_CLASS", $win_id);
	    @win_class = split /\0/, $raw_win_class;
	}
    };

    return { id    => $win_id,
	     name  => $win_name,
	     class => \@win_class,
	   };
}

sub set_number_of_desktops {
    my($self, $number) = @_;
    eval {
	$self->mw->property("set", "_NET_NUMBER_OF_DESKTOPS", "CARDINAL", 32,
			    [$number], "root");
    };
    warn $@ if $@;
}

sub set_desktop_viewport {
    my($self, $vx, $vy) = @_;
    eval {
	$self->mw->property("set", "_NET_DESKTOP_VIEWPORT", "CARDINAL", 32,
			    [$vx, $vy], "root");
    };
    warn $@ if $@;
}

sub set_active_window {
    die "NYI";
}

sub set_wm_icon {
    my($self, $photo_or_file) = @_;
    my $mw = $self->mw;
    my $photo;
    if (UNIVERSAL::isa($photo_or_file, "Tk::Photo")) {
	$photo = $photo_or_file;
    } else {
	my $file = $photo_or_file;
	# XXX Should probably use the real magic instead.
	# Or first try and then reload the module.
	if ($file =~ m{\.png$}i) {
	    require Tk::PNG;
	} elsif ($file =~ m{\.jpe?g$}i) {
	    require Tk::JPEG;
	}
	$photo = $mw->Photo(-file => $file);
    }

    my @points;
    {
	my $data = $photo->data;
	my $y = 0;
	# XXX How to get alpha value?
	while ($data =~ m<{(.*?)}\s*>g) {
	    my(@colors) = split /\s+/, $1;
	    my(@trans);
	    if ($photo->can("transparencyGet")) {
		# Tk 804
		for my $x (0 .. $#colors) {
		    push @trans, $photo->transparencyGet($x,$y) ? "00" : "FF";
		}
	    } else {
		# Tk 800
		@trans = map { "FF" } (0 .. $#colors);
	    }
	    my $x = 0;
	    push @points, map {
		hex($trans[$x++] . substr(("0"x8).substr($_, 1),-6));
	    } @colors;
	    $y++;
	}
    }

    my($wr) = $mw->wrapper;
    $mw->property('set', '_NET_WM_ICON', "CARDINAL", 32,
		  [$photo->width, $photo->height, @points], $wr);
}

1;

__END__

See also:
http://www.freedesktop.org/wiki/Standards_2fwm_2dspec

These are defined by fvwm 2.5.16:
_KDE_NET_SYSTEM_TRAY_WINDOWS
_KDE_NET_WM_FRAME_STRUT
_KDE_NET_WM_SYSTEM_TRAY_WINDOW_FOR
_NET_ACTIVE_WINDOW
_NET_CLIENT_LIST
_NET_CLIENT_LIST_STACKING
_NET_CLOSE_WINDOW
_NET_CURRENT_DESKTOP
_NET_DESKTOP_GEOMETRY
_NET_DESKTOP_NAMES
_NET_DESKTOP_VIEWPORT
_NET_FRAME_EXTENTS
_NET_MOVERESIZE_WINDOW
_NET_NUMBER_OF_DESKTOPS
_NET_RESTACK_WINDOW
_NET_SUPPORTED
_NET_SUPPORTING_WM_CHECK
_NET_VIRTUAL_ROOTS
_NET_WM_ACTION_CHANGE_DESKTOP
_NET_WM_ACTION_CLOSE
_NET_WM_ACTION_FULLSCREEN
_NET_WM_ACTION_MAXIMIZE_HORZ
_NET_WM_ACTION_MAXIMIZE_VERT
_NET_WM_ACTION_MINIMIZE
_NET_WM_ACTION_MOVE
_NET_WM_ACTION_RESIZE
_NET_WM_ACTION_SHADE
_NET_WM_ACTION_STICK
_NET_WM_ALLOWED_ACTIONS
_NET_WM_DESKTOP
_NET_WM_HANDLED_ICON
_NET_WM_ICON
_NET_WM_ICON_GEOMETRY
_NET_WM_ICON_NAME
_NET_WM_ICON_VISIBLE_NAME
_NET_WM_MOVERESIZE
_NET_WM_NAME
_NET_WM_PID
_NET_WM_STATE
_NET_WM_STATE_ABOVE
_NET_WM_STATE_BELOW
_NET_WM_STATE_FULLSCREEN
_NET_WM_STATE_HIDDEN
_NET_WM_STATE_MAXIMIZED_HORIZ
_NET_WM_STATE_MAXIMIZED_HORZ
_NET_WM_STATE_MAXIMIZED_VERT
_NET_WM_STATE_MODAL
_NET_WM_STATE_SHADED
_NET_WM_STATE_SKIP_PAGER
_NET_WM_STATE_SKIP_TASKBAR
_NET_WM_STATE_STAYS_ON_TOP
_NET_WM_STATE_STICKY
_NET_WM_STRUT
_NET_WM_VISIBLE_NAME
_NET_WM_WINDOW_TYPE
_NET_WM_WINDOW_TYPE_DESKTOP
_NET_WM_WINDOW_TYPE_DIALOG
_NET_WM_WINDOW_TYPE_DOCK
_NET_WM_WINDOW_TYPE_MENU
_NET_WM_WINDOW_TYPE_NORMAL
_NET_WM_WINDOW_TYPE_TOOLBAR
_NET_WORKAREA
