## dynamically generate a `inventory` file for Ansible Configuration Automation 

data "template_file" "ansible_masternode" {
    count      = "${var.tfe_node_count}"
    template   = "${file("${path.module}/templates/ansible_hosts.tpl")}"
    depends_on = ["aws_instance.tfe_node"]

      vars {
        node_name    = "${lookup(aws_instance.tfe_node.*.tags[count.index], "Name")}"
        ansible_user = "${var.ssh_user}"
        extra        = "ansible_host=${element(aws_instance.tfe_node.*.public_ip,count.index)}"
      }

}


data "template_file" "ansible_groups" {
    template = "${file("${path.module}/templates/ansible_groups.tpl")}"

      vars {
        ssh_user_name = "${var.ssh_user}"
        masternode_def  = "${join("",data.template_file.ansible_masternode.*.rendered)}"
      }

}

resource "local_file" "ansible_inventory" {
    depends_on = ["data.template_file.ansible_groups"]

    content = "${data.template_file.ansible_groups.rendered}"
    filename = "${path.module}/ansible/inventory"

}

data "template_file" "ansible_role_ptfe_vars" {
  template = "${file("${path.module}/templates/ansible_role_ptfe_vars.tpl")}"

    vars {
      tfe_password        = "${var.tfe_password}"
      tfe_encryption_key  = "${var.tfe_encryption_key}"
    }
}

resource "local_file" "ansible_role_ptfe_vars" {    
    depends_on = ["data.template_file.ansible_groups"]

    content = "${data.template_file.ansible_role_ptfe_vars.rendered}"
    filename = "${path.module}/ansible/roles/ptfe/vars/main.yml"
}

resource "null_resource" "cp_vault_password" {
    depends_on = ["local_file.ansible_role_ptfe_vars"]

    triggers {
    always_run = "${timestamp()}"
    }
    
    connection {
      type        = "ssh"
      host        = "${aws_instance.jumphost.public_ip}"
      user        = "${var.ssh_user}"
      private_key = "${var.id_rsa_aws}"
      insecure    = true
    }
    provisioner "remote-exec" {
    inline = [
      "echo ${var.tfe_rli_vault_password} > ~/.vault-password.txt ",
    ]
  }
  
}

#encrypt licence and cert here before we run the playbook
resource "null_resource" "encrypt_license" {
  depends_on = ["null_resource.cp_vault_password"]

  triggers {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "apt-get install ansible -y && ansible-vault decrypt ~/ansible/role/ptfe/files/license.rli --vault-password-file ~/.vault-password.txt ; [ -e ~/ansible/roles/copy_cert/files/cert.tgz ] && ansible-vault decrypt ~/ansible/roles/copy_cert/files/cert.tgz --vault-password-file ~/.vault-password.txt"
    
  }
#    connection {
#      type        = "ssh"
#      host        = "${aws_instance.jumphost.public_ip}"
#      user        = "${var.ssh_user}"
#      private_key = "${var.id_rsa_aws}"
#      insecure    = true
#    }
}

##
## here we copy the local file to the jumphost
## using a "null_resource" to be able to trigger a file provisioner
##

resource "null_resource" "cp_ansible" {
  depends_on = ["local_file.ansible_inventory"]

  triggers {
    always_run = "${timestamp()}"
  }

  provisioner "file" {
    source      = "${path.module}/ansible"
    destination = "~/"

    connection {
      type        = "ssh"
      host        = "${aws_instance.jumphost.public_ip}"
      user        = "${var.ssh_user}"
      private_key = "${var.id_rsa_aws}"
      insecure    = true
    }
  }
}


resource "null_resource" "ansible_run" {
  depends_on = ["null_resource.cp_ansible", "local_file.ansible_inventory", "aws_instance.tfe_node", "aws_route53_record.jumphost"]

  triggers {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    host        = "${aws_instance.jumphost.public_ip}"
    user        = "${var.ssh_user}"
    private_key = "${var.id_rsa_aws}"
    insecure    = true
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 30 && ansible-playbook -i ~/ansible/inventory ~/ansible/playbook.yml ",
    ]
  }
}
