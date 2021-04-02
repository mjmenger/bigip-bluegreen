set -o allexport; source .env; set +o allexport


i=0
COOKIEJAR="$(mktemp)"
CRUMB=$(curl -u "$bufferuser:$bufferpassword" --cookie-jar "$COOKIEJAR" "$bufferhost:$bufferport/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)")
echo $CRUMB
for thirdoctet in $ipthird
do 
    for fourthoctet in $(eval echo "{$ipfourth}") 
    do 
        virtualip="10.210.$thirdoctet.$fourthoctet" 
        tenant="Test${virtualip}"
        echo "${virtualip}:${i}"
        rulename="/${tenant}/App/${tenant}_bluegreen_irule"
        rulecontent="when CLIENT_ACCEPTED {\nset distribution [class match -value \\\"distribution\\\" equals bluegreen_datagroup]\nset blue_pool [class match -value \\\"blue_pool\\\" equals bluegreen_datagroup]\nset green_pool [class match -value \\\"green_pool\\\" equals bluegreen_datagroup]\nset rand [expr { rand() }]\nif { \$rand < \$distribution } {pool \$blue_pool} else {pool \$green_pool}}"

        echo "create iRule"
        curl -k --request POST \
        -u "$bufferuser:$bufferpassword" \
        --url http://$bufferhost:$bufferport/job/icrestbuffer/buildWithParameters \
        --header "$CRUMB" \
        --cookie "$COOKIEJAR" \
        --data 'ICREST_METHOD=POST' \
        --data-urlencode 'ICREST_URI=/mgmt/tm/ltm/rule' \
        --data "ICREST_JSON={\"name\":\"${rulename}\",\"apiAnonymous\":\"when CLIENT_ACCEPTED {\nset distribution [class match -value \\\"distribution\\\" equals bluegreen_datagroup]\nset blue_pool [class match -value \\\"blue_pool\\\" equals bluegreen_datagroup]\nset green_pool [class match -value \\\"green_pool\\\" equals bluegreen_datagroup]\nset rand [expr { rand() }]\nif { \$rand < \$distribution } {pool \$blue_pool} else {pool \$green_pool}}\"}"

        echo "create datagroup"
        curl -k --request POST \
        -u "$bufferuser:$bufferpassword" \
        --url http://$bufferhost:$bufferport/job/icrestbuffer/buildWithParameters \
        --header "$CRUMB" \
        --cookie "$COOKIEJAR" \
        --data 'ICREST_METHOD=POST' \
        --data-urlencode 'ICREST_URI=/mgmt/tm/ltm/data-group/internal/' \
        --data "ICREST_JSON={ \"name\": \"bluegreen_datagroup\",  \"partition\": \"${tenant}\", \"type\": \"string\", \"records\": [ { \"name\": \"blue_pool\", \"data\": \"/Common/Shared/blue\" }, { \"name\": \"distribution\", \"data\": \"0.5\" }, { \"name\": \"green_pool\", \"data\": \"/Common/Shared/green\" } ] }"

        sleep 1
    done
done