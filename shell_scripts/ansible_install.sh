#!/bin/bash
yum -y install python39 > /var/log/terraform_init_run.log
python3 -m pip install ansible >> /var/log/terraform_init_run.log
ansible --version >> /var/log/terraform_init_run.log
