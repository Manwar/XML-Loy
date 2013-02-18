package MojoX::XML::Atom;
use MojoX::XML with => (
  mime => 'application/atom+xml',
  prefix => 'atom',
  namespace => 'http://www.w3.org/2005/Atom'
);
#use Mojo::Date::RFC3339;
use Mojo::ByteStream 'b';


# Namespace declaration
use constant XHTML_NS => 'http://www.w3.org/1999/xhtml';

# Todo:
#  - see http://search.cpan.org/dist/XML-Atom-SimpleFeed

# New person construct
sub new_person {
  my $self = shift;
  my $person = ref($self)->SUPER::new('person');
  my %hash = @_;
  foreach (keys %hash) {
    $person->add($_, $hash{$_})
  };
  return $person;
};


# Add person information
sub _add_person {
  my $self = shift;
  my $type = shift;

  # Person is a defined node
  if (ref($_[0])) {
    my $person = shift;
    $person->root->at('*')->tree->[1] = $type;
    return $self->add($person);
  }

  # Person is a hash
  else {
    my $person = $self->add($type);
    my %data = @_;

    foreach (keys %data) {
      $person->add($_ => $data{$_} ) if $data{$_};
    };
    return $person;
  };
};


# New date construct
sub new_date {
  my $self = shift;
  my $time = shift || time;  # now
  return Mojo::Date::RFC3339->new($time);
};


# Add date construct
sub _add_date {
  my ($self, $type, $date) = @_;

  unless (ref($date)) {
    $date = $self->new_date($date);
  };

  return $self->add($type, $date->to_string);
};


# New text construct
sub new_text {
  my $self = shift;

  return unless $_[0];

  my $class = ref($self);

  unless (defined $_[1]) {
    return $class->SUPER::new(
      text => {
	type => 'text',
	-type => 'escape'
      } => shift);
  };

  my ($type, $content, %hash);

  if (!defined $_[2]) {
    $type = shift;
    $content = shift;
  }

  else {
    %hash = @_;

    $type = delete $hash{type} || 'text';

    if (exists $hash{src}) {
      return $class->SUPER::new(
	text => { type => $type, %hash }
      );
    };

    $content = delete $hash{content} or return;
  };

  my $c_node;

  # xhtml
  if ($type eq 'xhtml') {

    $c_node = $class->SUPER::new(
      text => {
	type => $type,
	%hash
      });

    $c_node->add(
      -div => {
	xmlns => XHTML_NS,
	-type => 'raw'
      } => $content);
  }

  # html or text
  elsif ($type eq 'html' || $type =~ /^text/i) {

    $c_node = $class->new(
      text => {
	'type'  => $type,
	'-type' => 'escape',
	'xml:space' => 'preserve',
	%hash
      } => b($content)->xml_escape . ''
    );
  }

  # xml media type
  elsif ($type =~ /[\/\+]xml(;.+)?$/i) {
    $c_node = $class->new(
      text => {
	type  => $type,
	-type => 'raw',
	%hash
      } => $content);
  }

  # all other media types
  else {
    $c_node = $class->new(
      text => {
	type => $type,
	-type => 'armour',
	%hash
      },
      $content);
  };

  return $c_node;
};


# Add text information
sub _add_text {
  my $self = shift;
  my $type = shift;

  # Text is a defined node
  if (ref($_[0])) {

    my $text = shift;

    # Get root element
    my $root_elem = $text->root->at('*');

    $root_elem->tree->[1] = $type;
    my $root_att = $root_elem->attrs;

    if (exists $root_att->{type} && $root_att->{type} eq 'text') {
      delete $root_elem->attrs->{'type'};
    };
    $text->root->at('*')->tree->[1] = $type;
    return $self->add($text);
  };

  my $text;
  # Text is no hash
  unless (defined $_[1]) {
    $text = $self->new_text(type => 'text',
			    content => shift );
  }

  # Text is a hash
  else {
    $text = $self->new_text(@_);
  };

  return $self->_add_text($type, $text) if ref $text;

  return;
};


# Add entry
sub add_entry {
  my $self = shift;

  if (ref($_[0])) {
    return $self->add(@_);
  };

  my %hash = @_;
  my $entry;

  # Set id additionally as xml:id
  if (exists $hash{id}) {
    $entry = $self->add('entry',
			{'xml:id' => $hash{id}});
  }

  # No id given
  else {
    $entry = $self->add('entry');
  };

  # Add information
  foreach (keys %hash) {
    $entry->add($_, $hash{$_});
  };

  return $entry;
};


# Add content information
sub add_content {
  shift->_add_text( content => @_);
};


# Add author information
sub add_author {
  shift->_add_person( author => @_);
};


# Add category information
sub add_category {
  my $self = shift;

  return unless $_[0];

  if (!defined $_[1]) {
    return $self->SUPER::add(category => { term => shift });
  };

  return $self->SUPER::add(category => { @_ } );
};


# Add contributor information
sub add_contributor {
  shift->_add_person(contributor => @_);
};


# Add generator information
sub add_generator {
  shift->add(generator => @_);
};


# Add icon
sub add_icon { # only one
  shift->add(icon => shift);
};


# Add id
sub add_id { # must one
  my $self = shift;
  my $id = shift;
  return unless $id;
  my $element = $self->add(id => $id);
  $element->parent->attrs('xml:id' => $id);
  return $self;
};


# Add link information
sub add_link {
  my $self = shift;
  unless (defined $_[1]) {
    return $self->add(link  => {
      rel  => 'related',
      href => shift
    });
  } elsif (@_ == 2) {
    return $self->add(link => {
      rel  => shift,
      href => shift
    });
  };

  my %values = @_;
  # href, rel, type, hreflang, title, length
  my $rel = delete $values{rel} || 'related';
  return $self->add( link => { rel => $rel, %values });
};


# Add logo
sub add_logo {
  shift->add(logo => shift);
};


# Add publish time information
sub add_published {
  shift->_add_date(published => @_);
};


# Add rights information
sub add_rights {
  shift->_add_text(rights => @_);
};


# Add source information
sub add_source {
  shift->add(source => { @_ });
};


# Add subtitle
sub add_subtitle {
  shift->_add_text(subtitle => @_);
};


# Add summary
sub add_summary {
  shift->_add_text(summary => @_);
};


# Add title
sub add_title {
  shift->_add_text('title', @_);
};


# Add update time information
sub add_updated {
  shift->_add_date(updated => @_);
};


1;

__END__

=pod

=head1 NAME

MojoX::XML::Atom - Atom Syndication Format

=head1 SYNOPSIS

  # Mojolicious
  $app->plugin(XML => {
    new_atom => ['Atom']
  });

  # Mojolicious::Lite
  plugin XML => {
    new_atom => ['Atom']
  };

  # In Controllers
  my $feed = $self->new_atom( 'feed' );

  my $author = $feed->new_person( name => 'Fry' );
  $feed->add_author($author);
  $feed->add_title('This is a test feed.');
  my $entry = $self->new_atom('entry');

  for ($entry) {
    $_->add_title('First Test entry');
    $_->add_subtitle('This is a subtitle');
    my $content = $_->add_content(
	type    => 'xhtml',
	content => '<p id="para">' .
	           'This is a Test!' .
	           '</p>');
    $content->at('#para')
	->replace_content('This is a <strong>Test</strong>!');
  };

  $feed->add_entry($entry);
  $self->render_xml($feed);

=head1 DESCRIPTION

L<MojoX::XML::Atom> is a base class or extension
for L<MojoX::XML> and provides several functions
for the work with the Atom Syndication Format as described in
L<RFC4287|http://tools.ietf.org/html/rfc4287>.

=head1 METHODS

L<Mojolicious::Plugin::XML::Atom> inherits all methods
from L<MojoX::XML> and implements the
following new ones.

=head2 C<new_text>

  my $text = $atom->new_text('This is a test');
  my $text = $atom->new_text(xhtml => 'This is a <strong>test</strong>!');
  my $text = $atom->new_text(
    type => 'xhtml',
    content => 'This is a <strong>test</strong>!'
  );

Returns a new text construct. Accepts either a simple string
(of type 'text'), a tupel with the first argument being the media type and
the second argument being the content, or a hash with the parameters C<type>,
C<content> or C<src> (and others). There are three predefined
C<type> values:

=over 2

=item C<text> for textual data

=item C<html> for HTML data

=item C<xhtml> for XHTML data

=back

C<xhtml> data is automatically wrapped in a
namespaced C<div> element, see
L<RFC4287, Section 3.1|http://tools.ietf.org/html/rfc4287.htm#section-3.1>
for further details.

=head2 C<new_person>

  my $person = $atom->new_person(
    name => 'Bender',
    uri  => 'acct:bender@example.org'
  );

Returns a new person construction.

=head2 C<new_date>

  my $date = $atom->new_date(1312311456);
  my $date = $atom->new_date('1996-12-19T16:39:57-08:00');

Returns a L<Mojo::Date::RFC3339> object.
It accepts all parameters of L<Mojo::Date::RFC3339::parse>.
If no parameter is given, the current server time is returned.

=head2 C<add_entry>

  my $entry = $atom->add_entry(id => '#Entry1');

Adds an entry to the Atom object.
Accepts a hash of simple entry information.

=head2 C<add_content>

  my $text = $atom->new_text(
    type => 'xhtml',
    content => '<p>This is a <strong>test</strong>!</p>'
  );

  $atom->add_content($text);
  $atom->add_content('This is a test!');

Adds content information to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.

=head2 C<add_author>

  my $person = $atom->new_person( name => 'Bender',
                                  uri  => 'acct:bender@example.org');
  my $author = $atom->add_author($person);

Adds author information to the Atom object.
Accepts a person construct (see L<new_person>) or the
parameters accepted by L<new_person>.

=head2 C<add_category>

  $atom->add_category('world');

Adds category information to the Atom object.
Accepts either a hash for attributes (with, e.g., term and label)
or one string representing the categories term.

=head2 C<add_contributor>

  my $person = $atom->new_person( name => 'Bender',
                                  uri  => 'acct:bender@example.org');
  my $contributor = $atom->add_contributor($person);

Adds contributor information to the Atom object.
Accepts a person construct (see L<new_person>) or the
parameters accepted by L<new_person>.

=head2 C<add_generator>

  $atom->add_generator('Sojolicious-Atom-Plugin');

Adds generator information to the Atom object.

=head2 C<add_icon>

  $atom->add_icon('http://sojolicio.us/favicon.ico');

Adds a URI to an icon associated with the Atom object.
The image should be suitable for small representation size
and have an aspect ratio of 1:1.

=head2 C<add_id>

  $atom->add_id('http://sojolicio.us/#12345');

Adds a unique identifier to the Atom object.

=head2 C<add_link>

  $atom->add_link('http://sojolicio.us/#12345');
  $atom->add_link(related => 'http://sojolicio.us/#12345');
  $atom->add_link(rel => 'self',
                  href => 'http://sojolicio.us/#12345');

Adds link information to the Atom object. If no relation
attribute is given, the default relation is 'related'.
Accepts either one scalar as a reference of a related link,
a pair of scalars for the relational type and the reference
or multiple hashes for the attributes of the link.

=head2 C<add_logo>

  $atom->add_logo('http://sojolicio.us/sojolicious.png');

Adds a URI to a logo associated with the Atom object.
The image should have an aspect ratio of 2:1.

=head2 C<add_published>

  my $date = $atom->new_date(1312311456);
  $atom->add_published($date);

Adds a publishing timestamp to the Atom object.
Accepts a date construct (see L<new_date>) or the
parameter accepted by L<new_date>.

=head2 C<add_rights>

  $atom->add_rights('Public Domain');

Adds legal information to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.

=head2 C<add_source>

  my $source = $atom->add_source('xml:base' =>
    'http://source.sojolicio.us/');
  $source->add_author(name => 'Zoidberg');

Adds source information of the Atom object.

=head2 C<add_subtitle>

  my $text = $atom->new_text(type => 'text',
                             content => 'This is a subtitle!');

  $atom->add_subtitle($text);
  $atom->add_subtitle('This is a subtitle!');

Adds subtitle information to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.

=head2 C<add_summary>

  my $text = $atom->new_text(type => 'text',
                             content => 'Test entry');

  $atom->add_summary($text);
  $atom->add_summary('Test entry');

Adds a summary of the content to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.

=head2 C<add_title>

  my $text = $atom->new_text(type => 'text',
                             content => 'First Test entry');

  $atom->add_title($text);
  $atom->add_title('First Test entry');

Adds a title to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.

=head2 C<add_updated>

  my $date = $atom->new_date(1312311456);
  $atom->add_updated($date);

Adds a last update timestamp to the Atom object.
Accepts a date construct (see L<new_date>) or the
parameter accepted by L<new_date>.

=head1 MIME-TYPES

When loaded as a base class, L<MojoX::XML::Atom>
establishes the following mime-types:

  'atom': 'application/atom+xml'

=head1 DEPENDENCIES

L<Mojolicious>,
L<MojoX::XML>,
L<Mojo::Date::RFC3339>.

=head1 AVAILABILITY

  https://github.com/Akron/Sojolicious

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2012, Nils Diewald.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut