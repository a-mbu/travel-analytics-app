#!/bin/bash
PORT="5000"
DOMAIN="localhost"
API_VERION="/api/v1"
BASE_URL="http://${DOMAIN}:${PORT}${API_VERION}"
INDEX_URL="http://${DOMAIN}:${PORT}/"
FLIGHTS_URL="${BASE_URL}/flights"
WHEATHER_URL="${BASE_URL}/weather"
DELAYS_URL="${BASE_URL}/analytics/delays"
HEALTH_URL="${BASE_URL}/health"
FILTER_URL_FMT="${FLIGHTS_URL}?airline=%s&origin=%s&destination=%s"
CITY_WEATHER_FMT="${WHEATHER_URL}/%s"
FILTER_ARGS="JFK American LAX"
#printf -v FILTER_URL "$FILTER_URL_FMT" $FILTER_ARGS #smoke test
FILTERS=(
    "American JFK LAX"
    "United SFO ORD"
)

CITY_ENDPOINTS=(
    "new%20york"
    "london"
    "tokyo"
    "sydney"
    "chicago"
    "los%20angeles"
    "miami"
    "unknown"
)

declare -A SIMPLE_ENDPOINTS=(
    ["root"]="$INDEX_URL"
    ["flights"]=$FLIGHTS_URL
    ["health"]=$HEALTH_URL
)


remove_filter(){
    local url=$1
    local base="${url%%\?*}"
    local query="${url#*\?}"
    #echo "baseurl=$base query=$query"
    IFS='&' read -r -a filters <<< "$query"
    unset 'filters[${#filters[@]}-1]'
    new_query=$(printf "%s&" "${filters[@]}")
    new_query="${new_query%&}"
    echo "${base}?${new_query}"

}

test_status_code(){
    local curl_exit_status=$1
    local http_code=$2
    if [[ $curl_exit_status -ne 0 ]]; then
       echo "curl_command_failed: http_code=$http_code"
       return 1
    fi
    if [[ $http_code -ne 200 ]]; then
       echo  "Redirect of Failed, http_code=$http_code"
       return 1
    fi
    echo "http_code = $http_code, exit_code= $curl_exit_status"
    echo ""
    return 0
}

test_analytics_delays(){
    local function_exit=0
    tmpfile=$(mktemp)
    echo "curl -s -o "$tmpfile" -w \"%{http_code}\" \"${DELAYS_URL}\""
    http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" "${DELAYS_URL}")
    curl_status=$?
    cat $tmpfile
    rm "$tempfile"
    test_status_code $curl_status $http_code
    function_exit=$?
    return $function_exit
}

test_analytics_endpoints(){
    local function_exit=0
    test_analytics_delays
    function_exit=$?
    return $function_exit
}

test_base_endpoints(){
    echo "################################"
    echo "Testing Enpoints"
    echo "##############################"
    local function_exit=0
    for key in "${!SIMPLE_ENDPOINTS[@]}"; do
        tmpfile=$(mktemp)
        echo "curl -s -o "$tmpfile" -w \"%{http_code}\" \"${SIMPLE_ENDPOINTS[$key]}\""
        http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" "${SIMPLE_ENDPOINTS[$key]}")
        curl_status=$?
        cat $tmpfile
        rm "$tempfile"
        test_status_code $curl_status $http_code
        function_exit=$?
    done
    return $function_exit
}

test_weather(){
    local function_exit=0
    for city in "${CITY_ENDPOINTS[@]}"; do
        tmpfile=$(mktemp)
        printf -v weather_url "$CITY_WEATHER_FMT" $city
        echo "curl -s -o "$tmpfile" -w \"%{http_code}\" \"$weather_url\""
        http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" "$weather_url")
        curl_status=$?
        cat $tmpfile
        rm "$tempfile"
        test_status_code $curl_status $http_code
        function_exit=$?
    done
    return $function_exit
}

test_filter(){
    local query_url=$1
    local base="${query_url%%\?*}"
    local query="${query_url#*\?}"
    IFS='&' read -r -a filters <<< "$query"
    local count=${#filters[@]}
    local function_exit=0
    for filter in ${filters[@]}; do

        echo "-----------------------------------"
        echo "Querying with ${filter} Filter"
        echo "----------------------------------"
        echo "curl ${base}?${filter}"
        #http_code=$(curl -s -o /dev/null -w "%{http_code}" "${base}?${filter}")
        tmpfile=$(mktemp)
        http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" "${base}?${filter}")
        curl_status=$?
        cat $tmpfile
        rm "$tempfile"
        echo "exit status: $curl_status, http_code=$http_code"
        echo $body
        test_status_code $curl_status $http_code
        function_exit=$?
        echo ""
    done

    testurl="${base}?${query}"
    for ((i=0; i<${#filters[@]}; i++)); do
        curr_count=$((count - i))
        echo "------------------------------------"
        echo "Querying with $curr_count filter/filters"
        echo "-------------------------------------"
        echo "curl $testurl"
        http_code=$(curl -s -o /dev/null -w "%{http_code}" $testurl)
        testurl=$(remove_filter $testurl)
        curl_status=$?
        echo "exit status: $curl_status, http_code=$http_code"
        test_status_code $curl_status $http_code
        function_exit=$?
        echo ""
    done

    return $function_exit

}

testing_filters(){
    echo "#######################################"
    echo "Testing Query Filters"
    echo "########################################"
    for filter in "${FILTERS[@]}"; do
        printf -v filter_url "$FILTER_URL_FMT" $filter;
        test_filter $filter_url
    done
    return 0
}

FUNCTION_LIST=(
    test_filter
    test_base_endpoints
    test_weather
    test_analytics_endpoints
)

if [[ $1 == "filtering" ]]; then
    test_filters
elif [[ $1 == "base" ]]; then
    test_base_endpoints
elif [[ $1 == "weather" ]]; then
    test_weather
elif [[ $1 == "analytics" ]]; then
    test_analytics_endpoints
else
    for f in "${FUNCTION_LIST[@]}"; do
        "$f"
    done
fi
