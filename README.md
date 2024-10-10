# Siign

Integrate [Tiime][] with [Docage][] to sign quotes.

Features:

- list Tiime quotes
- create Docage transaction from Tiime quotes
- Provide a simple interface for customers to sign quotes
- Update quote status to Tiime
- Receive notification once the quote change

## Configuration

You should the following environment variables:

```
# Tiime user email
TIIME_USER=
# Tiime password
TIIME_PASSWORD=
# Docage email
DOCAGE_USER=
# Docage API key
DOCAGE_API_KEY=
# Enable docage test mode to not consume credits
DOCAGE_TEST_MODE=true
# The path to the sqlite database
DB_PATH=
# The webhook secret to protect the endpoint
WEBHOOK_SECRET=myimportantsecrettonotallowh4ck3rtosendnotification
# The notification URL when the quote is signed, refused, expired or aborted ${msg} will be replaced by the corresponding message
NOTIFICATION_URL=https://xxx.com?msg=${msg}
```

## Usage

    bundle exec puma

## Tests

    bundle exec rspec

## License

AGPL v3

[tiime]: https://www.tiime.fr/
[docage]: https://www.docage.com/
