# coded-infra

Настоящий репозиторий содержит пример описания простой отказоустойчивой инфраструктуры сайта, которая может быть развёрнута в AWS-подобном облаке с помощью средств автоматизации Terraform и Ansible. Базовая инфраструктура состоит из джампхоста/DNS-сервера (BIND9), двух балансировщиков нагрузки (HAProxy) и двух бекенд-серверов (NGINX). В дальнейшем набор сервисов может меняться, см. TODO.

Данная инфраструктура используется мной для моего [блога](http://soup.msk.ru).

## Usage

Если вы хотите использовать данный код для развертывания собственной виртуальной инфраструктуры (что можно делать исключительно на свой страх и риск), то перед использованием вам необходимо установить Terraform и Ansible.

### Tools' installation

Способы установки Terraform для разных ОС описаны [на официальном сайте](https://developer.hashicorp.com/terraform/downloads).

Я использовал локальную установку с распаковкой исполняемого файла в каталог `/usr/local/bin/terraform`. Подтвердите установку командой:

```
$ terraform version
Terraform v1.1.7
on linux_amd64
+ provider hc-registry.website.cloud.croc.ru/c2devel/croccloud v4.14.0-CROC4

Your version of Terraform is out of date! The latest version
is 1.4.6. You can update by downloading from https://www.terraform.io/downloads.html
```

**Дисклеймер:** Так как часть ресурсов Hashicorp - разработчика Terraform - недоступна для пользователей из России, приходится использовать различные обходные пути для установки тех или иных провайдеров. Если вы работаете с Terraform не из России, то проблем у вас быть не должно. **Дисклеймер 2:** некоторые облачные провайдеры с AWS-совместимым API выпускают собственные версии Terraform-провайдеров для работы с их платформами, поэтому блок с установкой Terraform-провайдера `aws` я пропущу - обратитесь к документации используемой вами облачной платформы. Тем не менее, представленный здесь код должен быть по большей части совместим с любым Terraform-провайдером, реализующим AWS-like API. Я использую провайдер Croc Cloud. 

[Пример использования зеркала Яндекса для установки провайдеров.](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart#configure-provider)

[О настройке зеркал из официальной документации Terraform.](https://developer.hashicorp.com/terraform/cli/config/config-file#explicit-installation-method-configuration)

Используемые провайдеры описываются в файле `provider.tf`. 

Для установки Ansible требуется Python 3 и pip. Если по каким-то причинам они не установлены, установите их, затем установите Ansible с помощью pip:
```
$ python3 -m pip install --user ansible
...
$ ansible --version
ansible [core 2.14.5]
  config file = None
  configured module search path = ['/home/afirsov/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /home/afirsov/.local/lib/python3.9/site-packages/ansible
  ansible collection location = /home/afirsov/.ansible/collections:/usr/share/ansible/collections
  executable location = /home/afirsov/.local/bin/ansible
  python version = 3.9.7 (default, Aug 30 2021, 00:00:00) [GCC 10.3.1 20210422 (Red Hat 10.3.1-1)] (/usr/bin/python3)
  jinja version = 3.1.2
  libyaml = True
```

**Важно:** для корректной работы плейбука требуется Ansible версии не ниже 2.11. Не забудьте добавить каталог с исполняемым файлом в PATH. 

### First run

Склонируйте репозиторий. При первом запуске необходимо проинициализировать Terraform и требуемые провайдеры в каталоге `tf/`:

```
$ terraform init

Initializing the backend...

Initializing provider plugins...
...
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above.
...
Terraform has been successfully initialized!

You may now begin working with Terraform.
...
```

Здесь и далее команды для Terraform и Ansible выполняются в каталогах `tf/` и `ansible/` соответственно.

В каталоге `tf/` создайте и заполните файл `terraform.tfvars` значениями переменных, описанных в файле `variables.tf`. Для каждой переменной в файле `variables.tf` указано краткое описание и тип данных. Формат присвоения значений переменных в файле `terraform.tfvars` прост: `<Variable_name> = <Variable_value>`. Строковые значения оборачиваются в одинарные или двойные кавычки. Подробнее описано в [документации Terraform](https://developer.hashicorp.com/terraform/language/values/variables).

Например, следующей записи в `variables.tf`:

```HCL
variable "access_key" {
    type = string
    description = "AWS Access Key"
}
```

Соответствует следующая запись в `terraform.tfvars`:

```
access_key = "letBulochkin:blah@blahblah"
```

Значения AWS Access Key, AWS Secret Key, AWS Region, EC2 API URL и S3 API URL можно получить в консоли управления вашего облачного провайдера. Затем выполните планирование развёртывания:

```
$ terraform plan

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:
...
Plan: 23 to add, 0 to change, 0 to destroy.
...
```

Если вы уже разворачивали инфраструктуру с помощью Terraform, и, например, желаете продолжить работу с другой рабочей станции, то предварительно скачайте описание текущего состояния инфраструктуры `terraform.tfstate`, либо используйте [remote state](https://developer.hashicorp.com/terraform/language/state/remote). Проверьте корректность состояния; после этого вывод `terraform plan` изменится:

```
$ terraform state list
aws_eip.eip_public
aws_eip.eip_service
...

$ terraform state show aws_eip.eip_public
# aws_eip.eip_public:
resource "aws_eip" "eip_public" {
    ...
    public_ip         = "185.12.30.91"
    ...

$ terraform plan
aws_vpc_dhcp_options.dhcopts_stand_vpc: Refreshing state... [id=...]
aws_key_pair.infra_sshkey: Refreshing state... [id=soup_managed_infra_key]
aws_vpc.stand_vpc: Refreshing state... [id=...]
...
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
```

Если результат планирования вас устраивает, примените изменения (если вы используете подготовленный state, то изменения произведены не будут):

```
$ terraform apply
...
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

main_public_ip = "185.12.30.91"
service_access_ip = "..."
```

В файле `outputs.tf` описываются значения переменных, которые Terraform отобразит в конце отчета о выполнении развёртывания. В текущей версии в конце отчета будут выведены публичные EIP-адреса - адрес для доступа к стенду по SSH и адрес публичного эндпоинта, которые мы получим от облачного провайдера. Эти адреса в дальнейшем необходимо использовать в конфигурации Ansible.

В файле `ansible/inventory.yaml` обратите внимание на групповое описание хостов и общие переменные:

```yaml
soup_managed_infra:
  vars:
    ansible_ssh_common_args: >-  # set soup.service record to /etc/hosts
      -o ForwardAgent=yes -o ControlMaster=auto -o ControlPersist=2m
      -o ProxyCommand="ssh -W %h:%p ec2-user@soup.service"
```

В файл `/etc/hosts` пропишите имя, под которым будет резолвиться Service access EIP из отчета Terraform (либо подставьте в инвентори Ansible на место имени `soup.service`). Также добавьте в SSH Agent приватный ключ, вместе с которым вы развернули ВМ с помощью Terraform - для того, чтобы при прогоне сценария Ansible не пришлось многократно вводить пароль от ключа.

Запустите выполнение сценария Ansible командой:

```
$ ansible-playbook playbook.yaml -i inventory.yaml
...
PLAY RECAP *******************************************************************************************************
backend01                  : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
...
```

