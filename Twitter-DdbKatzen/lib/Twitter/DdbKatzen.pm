package Twitter::DdbKatzen;

=head1 NAME

Twitter::DdbKatzen - The great new Twitter::DdbKatzen!

=head1 VERSION

Version 2.0

=head2 METHODS

=cut

use strict;
use warnings;
use namespace::autoclean;

use FindBin qw($Bin);
use Log::Log4perl qw( :levels);

use DateTime;
use DateTime::Format::SQLite;
use Encode;
use JSON;
use List::Util qw( shuffle);
use LWP::Simple qw(get $ua);
use Net::Twitter;
use POSIX;
use Switch;
use URI::Escape;

use Data::Dumper;

use lib "../";
use Twitter::DdbKatzen::Schema;

our $VERSION = '2.0';

use Moose;

with
  qw( MooseX::Getopt MooseX::Log::Log4perl MooseX::Daemonize MooseX::Runnable   );

use Moose::Util::TypeConstraints;

subtype 'File', as 'Str',
  where { -e $_ },
  message { "Cannot find any file at $_" };

has 'debug' => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => "if set, tweets are just logged, not sent"
);
has 'dont_close_all_files' => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => "required for demon to run, no idea why"
);
has 'sqlite_db' => (
    is            => 'ro',
    isa           => 'File',
    required      => 1,
    documentation => "sqlite_db to store tweets, in order to avoid repetitions"
);
has 'name' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "name of the demon"
);
has 'ddb_api_key' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "API Key for 'Deutsche Digitale Bibliothek'"
);
has 'ddb_api_url' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "API Key for 'Deutsche Digitale Bibliothek'"
);
has 'twitter_account' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "Twitter Account to use"
);
has 'twitter_consumer_key' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "Twitter Authentication"
);
has 'twitter_consumer_secret' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "Twitter Authentication"
);
has 'twitter_access_token' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "Twitter Authentication"
);
has 'twitter_access_token_secret' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "Twitter Authentication"
);
has 'url_shortener' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => "which url shortener to use"
);

has 'sleep_time' => (
    is            => 'ro',
    isa           => 'Int',
    default       => 2000,
    documentation => "how many seconds to wait between tweets"
);

has 'duplicate_limit' => (
    is            => 'ro',
    isa           => 'Int',
    default       => 3,
    required      => 0,
    documentation => "how many days until a duplicate post is allowed"
);

no Moose::Util::TypeConstraints;

Log::Log4perl::init( $Bin . '/logging.conf' );

=head2 run

called by the perl script

=cut

sub run {
    my $self = shift;
    $self->start();
    exit(0);
}

after start => sub {
    my $self = shift;

    return unless $self->is_daemon;

    $self->log->info("Daemon started..");

    $self->{Schema} =
      Twitter::DdbKatzen::Schema->connect( 'dbi:SQLite:' . $self->sqlite_db );
    $self->{globalDuplicatesCount} = 0;

    $self->createTwitterObject();

    while (1) {

        # what shall we do? let's roll the dice?

        eval {
            $self->rollTheDice();

        };
        if ($@) {
            $self->log->error( "Oh problem!: " . $@ );
        }
        else {

            $self->log->debug(
                "I'm going to sleep for " . $self->sleep_time . " seconds.." );
            sleep( $self->sleep_time );
        }

    }

};

after status => sub {
    my $self = shift;
    $self->log->info("Status check..");
};

before stop => sub {
    my $self = shift;
    $self->log->info("Daemon ended..");
};

=head2 rollTheDice

roll the dice and start corresponding action

=cut

sub rollTheDice {

    my $self   = shift;
    my $random = undef;
    my $range  = 100;

    $random = int( rand($range) );
    $self->log->info( "The dice said: " . $random . "!" );

    switch ($random) {

        case [ 0 .. 94 ]{ $self->writeCatTweet(); }
        case [ 95 .. 100 ]{ $self->writeRandomAnimalTweet(); }
    }

}

=head2 createTwitterObject()

authenticate to Twitter and return a C<Net::Twitter>-object

=cut

sub createTwitterObject {
    my $self    = shift;
    my $Twitter = Net::Twitter->new(
        traits              => [qw/API::RESTv1_1/],
        consumer_key        => $self->twitter_consumer_key,
        consumer_secret     => $self->twitter_consumer_secret,
        access_token        => $self->twitter_access_token,
        access_token_secret => $self->twitter_access_token_secret,
        ssl                 => 1,
    ) || $self->log->logdie("Could not create Twitter-Object: $!");

    $self->{Twitter} = $Twitter;
    $self->log->debug("Twitter Object created");
}

=head2 getDDBResults(Query=>'Linz', Field=>'title', Type=>'IMAGE', Rows=>10)

searches Europeana and returns the first matching Result

Parameters

=over 

=item  * Query

querystring for the search

=item * Field

which index to use

=item * Type

type of result, defaults to  I<mediatype_002> (image)

=items * Rows

how many rows should be returned, defaults to C<1>

=back

=cut

sub getDDBResults {
    my ( $self, %p ) = @_;
    my $json_result  = undef;
    my $result_ref   = undef;
    my $query_string = undef;
    my @items        = ();
    my $return       = undef;

    $p{Type} = 'mediatype_002' unless ( defined( $p{Type} ) );
    $p{Rows} = 20 unless ( defined( $p{Rows} ) );

    $self->log->debug( "Query: " . $p{Query} );

    #build $query_string
    eval {
        $query_string = sprintf(
"%s/search?oauth_consumer_key=%s&rows=%s&query=%s:%s&facet=type_fct&type_fct=%s",
            $self->ddb_api_url, $self->ddb_api_key, $p{Rows}, $p{Field},
            uri_escape_utf8( $p{Query} ),
            $p{Type}
        );
    };

    if ($@) {

        $self->log->error( "Error while creating query string: " . $@ );
        $return->{Status} = "NotOK";
        $return->{Query}  = $p{Query};
        return $return;
    }

    $self->log->debug( "QueryString is: " . $query_string );
    if ( $json_result = get $query_string) {
        $result_ref = decode_json($json_result);
        $self->log->debug(
            "Found " . $result_ref->{numberOfResults} . " items.." );
        if ( $result_ref->{numberOfResults} > 0 ) {

            # items found, now get an item view for a random result
            @items = shuffle( @{ $result_ref->{results}->[0]->{docs} } );

            $self->log->info( "get item " . $items[0]->{id} );
            $self->log->info( "thumbnail " . $items[0]->{thumbnail} );
            $return->{Thumbnail} = $items[0]->{thumbnail};
            $return->{ThumbnailData} =
              get "https://www.deutsche-digitale-bibliothek.de"
              . $return->{Thumbnail};

            # $self->log->debug( "Item is: " . Dumper( $items[0] ) );

            eval {
                $query_string =
                  sprintf( "%s/items/%s/view?oauth_consumer_key=%s",
                    $self->ddb_api_url, $items[0]->{id}, $self->ddb_api_key );
            };

            if ($@) {
                $self->log->error( "Error while creating query string: " . $@ );
                $return->{Status} = "NotOK";
                $return->{Query}  = $p{Query};
                return $return;
            }

            $self->log->debug( "Querystring for item is: " . $query_string );

            if ( $json_result = get $query_string) {
                $result_ref = decode_json($json_result);

                $self->log->debug( "Found item" . Dumper($result_ref) );

                $return->{Identifier} = $result_ref->{item}->{'identifier'};

                $return->{Title} =
                  decode( 'iso-8859-1', $result_ref->{item}->{'title'} );
                $return->{Title} = encode( 'utf-8', $return->{Title} );

                # get direct link to item
                if (   ( defined( $result_ref->{item}->{'origin'} ) )
                    && ( $result_ref->{item}->{'origin'} =~ /href="(.*?)"/ ) )
                {
                    $return->{Url} = $1;
                }

                # parse more fields
                foreach
                  my $field ( @{ $result_ref->{item}->{fields}->{field} } )
                {

                    switch ( $field->{name} ) {

                        case 'Geschaffen (wann)' {
                            $return->{Date} = $field->{value};
                        }

                    }
                }

                # custom enrichment
                $return->{Status} = "OK";
                $return->{Query}  = $p{Query};

                # $self->log->debug( "Assembled result: " . Dumper($return) );

                return $return;
            }
            else {
                $return->{Status} = "NotOK";
                $return->{Query}  = $p{Query};
                return $return;
            }

        }
        else {
            $return->{Status} = "NotOK";
            $return->{Query}  = $p{Query};
            return $return;
        }

    }

}

=head2 post2Twitter(Message=>'So.. you like cats? Here's a picture from #europeana: _URL_', Result=>$result)

posts the result to the twitter account specified by C<$self->twitter_account>

Parameters

=over

=item  * Message

message to post, you can use the following placeholders C<_TITLE_>, C<_YEAR_>,
C<_URL_>

=item  * Result

Europeana Search Result

=back

=cut

sub post2Twitter {
    my ( $self, %p ) = @_;
    my $nt_result = undef;
    my $short_url = undef;
    my $status    = undef;
    my $timestamp = DateTime::Format::SQLite->format_datetime( DateTime->now );

    $status = $p{Message};

    $short_url = get( $self->url_shortener . $p{Result}->{Url} );

    $status =~ s/_TITLE_/$p{Result}->{Title}/;
    $status =~ s/_URL_/$short_url/;

    if ( defined( $p{Result}->{Date} ) ) {
        $status =~ s/_YEAR_/$p{Result}->{Date}/;

    }
    else {
        $status =~ s/ (aus) _YEAR_//;

    }

    if ( defined( $p{Result}->{Title} ) ) {
        $status =~ s/_TITLE_/$p{Result}->{Title}/;

    }
    else {
        $status =~ s/ '_TITLE_'//;

    }

    $status = decode( 'utf8', $status );
    $self->log->info(
        "Posting Status: " . $status . " (" . length($status) . ")" );

    if ( $self->debug == 1 ) {
        $self->log->info("Just kidding! We are in debug mode...");
    }
    else {

        if ( length($status) > 140 ) {
            $self->log->warn("Status is too long!");
        }
        else {

            eval {
                $nt_result = $self->{Twitter}->update_with_media(
                    $status,
                    [
                        undef,
                        $p{Result}->{Thumbnail},
                        Content => $p{Result}->{ThumbnailData}
                    ]
                );
            };
            if ($@) {
                $self->logger->error( "Error posting to "
                      . $self->twitter_account . ": "
                      . $@
                      . "!" );

            }
            else {
                # write to database
                $self->{Schema}->resultset('Tweet')->create(
                    {
                        ddb_identifier => $p{Result}->{Identifier},
                        tweet_date     => $timestamp
                    }
                );

            }
        }

        # $self->log->debug( Dumper($nt_result) );
    }

} ## end sub post2Twitter

=head2 writeCatTweet()

posts a cat picture

=cut

sub writeCatTweet {
    my $self       = shift;
    my $result_ref = undef;
    my @messages   = (
        "Katzenbild aus der \#ddb! '_TITLE_' aus _YEAR_: _URL_",
        "\#ddb eine Katze bitte! OK, '_TITLE_' aus _YEAR_: _URL_",
        "Oh! Katzen in der #ddb: '_TITLE_' aus _YEAR_ _URL_",
        "Katze gefällig? Aus der #ddb: '_TITLE_' aus _YEAR_: _URL_",
"Und schon wieder ein Katzenbild aus der #ddb: '_TITLE_' aus _YEAR_: _URL_",
        "OK, Internet du magst Katzenbilder: '_TITLE_' aus _YEAR_: _URL_ #ddb",
        "Internet, Katze; #ddb, '_TITLE_' aus _YEAR_: _URL_",
"Ja die Deutsche Digitale Bibliothek hat auch Katzenbilder:  '_TITLE_' aus _YEAR_: _URL_ #ddb",
        "Ganz etwas originelles:  '_TITLE_' aus _YEAR_: _URL_ #ddb",
"In der Deutschen Digitalen Bibliothek gefunden: '_TITLE_' aus _YEAR_: _URL_ #ddb",
"<Geistreichen Tweet zu Katzen einfügen>:  '_TITLE_' aus _YEAR_: _URL_ #ddb",
    );
    my @terms =
      ( "katze", "katzen", "hauskatze", "kaetzchen" )
      ;    # avoid those pesky umlauts..

    @messages = shuffle @messages;
    @terms    = shuffle @terms;

    $self->log->debug("I'm gonna tweet about cats!");

    $result_ref = $self->getDDBResults(
        Query => $terms[0],
        Field => 'title',
        Rows  => 250
    );

    # not very elegant but simple
    if (
        (
            $self->checkForDuplicate(
                Identifier => $result_ref->{Identifier}
            ) eq 'OK'
        )

        && ( $result_ref->{Status} eq 'OK' )
      )
    {
        $self->post2Twitter(
            Result  => $result_ref,
            Message => $messages[0]
        );

        return;
    }
    else {

        # start again
        $self->rollTheDice();
        return;

    }
}

=head2 writeRandomAnimalTweet()

posts a picture of another animal

=cut

sub writeRandomAnimalTweet {
    my $self       = shift;
    my $result_ref = undef;
    my @messages   = (
        "Immer nur Katzen ist langweilig! '_TITLE_' aus _YEAR_: _URL_ \#ddb",
        "\#ddb überrasche mich mal! OK, '_TITLE_' aus _YEAR_: _URL_",
"In der Deutschen Digitalen Bibliothek keine Katze gefunden: '_TITLE_' aus _YEAR_: _URL_ #ddb",

    );
    my @terms = ( "hund", "maus", "eichhoernchen", "einhorn", "pony", "hamster" )
      ;    # avoid those pesky umlauts..

    @messages = shuffle @messages;
    @terms    = shuffle @terms;

    $self->log->debug("I'm gonna tweet about $terms[0]!");

    $result_ref = $self->getDDBResults(
        Query => $terms[0],
        Field => 'title',
        Rows  => 250
    );

    # not very elegant but simple
    if (
        (
            $self->checkForDuplicate(
                Identifier => $result_ref->{Identifier}
            ) eq 'OK'
        )

        && ( $result_ref->{Status} eq 'OK' )
      )
    {
        $self->post2Twitter(
            Result  => $result_ref,
            Message => $messages[0]
        );

        return;
    }
    else {

        # start again
        $self->rollTheDice();
        return;

    }

}

=head2 checkForDuplicate(Identifier=>'oai:dafadsfdsfdsf')

checks C<sqlite_db> if the specified image has already been posted
within C<duplicate_period>

returns C<OK> or the day of the last tweet 

=cut

sub checkForDuplicate {
    my ( $self, %p ) = @_;
    my $return = undef;
    my $check_date = DateTime->now->subtract( days => $self->duplicate_limit );

    my $resultSet = undef;
    my $row       = undef;

    $self->log->debug( "Checking "
          . $p{Identifier}
          . " with limit "
          . $self->duplicate_limit
          . "!" );

    $resultSet = $self->{Schema}->resultset('Tweet')->search(
        {
            '-and' => [
                'ddb_identifier' => $p{Identifier},
                'tweet_date'     => {
                    '>' => DateTime::Format::SQLite->format_datetime($check_date)
                  }

            ]
        },
        { 'order_by' => { -desc => 'tweet_date' } }
    );

    if ( $resultSet->count == 0 ) {
        $self->{globalDuplicatesCount}--;
        return "OK";
        
    }
    else {

        $self->{globalDuplicatesCount}++;

        #calm down, if too many duplicates in a row
        if ( $self->{globalDuplicatesCount} > 30 ) {
            $self->{globalDuplicatesCount};
            $self->log->warn("Wow! Too many duplicates.. I'm taking a nap...");

            sleep( $self->sleep_time );
        }

        # duplicates found, log the first and return
        $row = $resultSet->next;

        $self->log->info( $resultSet->count
              . " Duplicates found, "
              . $row->ddb_identifier
              . " already tweeted on "
              . $row->tweet_date );

        return $row->tweet_date;
    }

}

__PACKAGE__->meta->make_immutable;

1;    # End of Twitter::EuropeanaBot

=head1 AUTHOR

Peter Mayr, C<< <at.peter.mayr at gmail.com> >>

=head1 BUGS

Please report any bugs at L<https://github.com/hatorikibble/twitter-europeanabot>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Twitter::EuropeanaBot


You can also look for information at:

=over 4

=item * GitHub

L<https://github.com/hatorikibble/twitter-europeanabot>

=back


=head1 ACKNOWLEDGEMENTS

Basic idea taken from L<https://twitter.com/DPLAbot>

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Peter Mayr.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

