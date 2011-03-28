package Net::CLI::Interact::Action;

use Moose;
use Moose::Util::TypeConstraints qw(enum);
use Net::CLI::Interact::ActionSet;

has 'type' => (
    is => 'ro',
    isa => enum([qw/send match/]),
    required => 1,
);

has 'value' => (
    is => 'ro',
    isa => 'Str|RegexpRef',
    required => 1,
);

has 'no_ors' => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
    default => 0,
);

has 'is_lazy' => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
    default => 0,
    init_arg => 'lazy',
);

has 'continuation' => (
    is => 'rw',
    isa => 'Net::CLI::Interact::ActionSet',
    required => 0,
);

has 'params' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
    auto_deref => 1,
    required => 0,
);

has 'response' => (
    is => 'rw',
    isa => 'Str',
    default => '',
    required => 0,
);

sub BUILDARGS {
    my ($class, @rest) = @_;
    # accept single hash ref or naked hash
    my $params = (ref $rest[0] eq ref {} and scalar @rest == 1 ? $rest[0] : {@rest});

    if (exists $params->{continuation} and ref $params->{continuation} eq ref []) {
        $params->{continuation} = Net::CLI::Interact::ActionSet->new({
            actions => $params->{continuation},
        });
    }

    return $params;
}

# only a shallow copy so all the reference based slots still
# share data with the original Action's slots
sub clone {
    my $self = shift;
    $self->meta->clone_object($self, %{(shift) || {}});
}

# count the number of sprintf parameters used in the value
sub num_params {
    my $self = shift;
    return 0 if ref $self->value eq ref qr//;
    # this tricksy little number comes from the Perl FAQ
    my $count = () = $self->value =~ m/(?<!%)%/g;
    return $count;
}

1;

# ABSTRACT: Sent data or matched response from connected device

=head1 DESCRIPTION

This class is used internally by L<Net::CLI::Interact> and it's unlikely that
an end-user will need to make use of Action objects directly. The interface is
documented here as a matter of record.

An Action object represents I<either> some kind of text or command to send to
a connected device, I<or> a regular expression matching the response from a
connected device. Such Actions are built up into ActionSets which describe a
conversation with the connected device.

If the Action is a C<send> type, then after execution it can be cloned and
augmented with the response text of the command. If the response is likely to
be paged, then the Action may also store instruction in how to trigger and
consume the pages.

=head1 INTERFACE

=head2 type

Denotes the kind of Action, which may be C<send> or C<match>.

=head2 value

In the case of C<send>, a String command to send to the device. In the case of
C<match>, a regular expression reference to match response from the device.

=head2 no_ors

Whether to append the I<output record separator> (newline) to the C<send>
command when sent to the connected device.

=head2 is_lazy

Only applies to the C<match> kind, and records whether the user specified this
Match as a regular expression reference, or the name of a Match defined
elsewhere. In the latter case, it can trigger C<Net::CLI::Interact> to assume
the Prompt value has permanently changed.

=head2 continuation

Only applies to the C<send> kind. When response output is likely to be paged,
this stores an L<ActionSet|Net::CLI::Interact::ActionSet> that contains two
Actions: one for the C<match> which indicates output has paused at the end of
a page, and one for the C<send> command which triggers printing of the next
page.

=head2 params

Only applies to the C<send> kind, and contains a list of parameters which are
substituted into the C<value> using Perl's C<sprintf> function. Insufficient
parameters causes C<sprintf> to die.

=head2 num_params

Only applies to the C<send> kind, and returns the number of parameters which
are required for the current C<value>. Used for error checking when setting
C<params>.

=head2 response

A stash for the returned output following a C<send> command. In fact, this
slot is temporarily used by the C<match> action as it slurps output, but the
content is then transferred over to the partner C<send> in the ActionSet.

=head2 clone

Returns a new Action, which is a shallow clone of the existing one. All the
reference based slots will share data, but you can add (for example) a
C<response> without affecting the original Action. Used when preparing to
execute an Action which has been retrieved from the
L<Phrasebook|Net::CLI::Interact::Phrasebook>.

=cut
