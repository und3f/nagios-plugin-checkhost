package Nagios::Plugin::CheckHost::Ping;

use strict;
use warnings;

use base 'Nagios::Plugin::CheckHost';
use Nagios::Plugin::Threshold;
use Nagios::Plugin;

sub _initialize {
    my $self = shift;

    my $np = $self->_initialize_nagios(shortname => 'CHECKHOST-PING');

    $np->add_arg(
        spec     => 'host|H=s',
        help     => 'host to check',
        required => 1,
    );

    $self->{total_pings} = 4;
    $np->add_arg(
        spec     => 'loss_threshold_critical|ltc=s',
        help     => 'maximum percentage of ping loss '
            . 'outside of which a critical code '
            . 'will be generated for a node (default %s).',
        default  => 50,
        required => 1,
    );
    $np->add_arg(
        spec     => 'loss_threshold_warning|ltw=s',
        help     => 'maximum percentage of ping loss '
            . 'outside of which a warning code '
            . 'will be generated for a node (default %s).',
        default  => 25,
        required => 1,
    );

    $np->add_arg(
        spec     => 'max_nodes|n=i',
        help     => 'max amount of nodes used for the check (default %s)',
        default  => 3,
        required => 1,
    );

    $np->add_arg(
        spec => 'warning|w=i',
        help => 'maximum number of nodes that failed '
          . 'threshold check with any code, '
          . 'outside of which a warning will be generated. '
          . 'Default %s.',
        default => 0,
    );

    $np->add_arg(
        spec => 'critical|c=i',
        help => 'maximum number of nodes that failed '
          . 'threshold check with a critical code, '
          . 'outside of which a critical will be generated. '
          . 'Default %s.',
        default => 1,
    );

    $self;
}

sub process_check_result {
    my ($self, $result) = @_;

    my $np   = $self->{nagios};
    my $opts = $np->opts;

    my %loss_result = (
        Nagios::Plugin::OK       => 0,
        Nagios::Plugin::WARNING  => 0,
        Nagios::Plugin::CRITICAL => 0
    );

    my $ltc = "0:" . $opts->get('loss_threshold_critical');
    my $ltw = "0:" . $opts->get('loss_threshold_warning');

    my $loss_threshold = Nagios::Plugin::Threshold->set_thresholds(
        critical => $ltc,
        warning  => $ltw,
    );

    foreach my $node ($result->nodes) {
        my $loss = $result->calc_loss($node);
        $loss = int($loss * 100);

        $np->add_perfdata(
            label => "loss-" . $node->shortname,
            value => $loss,
            uom   => '%',
        );

        $loss_result{$loss_threshold->get_status($loss)}++;

        if (my ($avg) = $result->calc_rtt($node)) {
            $np->add_perfdata(
                label => "avg-" . $node->shortname,
                value => int(1000 * $avg),
                uom   => 'ms',
            );
        }
    }

    my $code = $np->check_threshold(
        check    => $loss_result{Nagios::Plugin::CRITICAL},
        critical => $opts->get('critical')
    );

    if ($code == OK) {
        $code = $np->check_threshold(
            check => $loss_result{Nagios::Plugin::WARNING}
              + $loss_result{Nagios::Plugin::CRITICAL},
            warning => $opts->get('warning'),
        );
    }

    $np->nagios_exit($code, "report " . $self->report_url);
}

1;