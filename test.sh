#!/bin/bash

docker build -t saas/check_prometheus .
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --net=host \
  saas/check_prometheus \
  bash -c '\
    trap "docker-compose down --rmi all > /dev/null; docker-compose rm -f > /dev/null" EXIT; \
    ruby test.rb'
