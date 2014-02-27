twitter-ddbkatzen
====================

Ein TwitterBot der die [Deutsche Digitale Bibliothek] (https://www.deutsche-digitale-bibliothek.de) nach Katzenbildern durchsucht

    usage: ddbkatzen [-?fh] [long options...]
	--pidbase                          the base for our pid (default:
	                                   /var/run)
	--progname                         the name of the daemon
	--stop_timeout                     number of seconds to wait for the
	                                   process to stop, before trying
	                                   harder to kill it (default: 2 s)
	--logger                            
	--ignore_zombies                    
	--no_double_fork                    
	--basedir                          the directory to chdir to
	                                   (default: /)
	--pidfile                           
	-h -? --usage --help               Prints this usage information.
	-f --foreground                    if true, the process won't
	                                   background
	--debug                            if set, tweets are just logged,
	                                   not sent
	--dont_close_all_files             required for demon to run, no idea
	                                   why
	--sqlite_db                        sqlite_db to store tweets, in
	                                   order to avoid repetitions
	--name                             name of the demon
	--ddb_api_key                      API Key for 'Deutsche Digitale
	                                   Bibliothek'
	--ddb_api_url                      API Key for 'Deutsche Digitale
	                                   Bibliothek'
	--twitter_account                  Twitter Account to use
	--twitter_consumer_key             Twitter Authentication
	--twitter_consumer_secret          Twitter Authentication
	--twitter_access_token             Twitter Authentication
	--twitter_access_token_secret      Twitter Authentication
	--url_shortener                    which url shortener to use
    --sleep_time                       how many seconds to wait between
	                                   tweets
	--duplicate_limit                  how many days until a duplicate
	                                   post is allowed


Database creation
---------------

create SQLite Database with

    >sqlite3 tweets.db < schema.sql
