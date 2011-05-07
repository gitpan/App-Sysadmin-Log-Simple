package App::Sysadmin::Log::Simple;
# ABSTRACT: application class for managing a simple sysadmin log
our $VERSION = '0.004'; # VERSION
use perl5i::2;
use Module::Pluggable
    search_path => [__PACKAGE__],
    instantiate => 'new';


method new($class: %opts) {
    my $datetimeobj = localtime;
    if ($opts{date}) {
        my ($in_year, $in_month, $in_day) = split(m{/}, $opts{date});
        my $in_date = DateTime->new(
            year  => $in_year,
            month => $in_month,
            day   => $in_day,
        ) or croak "Couldn't understand your date - use YYYY/MM/DD\n";
        croak "Cannot use a date in the future\n" if $in_date > $datetimeobj;
        $datetimeobj = $in_date;
    }
    my $self = {
        logdir  => $opts{logdir},
        date    => $datetimeobj,
        user    => $opts{user} || $ENV{SUDO_USER} || $ENV{USER},
        in      => $opts{read_from} || \*STDIN,
        udp     => $opts{udp},
    };
    bless $self, $class;
}


method run($cmd) {
    $cmd ||= 'log';
    $self->run_command($cmd);
    return;
}

method run_command($cmd) {
    my $s = $self->can("run_command_$cmd");
    die "Unknown command '$cmd'" unless $s;
    $self->$s();
    return;
}

method run_command_log() {
    say 'Log entry:';
    my $in = $self->{in};
    my $logentry = <$in>; # one line
    croak 'A log entry is needed' unless $logentry;
    chomp $logentry;

    PLUGIN: foreach my $plugin ( $self->plugins(%$self) ) {
        next PLUGIN unless $plugin->can('log');
        $plugin->log($logentry);
    }
}

method run_command_view() {
    PLUGIN: foreach my $plugin ( $self->plugins(%$self) ) { # Does this even make sense?
        next PLUGIN unless $plugin->can('view');
        $plugin->view();
    }
}

__END__
=pod

=encoding utf-8

=head1 NAME

App::Sysadmin::Log::Simple - application class for managing a simple sysadmin log

=head1 VERSION

version 0.004

=head1 SYNOPSIS

    require App::Sysadmin::Log::Simple;
    App::Sysadmin::Log::Simple->new()->run();

=head1 DESCRIPTION

C<App::Sysadmin::Log::Simple> provides an easy way to maintain a simple
single-host system administration log.

The log is single-host in the sense that it does not log anything about
the host. While you can obviously state what host you're talking about
in your log entry, there is nothing done automatically to differentiate
such log entries, and there is no built-in way to log from one host to
another.

The logs themselves are also simple - you get a single line of plain
text to say what you have to say. That line gets logged in a fashion
that is easy to read with this script, with cat, or it can be parsed
with L<Text::Markdown> (or L<Text::MultiMarkdown>, which is a more
modern drop-in replacement) and served on the web.

If you need more than a single line of text, you may wish to use that
line to point to a pastebin - you can easily create and retrieve them
from the command line with L<App::Pastebin::sprunge>.

There is also no way to audit that the logs are correct. It can be
incorrect in a number of ways:

=over 4

=item * SUDO_USER or USER can be spoofed

=item * The files can be edited at any time, they are chmod 644 and
owned by an unprivileged user

=item * The timestamp depends on the system clock

=item * ...etc

=back

Nonetheless, this is a simple, easy, and B<fast> way to get a useful
script for managing a simple sysadmin log. We believe the 80/20 rule
applies: You can get 80% of the functionality with only 20% of a
"real" solution. In the future, each log entry might be committed to
a git repository for additional tracking.

=head1 METHODS

=head2 new

Obviously, the constructor returns an C<App::Sysadmin::Log::Simple>
object. It takes a hash of options which specify:

=head3 logdir

The directory where to find the sysadmin log. Defaults to
F</var/log/sysadmin>.

=head3 user

The user who owns the sysadmin log. Should be unprivileged,
but could be anything. Defaults to the current user.

=head3 date

The date to use instead of today.

=head3 udp

A hashref of data regarding UDP usage. If you don't want to
send a UDP datagram, omit this. Otherwise, it has the following
structure:

    my %udp_data = (
        irc => 1,           # Whether to insert IRC colour codes
        host => 'localhost',# What hostname to send to
        port => 9002,       # What port to send to
    );

=head3 index_preamble

The text to prepend to the index page. Can be anything - by
default, it is a short explanation of the rationale for using
this system of logging, which probably won't make sense
for your context.

=head3 view_preamble

A string which gets prepended to the log being viewed (ie. at
the top of the log file).

=head3 read_from

An opened filehandle reference to read from to get the log entry.
Defaults to C<STDIN>.

=head2 run

This runs the application in the specified mode: view or log (default).

=head1 AVAILABILITY

The project homepage is L<http://p3rl.org/App::Sysadmin::Log::Simple>.

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<http://search.cpan.org/dist/App-Sysadmin-Log-Simple/>.

The development version lives at L<http://github.com/doherty/App-Sysadmin-Log-Simple>
and may be cloned from L<git://github.com/doherty/App-Sysadmin-Log-Simple.git>.
Instead of sending patches, please fork this project using the standard
git and github infrastructure.

=head1 SOURCE

The development version is on github at L<http://github.com/doherty/App-Sysadmin-Log-Simple>
and may be cloned from L<git://github.com/doherty/App-Sysadmin-Log-Simple.git>

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through the web interface at
L<https://github.com/doherty/App-Sysadmin-Log-Simple/issues>.

=head1 AUTHOR

Mike Doherty <doherty@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Mike Doherty.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

