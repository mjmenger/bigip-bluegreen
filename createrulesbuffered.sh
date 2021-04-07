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
    
        echo "create iRule"
        curl -k \
        --url http://$bufferhost:$bufferport/job/icrestbuffer/buildWithParameters \
        -u "$bufferuser:$bufferpassword" \
        --header "$CRUMB" \
        --cookie "$COOKIEJAR" \
        -F ICREST_METHOD=POST \
        -F ICREST_URI=/mgmt/tm/ltm/rule \
        -F 'ICREST_JSON={"name":"'${rulename}'","apiAnonymous":"when CLIENT_ACCEPTED {\nset rand [expr {[TCP::client_port] % 100}]\nset distribution [class match -value \"distribution\" equals bluegreen_datagroup]\nif { $rand > $distribution }\n{pool '${greenpool}'}\n}"}'

        echo "create datagroup"
        curl -k --request POST \
        -u "$bufferuser:$bufferpassword" \
        --url http://$bufferhost:$bufferport/job/icrestbuffer/buildWithParameters \
        --header "$CRUMB" \
        --cookie "$COOKIEJAR" \
        -F ICREST_METHOD=POST \
        -F ICREST_URI=/mgmt/tm/ltm/data-group/internal/ \
        -F 'ICREST_JSON={ "name": "bluegreen_datagroup",  "partition": "'${tenant}'", "type": "string", "records": [ { "name": "blue_pool", "data": "'${bluepool}'" }, { "name": "distribution", "data": "50" }, { "name": "green_pool", "data": "'${greenpool}'" } ] }'

        sleep 1
    done
done