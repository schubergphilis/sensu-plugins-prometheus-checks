#!/bin/bash -e

docker build -t saas/check_prometheus .
docker run --rm -e TRAVIS=$TRAVIS saas/check_prometheus rspec -c -f d
docker run --rm saas/check_prometheus rubocop
