use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Twitter::DdbKatzen',
    AUTHOR        => q{Peter Mayr <at.peter.mayr@gmail.com>},
    VERSION_FROM  => 'lib/Twitter/DdbKatzen.pm',
    ABSTRACT_FROM => 'lib/Twitter/DdbKatzen.pm',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
        ? ( 'LICENSE' => 'perl' )
        : () ),
    EXE_FILES => ['bin/ddbkatzen'],
    PL_FILES  => {},
    PREREQ_PM => {
        'Test::More'            => 0,
        'Config::Any::JSON'     => 0,
        'DateTime'              => 0,
        'DateTime::Format::SQLite' => 0,
        'DBD::SQLite'           => '1.40',
        'DBIx::Class::Schema'   => 0,
        'File::Slurp'           => 1,
        'JSON'                  => '2.59',
        'List::Util'            => 0,
        'Log::Log4perl'         => '1.29',
        'LWP::Simple'           => 0,
        'MooseX::Daemonize'     => '0.15',
        'MooseX::Getopt'        => 0,
        'MooseX::Log::Log4perl' => 0,
        'MooseX::Runnable'      => 0,
        'Net::Twitter'          => '4.01002',
        'Switch'                => 0,
        'URI::Escape'           => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Twitter-EuropeanaBot-*' },
);
