use utf8;
package Twitter::DdbKatzen::Schema::Result::Tweet;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Twitter::DdbKatzen::Schema::Result::Tweet

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<tweets>

=cut

__PACKAGE__->table("tweets");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 ddb_identifier

  data_type: 'text'
  is_nullable: 0

=head2 tweet_date

  data_type: 'date'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "ddb_identifier",
  { data_type => "text", is_nullable => 0 },
  "tweet_date",
  { data_type => "date", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2014-02-26 21:39:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nhSJQCwe7X/tjJaCvtJ8aA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
