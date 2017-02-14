#!/bin/bash

docker build -t saas/check_prometheus .
docker run --rm saas/check_prometheus rspec -c -f d && rubocop
