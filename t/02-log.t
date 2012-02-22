use strict;
use warnings;

use IO::Select;
use IO::Socket::INET;
use Log::Dispatch;
use Test::More;

# set up a fake syslogd
my $port = 0;
if ($IO::Socket::INET::VERSION < 1.31) {
    $port = int(rand 1<<16) - int(rand 1<<15);
    diag "Using port $port for IO::Socket::INET v$IO::Socket::INET::VERSION";
}

my $localhost = '127.0.0.1';
my $listener = IO::Socket::INET->new(
    Proto       => 'tcp',
    Type        => SOCK_STREAM,
    LocalHost   => $localhost,
    LocalPort   => $port,
    Listen      => 1,
    Reuse       => 1,
) or BAIL_OUT $!;

$port = $listener->sockport;
ok $listener, "listening on $port";

my $log = Log::Dispatch->new(
    outputs => [
        [
            'Log::Syslog::Fast',
            min_level => 'info',
            name      => 'foo',
            transport => 'tcp',
            host      => $listener->sockhost,
            port      => $listener->sockport,
        ]
    ]
);
ok $log, "created logger";

my $msg = "Fatal error.";
$log->emerg($msg);
ok $log, "called logger";

my $receiver = $listener->accept;
$receiver->blocking(0);

ok $listener, "listening on $port";

if (ok(IO::Select->new($receiver)->can_read(1), "didn't time out waiting for log line")) {
    $receiver->recv(my $buf, 256);
    like $buf, qr/^<14>/, "priority value is correct";
    like $buf, qr/foo\[$$\]/, "program name/pid is correct";
    like $buf, qr/\Q$msg\E$/, "log message is correct";
}

done_testing;
