set -o allexport; source .env; set +o allexport


i=0
for thirdoctet in $ipthird
do 
    for fourthoctet in $(eval echo "{$ipfourth}") 
    do 
        virtualip="10.210.$thirdoctet.$fourthoctet" 
        tenant="Test${virtualip}"
        echo "${virtualip}:${i}"
        rulename="/${tenant}/App/${tenant}_bluegreen_irule"
        rulecontent="when CLIENT_ACCEPTED {\nset distribution [class match -value \\\"distribution\\\" equals bluegreen_datagroup]\nset blue_pool [class match -value \\\"blue_pool\\\" equals bluegreen_datagroup]\nset green_pool [class match -value \\\"green_pool\\\" equals bluegreen_datagroup]\nset rand [expr { rand() }]\nif { \$rand < \$distribution } {pool \$blue_pool} else {pool \$green_pool}}"
        payload="{\"name\":\"${rulename}\",\"apiAnonymous\":\"${rulecontent}\"}"
        #echo $payload
        echo "create iRule"
        curl -k --request POST \
        -u "$user:$password" \
        --url https://$bigip1/mgmt/tm/ltm/rule \
        --header 'content-type: application/json' \
        --data "$payload"

        echo "create datagroup"
        curl -k --request POST \
        --url https://$bigip1/mgmt/tm/ltm/data-group/internal/ \
        -u ${user}:${password} \
        --header 'content-type: application/json' \
        --data "{ \"name\": \"bluegreen_datagroup\",  \"partition\": \"${tenant}\", \"type\": \"string\", \"records\": [ { \"name\": \"blue_pool\", \"data\": \"/Common/Shared/blue\" }, { \"name\": \"distribution\", \"data\": \"0.5\" }, { \"name\": \"green_pool\", \"data\": \"/Common/Shared/green\" } ] }" 

        echo "set iRule"
        curl -k --request PATCH \
        --url https://$bigip1/mgmt/tm/ltm/virtual/~${tenant}~App~service \
        -u ${user}:${password} \
        --header 'content-type: application/json' \
        --data "{\"rules\": [ \"/${tenant}/App/${tenant}_bluegreen_irule\" ]}" 


    done
done