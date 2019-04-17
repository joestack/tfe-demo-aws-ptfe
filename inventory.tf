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

##
## here we copy the local file to the jumphost
## using a "null_resource" to be able to trigger a file provisioner
##
resource "null_resource" "provisioner" {
  depends_on = ["local_file.ansible_inventory"]

  triggers {
    always_run = "${timestamp()}"
  }

  provisioner "file" {
    source      = "${path.module}/ansible/inventory"
###    destination = "~/inventory"

    connection {
      type        = "ssh"
      host        = "${aws_instance.jumphost.public_ip}"
      user        = "${var.ssh_user}"
      private_key = "${var.id_rsa_aws}"
      insecure    = true
    }
  }
}

resource "null_resource" "cp_ansible" {
  depends_on = ["null_resource.provisioner"]

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

#resource "null_resource" "ansible_run" {
#  depends_on = ["null_resource.cp_ansible", "local_file.ansible_inventory", "aws_instance.web_nodes", "aws_route53_record.jumphost"]
#
#  triggers {
#    always_run = "${timestamp()}"
#  }
#
#  connection {
#    type        = "ssh"
#    host        = "${aws_instance.jumphost.public_ip}"
#    user        = "${var.ssh_user}"
#    private_key = "${var.id_rsa_aws}"
#    insecure    = true
#  }
#
#  provisioner "remote-exec" {
#    inline = [
#      "sleep 30 && ansible-playbook -i ~/inventory ~/ansible/playbook.yml ",
#    ]
#  }
#}
