FROM ruby:2.3-alpine

RUN apk update && \
  apk add bash \
          curl  \
          py-pip && \
  pip install docker-compose==1.9.0rc1 && \
  gem install rspec

RUN curl -O https://artifacts.s3.storage.schubergphilis.com/artifacts/docker/1.10.3/docker && \
      chmod +x docker && \
      mv docker /usr/local/bin/

ADD . /app
WORKDIR /app
