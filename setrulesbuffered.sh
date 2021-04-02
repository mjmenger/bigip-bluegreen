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

        echo "assign iRule to virtual server"
        curl -k --request POST \
        -u "$bufferuser:$bufferpassword" \
        --url http://$bufferhost:$bufferport/job/icrestbuffer/buildWithParameters \
        --header "$CRUMB" \
        --cookie "$COOKIEJAR" \
        --data 'ICREST_METHOD=PATCH' \
        --data-urlencode "ICREST_URI=/mgmt/tm/ltm/virtual/~${tenant}~App~service" \
        --data "ICREST_JSON={ \"rules\": [ \"${rulename}\" ] }"

        sleep 1
    done
done