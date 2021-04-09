set -o allexport; source .env; set +o allexport

i=0
COOKIEJAR="$(mktemp)"
CRUMB=$(curl -u "$bufferuser:$bufferpassword" --cookie-jar "$COOKIEJAR" "$bufferhost:$bufferport/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)")
echo $CRUMB
for thirdoctet in $ipthird
do 
    for fourthoctet in $(eval echo "{$ipfourth}") 
    do 
        virtualip="$ipprefix$thirdoctet.$fourthoctet" 
        tenant="Test${virtualip}"
        echo "${virtualip}:${i}"
        rulename="~${tenant}~App~${tenant}_bluegreen_irule"
        datagroupname="~${tenant}~App~bluegreen_datagroup"
    
        echo "delete iRule"
        curl -k \
        --url http://$bufferhost:$bufferport/job/icrestbuffer/buildWithParameters \
        -u "$bufferuser:$bufferpassword" \
        --header "$CRUMB" \
        --cookie "$COOKIEJAR" \
        -F ICREST_METHOD=DELETE \
        -F ICREST_URI=/mgmt/tm/ltm/rule/$rulename 

        echo "delete datagroup"
        curl -k \
        --url http://$bufferhost:$bufferport/job/icrestbuffer/buildWithParameters \
        -u "$bufferuser:$bufferpassword" \
        --header "$CRUMB" \
        --cookie "$COOKIEJAR" \
        -F ICREST_METHOD=DELETE \
        -F ICREST_URI=/mgmt/tm/ltm/data-group/internal/$datagroupname

        sleep 1
    done
done