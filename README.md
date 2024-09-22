# Siign

Integrate [Tiime][] with [Docage][] to sign quotes.

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
```

## Usage

    bundle exec puma

## Tests

    bundle exec rspec

## License

AGPL v3

[tiime]: https://www.tiime.fr/
[docage]: https://www.docage.com/
