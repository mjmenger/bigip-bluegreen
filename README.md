# bigip-bluegreen-poc
This work was derived from http://github.com/f5devcentral/as3-bluegreen
## Initialize environment variables
- create the sample ```.env.example``` file
```
make sample_dotenv
```
- rename ```.env.example``` to ```.env```
- update the ```.env``` file with values appropriate for your environment
```
bigip1=FQDNorIPaddressOfYourBIGIP
user=admin
password=password4adminaccountonBIGIP
ipprefix=10.210. <-- first two octets of virtual servers ip address
ipfourth=9..11 <-- range of values for the fourth octet of the virtual server ip address
ipthird="101 102 103" <-- range of values for the third octet of the virtual servers ip address
bufferuser=admin <-- the user name for the Jenkins request buffer
bufferpassword=password <-- the password for the Jenkins request buffer
bufferhost=dockerhost <-- the host of the docker containers
bufferport=8080 <-- the port for the Jenkins request buffer
locust_min_wait=30 <-- the minimum time to wait between steps in the locust test in seconds
locust_max_wait=60 <-- the maximum time to wait between steps in the locust test in seconds
bluepool=/Common/Shared/blue_pool <-- the name of the pool of "blue" application servers
greenpool=/Common/Shared/green_pool <-- the name of the pool of "green" application servers
```
## Start the buffer and load test harness
- run the comprehensive make command
```
make enchilada
```
## Run a test
in the URLs below change **dockerhostaddress** to the FQDN or ip address of the host where the Locust and Jenkins containers are running.
- log into Locust at http://dockerhostaddress:8089
- log into the Jenkins buffer instance at http://dockerhostaddress:8080
- TBD the remaining steps to run a load test
