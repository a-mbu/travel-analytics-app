#!/bin/bash
#run the following to build only :
# ./build-app.sh build
# to build and run :
# ./build-app.sh build compose
# to run docker compose :
# ./build-app.sh compose
if [[ $1 == "build" ]]; then
    docker build -t travel-analytics .
fi
if [[ $2 == "run" ]]; then
    docker run -p 5000:5000 travel-analytics
fi
if [[ $1 == "compose" ]]; then
    docker compose up;
fi
