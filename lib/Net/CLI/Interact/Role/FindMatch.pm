package Net::CLI::Interact::Role::FindMatch;
BEGIN {
  $Net::CLI::Interact::Role::FindMatch::VERSION = '1.112610';
}

use Moose::Role;

# see if any regexp in the arrayref match the response
sub find_match {
    my ($self, $text, $matches) = @_;
    $matches = ((ref $matches eq ref qr//) ? [$matches] : $matches);
    return undef unless
        (scalar grep {ref $_ eq ref qr//} @$matches) == scalar @$matches;

    use List::Util 'first';
    return first { $text =~ $_ } @$matches;
}


1;
