# $Id: WebUtils.pm,v 1.8 2003/06/17 19:49:25 matt Exp $

# Original Code and comments from Steve Willer.

package AxKit::XSP::WebUtils;

$VERSION = "1.5";

# taglib stuff
use AxKit 1.4;
use Apache;
use Apache::Constants qw(OK);
use Apache::Util;
use Apache::AxKit::Language::XSP::TaglibHelper;
sub parse_char  { Apache::AxKit::Language::XSP::TaglibHelper::parse_char(@_); }
sub parse_start { Apache::AxKit::Language::XSP::TaglibHelper::parse_start(@_); }
sub parse_end   { Apache::AxKit::Language::XSP::TaglibHelper::parse_end(@_); }

$NS = 'http://axkit.org/NS/xsp/webutils/v1';

@EXPORT_TAGLIB = (
  'env_param($name)',
  'path_info()',
  'query_string()',
  'request_uri()',
  'request_host()',
  'server_root()',
  'redirect($uri;$host,$secure,$use_refresh)',
  'url_encode($string)',
  'url_decode($string)',
  'header($name;$value)',
  'return_code($code)',
  'username()',
  'password()',
);

@ISA = qw(Apache::AxKit::Language::XSP);

use strict;

sub env_param ($) {
    my ($name) = @_;

    return $ENV{$name};
}

sub path_info () {
    my $Request = AxKit::Apache->request;
    return $Request->path_info;
}

sub query_string () {
    my $Request = AxKit::Apache->request;
    return $Request->query_string;
}

sub request_uri () {
    my $Request = AxKit::Apache->request;
    return $Request->uri;
}

sub server_root () {
    my $Request = AxKit::Apache->request;
    return $Request->document_root;
}

sub request_host () {
    my $hostname = Apache->header_in('Via');
    $hostname =~ s/^[0-9.]+ //g;
    $hostname =~ s/ .*//g;
    $hostname ||= $ENV{HTTP_HOST};
    $hostname ||= Apache->header_in('Host');
    return $hostname;
}

sub redirect ($;$$$) {
    my ($uri, $host, $secure, $use_refresh) = @_;
    
    if (lc($secure) eq 'yes') { $secure = 1 }
    elsif (lc($secure) eq 'no') { $secure = 0 }
    if (lc($use_refresh) eq 'yes') { $use_refresh = 1 }
    elsif (lc($use_refresh) eq 'no') { $use_refresh = 0 }
    
    my $myhost = $host;

    my $Request = AxKit::Apache->request;

    if ($uri !~ m|^https?://|oi) {
        if ($uri !~ m#^/#) {
            $uri = "./$uri" if $uri =~ /^\./;

            # relative path, so let's resolve the path ourselves
	    my $base = $Request->uri;
            $base =~ s{[^/]*$}{};
	    $uri = "$base$uri";
	    $uri =~ s{//+}{/}g;
	    $uri =~ s{/.(/|$)}{/}g;                     # embedded ./
	    1 while ($uri =~ s{[^/]+/\.\.(/|$)}{}g);   # embedded ../
	    $uri =~ s{^(/\.\.)+(/|$)}{/}g;              # ../ off of "root"
	}

        if (not defined $host) {
            $myhost = $Request->header_in("Host");

            # if we're going through a proxy, the virtual host is rewritten; yuck
            if ($myhost !~ /[a-zA-Z]/) {
                my $Server = $Request->server;
                $myhost = $Server->server_hostname;
                my $port = $Server->port;
                $myhost .= ":$port" if $port != 80;
            }
        }
        
        my $scheme = 'http';
        $scheme = 'https' if $secure; # Hmm, might break if $port was set above...
        if ($use_refresh) {
            $Request->header_out("Refresh" => "0; url=${scheme}://${myhost}${uri}");
            $Request->content_type("text/html");
            $Request->status(200);
        }
        else {
            $Request->header_out("Location" => "${scheme}://${myhost}${uri}");
            $Request->status(302);
        }
    }
    else {
        if ($use_refresh) {
            $Request->header_out("Refresh" => "0; url=$uri");
            $Request->content_type("text/html");
            $Request->status(200);
        }
        else {
            $Request->header_out("Location" => $uri);
            $Request->status(302);
        }
    }
    
    $Request->send_http_header;
    
    Apache::exit();
}

sub header ($;$) {
    my $name = shift;
    my $r = AxKit::Apache->request;
    
    if (@_) {
        return $r->header_out($name, $_[0]);
    }
    else {
        return $r->header_in($name);
    }
}

sub url_encode ($) {
    return Apache::Util::escape_uri(shift);
}

sub url_decode ($) {
    return Apache::Util::unescape_uri(shift);
}

sub return_code ($) {
    my $code = shift;

    my $Request = AxKit::Apache->request;

    $Request->status($code);
    
    $Request->send_http_header;
    
    Apache::exit();
}

sub username () {
    my $r = AxKit::Apache->request;
    
    return $r->connection->user;
}

sub password () {
    my $r = AxKit::Apache->request;
    
    my ($res, $pwd) = $r->get_basic_auth_pw;
    if ($res == OK) {
        return $pwd;
    }
    return;
}

1;

__END__

=head1 NAME

AxKit::XSP::WebUtils - Utilities for building XSP web apps

=head1 SYNOPSIS

Add the taglib to AxKit (via httpd.conf or .htaccess):

    AxAddXSPTaglib AxKit::XSP::WebUtils

Add the C<web:> namespace to your XSP C<<xsp:page>> tag:

    <xsp:page
         language="Perl"
         xmlns:xsp="http://apache.org/xsp/core/v1"
         xmlns:web="http://axkit.org/NS/xsp/webutils/v1"
    >

Then use the tags:

  <web:redirect>
    <web:uri>foo.xsp</web:uri>
  </web:redirect>

=head1 DESCRIPTION

The XSP WebUtils taglib implements a number of features for building
web applications with XSP. It makes things like redirects and
getting/setting headers simple.

=head1 TAG REFERENCE

All of the below tags allow the parameters listed to be either passed
as an attribute (e.g. C<<web:env_param name="PATH">>), or as a child
tag:

  <web:env_param>
    <web:name>PATH</web:name>
  </web:env_param>

The latter method allows you to use XSP expressions for the values.

=head2 C<<web:env_param name="..." />>

Fetch the environment variable specified with the B<name> parameter.

  <b>Server admin: <web:env_param name="SERVER_ADMIN"/></b>

=head2 C<<web:path_info/>>

Returns the current PATH_INFO value.

=head2 C<<web:query_string/>>

Returns the current query string

=head2 C<<web:request_uri/>>

Returns the full URI of the current request

=head2 C<<web:request_host/>>

This tag returns the end-user-visible name of this web service

Consider www.example.com on port 80. It is served by a number of
machines named I<abs>, I<legs>, I<arms>, I<pecs> and I<foo1>, on a
diversity of ports. With a proxy server in front that monkies with the
headers along the way. It turns out that, while writing a script,
people often wonder "How do I figure out the name of the web service
that's been accessed?". Various hacks with uname, hostname, HTTP
headers, etc. ensue.   This function is the answer to all your
problems.

=head2 C<<web:server_root/>>

Returns the server root directory, aka document root.

=head2 C<<web:redirect>>

This tag allows an XSP page to issue a redirect.

Parameters (can be attributes or child tags):

=over 4

=item uri (required)

The uri to redirect to.

=item host (optional)

The host to redirect to.

=item secure (optional)

Set to "yes" if you wish to redirect to a secure (ssl/https) server.

=back

Example (uses XSP param taglib):

  <web:redirect secure="yes">
    <web:uri><param:goto/></web:uri>
  </web:redirect>

=head2 C<<web:url_encode string="..."/>>

Encode the string using URL encoding according to the URI specification.

=head2 C<<web:url_decode string="..."/>>

Decode the URL encoded string.

=head2 C<<web:header>>

This tag allows you to get and set HTTP headers.

Parameters:

=over 4

=item name (required)

The name of the parameter. If only name is specified, you will B<get>
the value of the incoming HTTP header of the given name.

=item value (optional)

If you also specify a value parameter, then the tag will B<set> the
outgoing HTTP header to the given value.

=back

Example:

  <p>
  Your browser is: <web:header name="HTTP_USER_AGENT"/>
  </p>

=head1 AUTHOR

Matt Sergeant, matt@axkit.com

Original code by Steve Willer, steve@willer.cc

=head1 LICENSE

This software is Copyright 2001 AxKit.com Ltd.

You may use or redistribute this software under the terms of either the
Perl Artistic License, or the GPL version 2.0 or higher.
