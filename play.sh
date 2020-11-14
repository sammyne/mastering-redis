#!/bin/bash

tag=6.0.9-alpine3.12

docker run --name mastering-redis -d redis:${tag}