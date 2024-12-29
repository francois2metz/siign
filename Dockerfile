FROM ruby:3.4-bookworm

RUN set -eux ;\
    DEBIAN_FRONTEND=noninteractive apt-get update ;\
    DEBIAN_FRONTEND=noninteractive apt-get install  -y --no-install-recommends sqlite3

WORKDIR /code/siign

COPY . .

RUN bundle config set deployment true && \
    bundle config set without 'test' 'development' && \
    bundle install

CMD ["bundle", "exec", "puma", "--environment", "production"]

EXPOSE 9292
