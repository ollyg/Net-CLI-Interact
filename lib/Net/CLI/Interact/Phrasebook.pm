package Net::CLI::Interact::Phrasebook;

use Moose;
use Net::CLI::Interact::ActionSet;

has 'logger' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Logger',
    required => 1,
);

has 'personality' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'library' => (
    is => 'ro',
    isa => 'Str|ArrayRef[Str]',
    lazy_build => 1,
    required => 0,
);

sub _build_library {
    use File::Basename;
    my (undef, $directory, undef) = fileparse(
        $INC{ 'Net/CLI/Interact.pm' }
    );
    return ["${directory}Interact/phrasebook"];
}

has 'add_library' => (
    is => 'ro',
    isa => 'Str|ArrayRef[Str]',
    default => sub { [] },
    required => 0,
);

has 'prompt' => (
    is => 'ro',
    isa => 'HashRef[Net::CLI::Interact::ActionSet]',
    default => sub { {} },
    required => 0,
);

has 'macro' => (
    is => 'ro',
    isa => 'HashRef[Net::CLI::Interact::ActionSet]',
    default => sub { {} },
    required => 0,
);

# inflate the hashref into action objects
sub _bake {
    my ($self, $data) = @_;
    return unless ref $data eq ref {} and keys %$data;
    $self->logger->log('phrasebook', 'debug', 'storing type', $data->{type}, 'with name', $data->{name});

    my $slot = lc $data->{type};
    $self->$slot->{$data->{name}}
        = Net::CLI::Interact::ActionSet->new({
            actions => $data->{actions}
        });
}

# matches which are prompt names are resolved to RegexpRefs
sub _resolve_lazy_matches {
    my $self = shift;

    foreach my $name (keys %{$self->macro}) {
        my $set = $self->macro->{$name};
        my $new_set = [];

        $set->reset;
        while ($set->has_next) {
            my $item = $set->next;
            if ($item->is_lazy) {
                push @$new_set, $item->clone({ value =>
                    $self->prompt->{$item->value}->first->value
                });
            }
            else {
                push @$new_set, $item;
            }
        }

        $self->macro->{$name} = Net::CLI::Interact::ActionSet->new({
            actions => $new_set
        });
    }
}

sub BUILD {
    my $self = shift;
    $self->load_phrasebooks;
}

# parse phrasebook files and load action objects
sub load_phrasebooks {
    my $self = shift;
    my $data = {};

    foreach my $file ($self->_find_phrasebooks) {
        $self->logger->log('phrasebook', 'info', 'reading phrasebook', $file);
        my @lines = $file->slurp;
        while ($_ = shift @lines) {
            # Skip comments and empty lines
            next if m/^(?:#|\s*$)/;

            if (m{^(prompt|macro)\s+(\w+)\s*$}) {
                $self->_bake($data);
                $data = {type => $1, name => $2};
            }
            elsif (m{^\w}) {
                $_ = shift @lines until m{^(?:prompt|macro)};
                unshift @lines, $_;
            }

            if (m{^\s+(send(?:_literal)?)\s+(.+)$}) {
                my ($type, $value) = ($1, $2);
                $value =~ s/^["']//; $value =~ s/["']$//;
                push @{ $data->{actions} }, {
                    type => 'send', value => $value,
                    literal => ($type eq 'send_literal')
                };
                next;
            }

            if (m{^\s+match\s+prompt\s+(.+)\s*$}) {
                push @{ $data->{actions} },
                    {type => 'match', value => $1, lazy => 1};
                next;
            }

            if (m{^\s+match\s+/(.+)/\s*$}) {
                push @{ $data->{actions} },
                    {type => 'match', value => qr/$1/};
                next;
            }

            if (m{^\s+follow\s+/(.+)/\s+with\s+(.+)\s*$}) {
                my ($match, $send) = ($1, $2);
                $send =~ s/^["']//; $send =~ s/["']$//;
                $data->{actions}->[-1]->{continuation} = [
                    {type => 'match', value => qr/$match/},
                    {type => 'send',  value => $send, literal => 1}
                ];
                next;
            }
        }
        # last entry in the file needs baking
        $self->_bake($data);
    }

    $self->_resolve_lazy_matches;
}

# finds the path of Phrasebooks within the Library leading to Personality
use Path::Class;
sub _find_phrasebooks {
    my $self = shift;
    my @libs = (ref $self->add_library ? @{$self->add_library} : ($self->add_library));
    push @libs, (ref $self->library ? @{$self->library} : ($self->library));

    my $target = undef;
    foreach my $l (@libs) {
        Path::Class::Dir->new($l)->recurse(callback => sub {
            return unless $_[0]->is_dir;
            $target = $_[0] if $_[0]->dir_list(-1) eq $self->personality
        });
        last if $target;
    }
    confess (sprintf "couldn't find Personality '%s' within your Library\n",
            $self->personality) unless $target;

    my @phrasebooks = ();
    my $root = Path::Class::Dir->new();
    foreach my $part ( $target->dir_list ) {
        $root = $root->subdir($part);
        next if scalar grep { $root->subsumes($_) } @libs;
        push @phrasebooks,
            sort {$a->basename cmp $b->basename}
            grep { not $_->is_dir } $root->children(no_hidden => 1);
    }

    confess (sprintf "Personality [%s] contains no content!\n",
            $self->personality) unless scalar @phrasebooks;
    return @phrasebooks;
}

1;

# ABSTRACT: Load Interact Phrasebooks from a Library

=head1 DESCRIPTION

This module implements the loading and preparing of Interact Phrasebooks from
an on-disk file-based hierarchical library. In our context, a phrasebook can
contain either I<prompt> or I<macro> directives.

Prompts are simply named regular expressions that will match the content of a
single line of text. Macros are alternating sequences of CLI commands and
regular expressions, with a few more options as described below.

Each Prompt or Macro is baked into an instance of the class
L<Net::CLI::Interact::ActionSet>.

=head1 USAGE

A phrasebook is a plain text file containing named Prompts or Macros. Each
file exists in a directory hierarchy, such that files "deeper" in the
hierarchy have their entries override the similarly named entries higher up.
For example:

 /dir1/file1
 /dir1/file2
 /dir1/dir2/file3

Entries in C<file3> sharing a name with any entries from C<file1> or C<file2>
will take precedence. Those in C<file2> will also override entries in
C<file1>, because asciibetical sorting places the files in that order.

When the module is loaded, a I<personality> is given. This locates a directory
on disk, and then the files in that directory and all its ancestors in the
hierarchy are loaded. The hierarchy is specified by two I<library> options.

=head1 PARAMETERS

=over 4

=item personality($directory)

The name of a directory on disk. Any files higher in the libraries hierarchy
are also loaded, but entries in files contained within this directory, or
"closer" to it, will take precedence.

=item library($directory | \@directories)

First library hierarchy, specified either as a single directory or a list of
directories that are searched in order. The idea is that this option be set in
your application code, perhaps specifying some directory of phrasebooks
shipped with the distribution.

=item add_library($directory | \@directories)

Second library hierarchy, specified either as a single directory or a list of
directories that are searched in order. This parameter is for the end-user to
provide the location(s) of their own phrasebook(s).

=back

=head1 PHRASEBOOK FORMAT

=head2 Prompt

A Prompt is a named regular expression which matches the content of a single
line of text. Here is an example:

 prompt configure
     match /\(config[^)]*\)# ?$/

On the first line is the keyword C<prompt> followed by the name of the Prompt,
which must be a valid Perl identifier (letters, numbers, underscores only).

On the immediately following line is the keyword C<match> followed by a
regular expression, enclosed in two forward-slash characters. Currently, no
alternate bookend characters are supported, nor are regular expression
modifiers (such as C<xism>) outside of the match, but you can of course
include them within.

The Prompt is used to find out when the connected CLI has emitted all of the
response to a command. Try to make the Prompt as specific as possible,
including line-end anchors.

=head2 Macro

In general Macros are alternating sequences of commands to send to the
connected CLI, and regular expressions to match the end of the returned
response. Macros are useful for issueing commands which have intermediate
prompts, or confirmation steps. They also support the I<slurping> of
additional output when the connected CLI has split the response into pages.

At its simplest a Macro can be just one command:

 macro show_int_br
     send show ip int br
     match /> ?$/

On the first line is the keyword C<macro> followed by the name of the Macro,
which must be a valid Perl identifier (letters, numbers, underscores only).

On the immediately following line is the keyword C<send> followed by a space
and then any text up until the end of the line. This text is sent to the
conneted CLI as a single command statement. The following line contains the
keyword C<match> followed by the Prompt (regular expression) which will
terminate gathering of returned output from the sent command.

=over 4

=item Automatic Matching

Normally, you ought always to specify C<send> statements along with a
following C<match> statement so that the module can tell when the output from
your command has ended. However you can omit the Match and the module will
insert either the current C<prompt> value if set by the user, or the last
Prompt from the last Macro. So the above could be written as:

 macro show_int_br
     send show ip int br

You can have as many C<send> statements as you like, and the Match statements
will be inserted for you:

 macro show_int_br_and_timestamp
     send show ip int br
     send show clock

However it is recommended that this type of sequence be implemented as
individual commands rather than a Macro, as it will be easier for you to
retrieve the command response(s). Normally the Automatic Matching is used just
to allow missing off of the final Match statement when it's the same as the
current Prompt.

=item Format Interpolation

Each <send> statement is in fact run through Perl's C<sprintf> command, so
variables may be interpolated into the statement using standard C<%> fields.
For example:

 macro show_int_x
     send show interface %s

The method for passing variables into the module upon execution of this Macro
is documented elsewhere. This feature is useful for username/password prompts.

=item Named Match References

If you're going to use the same Match (regular expression) in a number of
Macros, then set it up as a Prompt (see above) and refer to it by name,
instead:

 prompt priv_exec
     match /# ?$/
 
 macro to_priv_exec
     send enable
     match /[Pp]assword: ?$/
     send %s
     match prompt priv_exec

As you can see, in the cae of the last Match, we have the keywords C<match
prompt> followed by the name of a defined Prompt.

=item Continuations

Sometimes the connected CLI will not know it's talking to a program and so
paginate the output (that is, split it into pages). There is usually a
keypress required between each page. This is supported via the following
syntax:

 macro show_run
     send show running-config
     follow / --More-- / with ' '

On the line following the C<send> statement is the keyword C<follow> and a
regular expression enclosed in forward-slashes. This is the Match which will,
if seen in the command output, trigger the continuation. On the line you then
have the keyword C<with> followed by a space and some text, until the end of
the line. If you need to enclose whitespace use quotes, as in the example.

The module will send the continuation text and gobble the matched prompt from
the emitted output so you only have one complete piece of text returned, even
if split over many pages. Metacharacters such as newlines are not yet
supported in the continuation text.

Note that in the above example the C<follow> statement should be seen as an
extension of the C<send> statement. There is an implicit Match prompt added at
the end, as per Automatic Matching, above.

=item Line Endings

Normally all sent command statements are appended with a newline (or the value
of C<ors>, if set). To suppress that feature, use the keyword C<send_literal>
instead of C<send>. However this does not prevent the Format Interpolation via
C<sprintf> as described above (which is not necessary: simply use C<%%>).

=back

=cut
