SHELL := /bin/bash
# load the .env file
ifneq (,$(wildcard ./.env))
	include .env
	export
endif

enchilada: enable_bursthandling setup_bluegreen_pools enable_restjavad_additional_memory prime_atcbuffer_jobs initialize_vips start_locust

clean: remove_locust remove_atcbuffer remove_tenants

enable_bursthandling:
	# Enable Burst Handling 
	curl -k --request POST \
	-u "${user}:${password}" \
	--url https://${bigip1}/mgmt/shared/appsvcs/settings \
	--header 'content-type: application/json' \
	--data '{"burstHandlingEnabled": true}'

enable_additional_memory:
	# Enable additional memory
	curl -k --request PATCH \
	-u "${user}:${password}" \
	--url https://${bigip1}/mgmt/tm/sys/db/provision.extramb \
	--header 'content-type: application/json' \
	--data '{"value": "1000"}'

enable_restjavad_additional_memory: enable_additional_memory
	# Enable use of the additional memory by restjavad
	curl -k --request PATCH \
	-u "${user}:${password}" \
	--url https://${bigip1}/mgmt/tm/sys/db/restjavad.useextramb \
	--header 'content-type: application/json' \
	--data '{"value": true}'
	# Restart restjavad
	# Note: the following will return an error because restjavad is part of the
	# implementation of the iControlREST API
	curl -k --request POST \
	-u "${user}:${password}" \
	--url https://${bigip1}/mgmt/tm/sys/service \
	--header 'content-type: application/json' \
	--data '{"command": "restart","name": "restjavad"}'
	# wait a moment for restjavad to restart
	sleep 15

setup_bluegreen_pools:
	curl -k --request POST \
	-u "${user}:${password}" \
	--url https://${bigip1}/mgmt/shared/appsvcs/declare \
	--header 'content-type: application/json' \
	--data '{"class": "AS3","action": "deploy","persist": true,"declaration": {"class": "ADC","schemaVersion": "3.25.0","id": "id_bluegreen_setup_1234","label": "","remark": "Setup Target Blue and Green Pools","Common": {"class": "Tenant","Shared": {"class": "Application","template": "shared","blue": {"class": "Pool","monitors": ["tcp"],"members": [{"servicePort": 80,"serverAddresses": ["10.211.100.1","10.211.100.2","10.211.100.3","10.211.100.4","10.211.100.5"]}]},"green": {"class": "Pool","monitors": ["tcp"],"members": [{"servicePort": 80,"serverAddresses": ["10.211.100.6","10.211.100.7","10.211.100.8","10.211.100.9","10.211.100.10"]}]}}}}}'

start_atcbuffer: remove_atcbuffer
	docker run -d --env JENKINS_ADMIN_ID="admin" \
	--env JENKINS_ADMIN_PASSWORD="password" \
	--env BIGIP_HOST="${bigip1}" \
	--env BIGIP_MGMT_URI="should/not/be/required" \
	--env BIGIP_ADMIN_ID="${user}" \
	--env BIGIP_ADMIN_PASSWORD="${password}" \
	--name "${bigip1}-atcbuffer" \
	-p 8080:8080 \
	mmenger/as3buffer:0.4.0
	sleep 30

# declarative Jenkins jobs do not have parameters
# when first loaded. Running a build on each job
# will error out and enable the parameters for 
# subsequent builds
# wait 15 seconds for priming builds to complete/fail
# then delete the priming builds
prime_atcbuffer_jobs: start_atcbuffer
	@echo retrieve jenkins crumb for crss
	$(eval COOKIEJAR="$(shell mktemp)")
	$(eval CRUMB=$(shell curl -u "admin:password" --cookie-jar $(COOKIEJAR) "http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)"))
	@echo prime the jobs in Jenkins
	curl -v -X POST  -u "admin:password" --cookie $(COOKIEJAR) -H "$(CRUMB)" http://localhost:8080/job/as3buffer/build 
	curl -v -X POST  -u "admin:password" --cookie $(COOKIEJAR) -H "$(CRUMB)" http://localhost:8080/job/icrestbuffer/build 
	sleep 15
	curl -v -X POST  -u "admin:password" --cookie $(COOKIEJAR) -H "$(CRUMB)" http://localhost:8080/job/icrestbuffer/1/doDelete
	curl -v -X POST  -u "admin:password" --cookie $(COOKIEJAR) -H "$(CRUMB)" http://localhost:8080/job/as3buffer/1/doDelete

remove_atcbuffer:
	docker rm -f -v ${bigip1}-atcbuffer

start_locust: remove_locust 
	docker run -d --env BIGIP_USER=admin \
	--env BIGIP_PASS=password \
	--env BIGIP_MGMT_URI="should/not/be/required" \
	--env BLUEGREEN_STEP_WAIT_MIN=${locust_min_wait} \
	--env BLUEGREEN_STEP_WAIT=${locust_max_wait} \
	-p 8089:8089 \
	-v $$PWD:/mnt/locust \
	--name "${bigip1}-locust" \
	locustio/locust \
	-f /mnt/locust/jenkins-icrest-bluegreen-test.py \
	--host 'http://localhost:8080'

start_locust_nod: remove_locust
	docker run --env BIGIP_USER=admin \
	--env BIGIP_PASS=password \
	--env BIGIP_MGMT_URI="should/not/be/required" \
	--env BLUEGREEN_STEP_WAIT_MIN=${locust_min_wait} \
	--env BLUEGREEN_STEP_WAIT=${locust_max_wait} \
	-p 8089:8089 \
	-v $$PWD:/mnt/locust \
	--name "${bigip1}-locust" \
	locustio/locust \
	-f /mnt/locust/jenkins-icrest-bluegreen-test.py \
	--host 'http://localhost:8080'

remove_locust:
	docker rm -f -v ${bigip1}-locust

initialize_vips: 
	# viparray.py will be used as input to the test harness so 
	# it uses the proper Tenant name to virtual address mapping
	echo "VIP_INFO = []" > viparray.py; \
	i=0; \
	for thirdoctet in $(subst ",,$(ipthird)); do \
		for fourthoctet in {${ipfourth}}; do \
			virtualip="${ipprefix}$$thirdoctet.$$fourthoctet"; \
			echo "$$virtualip:$$i"; \
			response=$$(curl -k --request POST \
			--url https://${bigip1}/mgmt/shared/appsvcs/declare \
			-u ${user}:${password} \
			--header 'content-type: application/json' \
			--data "{\"class\": \"AS3\",\"action\": \"deploy\",\"persist\": true,\"declaration\": {\"class\": \"ADC\",\"schemaVersion\": \"3.25.0\",\"id\": \"id_$$virtualip\",\"label\": \"Test$$virtualip\",\"remark\": \"An HTTP service with percentage based traffic distribution\",\"Test$$virtualip\": {\"class\": \"Tenant\",\"App\": {\"class\": \"Application\",\"service\": {\"class\": \"Service_L4\",\"virtualAddresses\": [\"$$virtualip\"],\"virtualPort\":  80,\"persistenceMethods\": [],\"profileL4\": {\"bigip\":\"/Common/fastL4\"},\"snat\":\"auto\",\"pool\": {\"bigip\":\"/Common/Shared/blue\"}}}}}}" \
			--write-out '%{http_code}' --silent --output /dev/null); \
			echo " CURL RESPONSE: $$response"; \
			if [[ $$response -eq 200 ]]; then \
				echo 'appending to viparray.py'; \
				echo "VIP_INFO.append((\"$$virtualip\",\"Test$$virtualip\",\"App\"))" >> viparray.py; \
			fi; \
			i=$$((i+1)); \
			sleep 5; \
		done \
	done

set_all_irules:
	./setrulesbuffered.sh

create_all_irules:
	./createrulesbuffered.sh

unset_all_irules:
	./unsetrulesbuffered.sh

remove_tenants: 
	i=0; \
	for thirdoctet in $(subst ",,$(ipthird)); do \
		for fourthoctet in {${ipfourth}}; do \
			virtualip="${ipprefix}$$thirdoctet.$$fourthoctet"; \
			response=$$(curl -k --request DELETE \
			--url https://${bigip1}/mgmt/shared/appsvcs/declare/Test$$virtualip \
			-u ${user}:${password} \
			--header 'content-type: application/json' \
			--write-out '%{http_code}' --silent --output /dev/null); \
			echo $$response; \
			i=$$((i+1)); \
			sleep 2; \
		done \
	done

sample_dotenv:
	echo bigip1=bigipaddress > .env.example; \
	echo user=admin >> .env.example; \
	echo password=bigippassword >> .env.example; \
	echo ipprefix=10.210. >> .env.example; \
	echo ipfourth=9..11 >> .env.example; \
	echo ipthird="101 102 103" >> .env.example; \
	echo bufferuser=admin >> .env.example; \
	echo bufferpassword=password >> .env.example; \
	echo bufferhost=dockerhostaddress >> .env.example; \
	echo bufferport=8080 >> .env.example; \
	echo locust_min_wait=30 >> .env.example; \
	echo locust_max_wait=60 >> .env.example; \
	echo bluepool=/Common/Shared/blue_pool >> .env.example; \
	echo greenpool=/Common/Shared/green_pool >> .env.example; \