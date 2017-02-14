FROM ruby:2.3-alpine

RUN mkdir /app
COPY Gemfile /app
COPY Gemfile.lock /app
WORKDIR /app
RUN bundle config --global frozen 1 && bundle install

COPY . /app
