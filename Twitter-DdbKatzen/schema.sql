 CREATE TABLE tweets (
    id INTEGER PRIMARY KEY NOT NULL,
    ddb_identifier TEXT NOT NULL,
    tweet_date DATE NOT NULL
  );

  CREATE index ddb_identifier_idx on tweets (ddb_identifier);
  CREATE index tweet_date_idx on tweets (tweet_date);