package Log::Dispatch::Log::Syslog::Fast;

use strict;
use warnings;

our $VERSION = '1.00';

use Log::Dispatch::Output;
use parent qw( Log::Dispatch::Output );

use Carp qw( croak );
use Log::Syslog::Constants 1.02 qw( :functions );
use Log::Syslog::Fast 0.58 qw( :protos );
use Params::Validate qw( validate SCALAR );
use Sys::Hostname ();

Params::Validate::validation_options( allow_extra => 1 );

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %p = @_;

    my $self = bless {}, $class;

    $self->_basic_init(%p);
    $self->_init(%p);

    return $self;
}

my ($Ident) = $0 =~ /(.+)/;

sub _init {
    my $self = shift;

    my %p = validate(
        @_, {
            transport => {
                type    => SCALAR,
                default => 'udp',
            },
            host => {
                type    => SCALAR,
                default => 'localhost',
            },
            port => {
                type    => SCALAR,
                default => 514,
            },
            facility => {
                type    => SCALAR,
                default => 'user'
            },
            severity => {
                type    => SCALAR,
                default => 'info'
            },
            sender => {
                type    => SCALAR,
                default => Sys::Hostname::hostname(),
            },
            name => {
                type    => SCALAR,
                default => $Ident
            },
        }
    );

    my $transport
        = lc $p{transport} eq 'udp'  ? LOG_UDP
        : lc $p{transport} eq 'tcp'  ? LOG_TCP
        : lc $p{transport} eq 'unix' ? LOG_UNIX
        : undef;
    croak "unknown facility $p{facility}" unless defined $transport;

    my $facility = get_facility($p{facility});
    croak "unknown facility $p{facility}" unless defined $facility;

    my $severity = get_severity($p{severity});
    croak "unknown severity $p{severity}" unless defined $severity;

    my $logger = Log::Syslog::Fast->new(
        $transport, $p{host}, $p{port}, $facility, $severity, $p{sender}, $p{name},
    );
    die "failed to create Log::Syslog::Fast" unless $logger;

    $self->{logger} = $logger;
}

sub log_message {
    my ($self, %p) = @_;
    $self->{logger}->send($p{message});
}

1;

# ABSTRACT: Log::Dispatch wrapper around Log::Syslog::Fast

=pod

=head1 SYNOPSIS

  use Log::Dispatch;

  my $log = Log::Dispatch->new(
      outputs => [
          [
              'Log::Syslog::Fast',
              min_level => 'info',
              name      => 'Yadda yadda'
          ]
      ]
  );

  $log->emerg("Time to die.");

=head1 DESCRIPTION

This module provides a simple object for sending messages to a syslog daemon
via UDP, TCP, or UNIX socket.

=method new

The constructor takes the following parameters in addition to the standard
parameters documented in L<Log::Dispatch::Output>:

=item * transport ($)

The transport mechanism to use: one of 'udp', 'tcp', or 'unix'.

=item * host ($)

For UDP and TCP, the hostname or IPv4 or IPv6 address. For UNIX, the socket
path. Defaults to 'localhost'.

=item * port ($)

The listening port of the syslogd (ignored for unix sockets). See
Log::Syslog::Fast. Defaults to 514.

=item * facility ($)

The log facility to use. See Log::Syslog::Constants. Defaults to 'user'.

=item * severity ($)

The log severity to use. See Log::Syslog::Constants. Defaults to 'info'.

=item * sender ($)

The system name to claim as the source of the message. Defaults to the system's
hostname.

=item * name ($)

The name of the application. Defaults to $0.

=cut
