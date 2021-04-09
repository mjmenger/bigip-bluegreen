from locust import HttpUser, task, between, constant, SequentialTaskSet 
import json
import jinja2
import os
import logging
import time
from viparray import *

TEMPLATE_FILE = "bluegreenstatic.json.j2"
logging.basicConfig(level=logging.WARNING)
class BlueGreenTasks(SequentialTaskSet):
    as3buffer_path = "/job/as3buffer/buildWithParameters"
    icrestbuffer_path = "/job/icrestbuffer/buildWithParameters"
    vip_address = "NOT_FOUND"
    tenant_name = "NOT_FOUND"
    app_name = "NOT_FOUND"
    bigip_mgmt_uri = os.getenv('BIGIP_MGMT_URI')
    bigip_user = os.getenv('BIGIP_USER')
    bigip_pass = os.getenv('BIGIP_PASS')
    task_label = ""
    jenkins_crumb = []
    templateLoader = jinja2.FileSystemLoader(searchpath="/mnt/locust/")
    templateEnv = jinja2.Environment(loader=templateLoader)
    template = templateEnv.get_template(TEMPLATE_FILE)
    dgdist_template = templateEnv.get_template('dg-distribution.json.j2')
    dgpool_template = templateEnv.get_template('dg-pool.json.j2')
    vsrules_template = templateEnv.get_template('vs-rules.json.j2')
    bgirule_template = templateEnv.get_template('ruledef.json.j2') 
    dgdistdef_template = templateEnv.get_template('dgdef.json.j2') 

    def on_start(self):
        if len(VIP_INFO) > 0:
            self.vip_address, self.tenant_name, self.app_name = VIP_INFO.pop()
            logging.info("retrieving crumb")
            r = self.client.get("/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)", name="0_getcrumb", verify=False, auth=(self.bigip_user,self.bigip_pass))
            logging.info(r.content.split(b':'))
            self.jenkins_crumb = r.content.split(b':')
            logging.info('creating irule')
            icrest_payload = self.bgirule_template.render(tenant = self.tenant_name, application = self.app_name, greenpool = "/Common/Shared/green")
            r = self.client.post(self.icrestbuffer_path, headers = {self.jenkins_crumb[0] : self.jenkins_crumb[1]},  name="0_create_irule_" + self.task_label, verify=False, auth=(self.bigip_user,self.bigip_pass), data={ "ICREST_METHOD": "POST", "ICREST_URI": "/mgmt/tm/ltm/rule/", "ICREST_JSON": icrest_payload })
            logging.info('creating datagroup')
            icrest_payload = self.dgdistdef_template.render(tenant = self.tenant_name, application = self.app_name, distribution = "20", bluePool = "/Common/Shared/blue", greenPool = "/Common/Shared/green")
            r = self.client.post(self.icrestbuffer_path, headers = {self.jenkins_crumb[0] : self.jenkins_crumb[1]},  name="0_create_datagroup_" + self.task_label, verify=False, auth=(self.bigip_user,self.bigip_pass), data={ "ICREST_METHOD": "POST", "ICREST_URI": "/mgmt/tm/ltm/data-group/internal/", "ICREST_JSON": icrest_payload })
            time.sleep(int(os.getenv('BLUEGREEN_STEP_WAIT_MIN')))

    @task
    def set_blue100_green000_on_blue(self):
        icrest_payload = self.vsrules_template.render(rules="\"/"+self.tenant_name+"/"+self.app_name+"/"+self.tenant_name+"_bluegreen_irule\"")
        logging.info(icrest_payload)
        r = self.client.post(self.icrestbuffer_path, headers = {self.jenkins_crumb[0] : self.jenkins_crumb[1]},  name="2_rest_enable_irule_" + self.task_label, verify=False, auth=(self.bigip_user,self.bigip_pass), data={ "ICREST_URI": "/mgmt/tm/ltm/virtual/~"+self.tenant_name+"~"+self.app_name+"~service", "ICREST_JSON": icrest_payload })

    @task
    def set_blue080_green020_on_blue(self):
        icrest_payload = self.dgdist_template.render(partition = self.tenant_name, application = self.app_name, distribution = "80", bluePool = "/Common/Shared/blue", greenPool = "/Common/Shared/green")
        logging.info(icrest_payload)
        r = self.client.post(self.icrestbuffer_path, headers = {self.jenkins_crumb[0] : self.jenkins_crumb[1]},  name="3_rest_blue80_distribution_" + self.task_label, verify=False, auth=(self.bigip_user,self.bigip_pass), data={ "ICREST_URI": "/mgmt/tm/ltm/data-group/internal/~"+self.tenant_name+"~"+self.app_name+"~bluegreen_datagroup", "ICREST_JSON": icrest_payload })

    @task
    def set_blue020_green080_on_blue(self):
        icrest_payload = self.dgdist_template.render(partition = self.tenant_name, application = self.app_name, distribution = "20", bluePool = "/Common/Shared/blue", greenPool = "/Common/Shared/green")
        logging.info(icrest_payload)
        r = self.client.post(self.icrestbuffer_path, headers = {self.jenkins_crumb[0] : self.jenkins_crumb[1]},  name="4_rest_blue20_distribution_" + self.task_label, verify=False, auth=(self.bigip_user,self.bigip_pass), data={ "ICREST_URI": "/mgmt/tm/ltm/data-group/internal/~"+self.tenant_name+"~"+self.app_name+"~bluegreen_datagroup", "ICREST_JSON": icrest_payload })

    @task
    def set_blue020_green080_on_green(self):
        icrest_payload = self.dgpool_template.render(partition = self.tenant_name, application = self.app_name, distribution = "20", bluePool = "/Common/Shared/blue", greenPool = "/Common/Shared/green", defaultPool = "/Common/Shared/green")
        logging.info(icrest_payload)
        r = self.client.post(self.icrestbuffer_path, headers = {self.jenkins_crumb[0] : self.jenkins_crumb[1]},  name="5_rest_default_green_" + self.task_label, verify=False, auth=(self.bigip_user,self.bigip_pass), data={ "ICREST_URI": "/mgmt/tm/ltm/virtual/~"+self.tenant_name+"~"+self.app_name+"~service", "ICREST_JSON": icrest_payload })

    @task
    def set_blue020_green080_off_green(self):
        icrest_payload = self.vsrules_template.render(rules='')
        logging.info(icrest_payload)
        r = self.client.post(self.icrestbuffer_path, headers = {self.jenkins_crumb[0] : self.jenkins_crumb[1]},  name="6_rest_disable_irule_" + self.task_label, verify=False, auth=(self.bigip_user,self.bigip_pass), data={ "ICREST_URI": "/mgmt/tm/ltm/virtual/~"+self.tenant_name+"~"+self.app_name+"~service", "ICREST_JSON": icrest_payload })



class BlueGreenUser(HttpUser):
    wait_time = between(int(os.getenv('BLUEGREEN_STEP_WAIT_MIN')), int(os.getenv('BLUEGREEN_STEP_WAIT')))
    tasks = [BlueGreenTasks]