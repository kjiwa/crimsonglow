---
title: FreeDNS Updater
description: >-
  A Perl script that updates a FreeDNS dynamic DNS A record when it no longer
  matches the caller's public IP, with nameserver and force-update flags.
---
As its name suggests, FreeDNS is a free Internet DNS service. If you manage your domains with them, you can use this script to update your DNS records whenever your IP changes. It acts by querying the A record for your domain and for your public IP. If there is a mismatch between them, an update is invoked. The script is written in Perl and accepts the following options:

Required:

* --domain \<domain\>
* --key \<key\>

Optional:

* --ip \<ip\>
* --nameserver \<nameserver\>
* --force

The script will query FreeDNS to find out your public IP if you do not specify an IP with --ip.

You can specify which DNS server you want the script to query when it is checking your domain records. This is useful if you have an internal DNS server that maps your domain to a private IP.

By default, the script will not invoke an update if the domain's A record is the same as your IP. You can force an update with the --force option.

The source code is released under the MIT license and is also available on GitHub at [github.com/kjiwa/freedns-update](https://github.com/kjiwa/freedns-update).

<div class="caption">freedns-update.pl</div>

{% highlight perl %}
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use LWP::Simple;
use Net::DNS;
use Socket;

sub get_my_ip_address
{
  my $url = qq(http://freedns.afraid.org/dynamic/check.php);
  my $content = get($url);
  die($!) unless defined($content);

  $content =~ m/Detected IP : (\S+)\n/ or die("Unable to extract IP address");
  my $ip = $1;
  return $ip;
}

sub get_ip_address_by_hostname
{
  my ($domain) = @_;

  my $host = gethostbyname($domain);
  die(sprintf(qq(Unable to determine IP address for %s), $domain)) unless defined($host);

  my $ip = inet_ntoa($host);
  return $ip;
}

sub get_ip_address_by_hostname_from_ns
{
  my ($domain, $ns) = @_;

  my $res = new Net::DNS::Resolver;
  $res->nameservers($ns);

  my @answers = $res->send($domain)->answer;
  foreach my $answer (@answers) {
    my $ip = $answer->{address};
    return $ip if $ip;
  }

  die(sprintf(qq(Unable to determine IP address for %s), $domain));
}

sub update_host_ip_address
{
  my ($domain, $key, $ip) = @_;

  my $url = sprintf(qq(http://freedns.afraid.org/dynamic/update.php?%s&address=%s), $key, $ip);
  my $content = get($url);

  unless ($content =~ m/(ERROR: Address \S+ has not changed|Updated \d+ host\(s\) .+ to \S+ in .+ seconds|Updated \S+ to \S+ in .+ seconds)/) {
    die(sprintf(qq(Error updating domain %s to IP %s: %s), $domain, $ip, $content));
  }
}

sub get_args
{
  my %opts;
  my @args = (
    'domain|d=s',
    'key|k=s',
    'ip=s',
    'nameserver|ns=s',
    'force|f',
    'simulate|s',
    'print|p',
    'help|h'
  );

  GetOptions(\%opts, @args);
  if (!exists $opts{domain} || !exists $opts{key}) {
    $opts{help} = 1;
  }

  return %opts;
}

sub usage
{
  my @P = split(/\//, $0);
  my $p = pop(@P);

  my $s = <<EOS;
USAGE: %s

Required:
--domain <domain>
--key <key>

Optional:
--ip <ip>
--nameserver <nameserver>
--force
--simulate
--print
--help
EOS

  return sprintf($s, $p);
}

sub fault_handler
{
  my ($e) = @_;
  print(sprintf(qq(%s\n), $e));
  print(sprintf(qq(%s\n), usage));
  exit(-1);
}

sub main
{
  my %args = get_args;

  my $domain = $args{domain};
  my $key = $args{key};
  my $my_ip = $args{ip};
  my $ns = $args{nameserver};
  my $force = $args{force};
  my $simulate = $args{simulate};
  my $print = $args{print};
  my $help = $args{help};

  if ($help) {
    print(sprintf(qq(%s\n), usage()));
    return 0;
  }

  my $domain_ip = $ns
                  ? get_ip_address_by_hostname_from_ns($domain, $ns)
                  : get_ip_address_by_hostname($domain);

  $my_ip = get_my_ip_address if !defined($my_ip);

  if ($print) {
    print(sprintf(qq(Before:\t%s\n), $domain_ip));
    print(sprintf(qq(After:\t%s\n), $my_ip));
 }

  if (!$simulate
      and ($force
           or $domain_ip ne $my_ip)) {
    update_host_ip_address($domain, $key, $my_ip);
  }

  return 0;
}

eval {
  main;
};

fault_handler($@) if $@;
{% endhighlight %}
