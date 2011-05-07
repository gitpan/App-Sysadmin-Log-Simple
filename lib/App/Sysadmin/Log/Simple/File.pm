package App::Sysadmin::Log::Simple::File;
use perl5i::2;
use File::Path 2.07 qw(make_path);
# ABSTRACT: a file-logger for App::Sysadmin::Log::Simple
our $VERSION = '0.004'; # VERSION


method new($class: %opts) {
    return bless {
        logdir  => $opts{logdir} || '/var/log/sysadmin',
        index_preamble => $opts{index_preamble},
        view_preamble  => $opts{view_preamble},
        date    => $opts{date},
        user    => $opts{user},
    }, $class;
}


method view() {
    require IO::Pager;
    my $year  = $self->{date}->year;
    my $month = $self->{date}->month;
    my $day   = $self->{date}->day;

    my $logfh;
    try {
        open $logfh, '<', "$self->{logdir}/$year/$month/$day.log";
    }
    catch {
        die "No log for $year/$month/$day\n" unless -e "$self->{logdir}/$year/$month/$day";
    };
    local $STDOUT = IO::Pager->new(*STDOUT);
    say $self->{view_preamble} if defined $self->{view_preamble};
    print while (<$logfh>);
    return;
}


method log($line) {
    make_path $self->{logdir} unless -d $self->{logdir};

    my $year  = $self->{date}->year;
    my $month = $self->{date}->month;
    my $day   = $self->{date}->day;

    make_path "$self->{logdir}/$year/$month" unless -d "$self->{logdir}/$year/$month";
    my $logfile = "$self->{logdir}/$year/$month/$day.log";

    # Start a new log file if one doesn't exist already
    unless (-e $logfile) {
        open my $logfh, '>>', $logfile;
        my $line = $self->{date}->day_name . ' ' . $self->{date}->month_name . " $day, $year";
        say $logfh $line;
        say $logfh "=" x length($line), "\n";
        close $logfh; # Explicitly close before calling generate_index() so the file is found
        $self->_generate_index();
    }

    open my $logfh, '>>', $logfile;
    my $timestamp = $self->{date}->hms;
    my $user = $ENV{SUDO_USER} || $ENV{USER}; # We need to know who wrote this
    say $logfh "    $timestamp $user:\t$line";

    # This might be run as root, so fix up ownership and
    # permissions so mortals can log to files root started
    my ($login, $pass, $uid, $gid) = getpwnam($self->{user});
    chown $uid, $gid, $logfile;
    chmod 0644, $logfile;
    return;
}

method _generate_index() {
    require File::Find::Rule;

    open my $indexfh, '>', "$self->{logdir}/index.log"; # clobbers the file
    say $indexfh $self->{index_preamble} if defined $self->{index_preamble};

    # Find relevant log files
    my @files = File::Find::Rule->mindepth(3)->in($self->{logdir});
    my @dates;
    foreach (@files) {
        if (m!(\d{4}/\d{1,2}/\d{1,2})!) { # Extract the date
            my $date = $1;
            my ($year, $month, $day) = split /\//, $date;
            push @dates, [$year, $month, $day];
        }
        else {
            warn "WTF: $_";
        }
    }
    # Sort by year, then by month, then by day
    @dates =    map  { $_->[0] }
                sort { $b->[1] <=> $a->[1] }
                map  { [ $_, $_->[0]*1000 + $_->[1]*10 + $_->[2] ] }
                @dates;

    # Keep track of 
    my $lastyear  = 0;
    my $lastmonth = 0;
    for my $date (@dates) {
        my $year  = $date->[0];
        my $month = $date->[1];
        my $day   = $date->[2];

        if ($year != $lastyear) {
            say $indexfh "\n$year";
            say $indexfh "-" x length($year);
            $lastyear  = $year;
            $lastmonth = 0;
        }
        if ($month != $lastmonth) {
            say $indexfh "\n### $month ###\n";
            $lastmonth = $month;
        }
        if ($year == $lastyear and $month == $lastmonth) {
            say $indexfh "[$day]($year/$month/$day)"
        }
    }
    return;
}

__END__
=pod

=encoding utf-8

=head1 NAME

App::Sysadmin::Log::Simple::File - a file-logger for App::Sysadmin::Log::Simple

=head1 VERSION

version 0.004

=head1 DESCRIPTION

This provides methods to App::Sysadmin::Log::Simple for logging to a file, and
viewing those log files.

=head1 METHODS

=head2 new

This creates a new App::Sysadmin::Log::Simple::File object. It takes a hash of
options with keys:

=over 4

=item logdir

This specifies the top of the tree of log files. Default is F</var/log/sysadmin>.
Please note that unprivileged users are typically not permitted to create the
default log directory.

=item index_preamble

This is a string to place at the top of the index page.

=item view_preamble

This is a string to prepend when viewing the log files.

=item date

This is a DateTime object for when the log entry was made I<or> for specifying
which date's log file to view, depending on the mode of operation.

=back

=head2 view

This allows users to view a log file in a pager provided by L<IO::Pager>,
typically L<less(1)>.

=head2 log

This creates a new log file if needed, adds the log entry to it, and re-generates
the index file as necessary.

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

