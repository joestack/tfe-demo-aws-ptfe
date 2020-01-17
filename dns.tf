data "aws_route53_zone" "selected" {
  name         = "${var.dns_domain}."
  private_zone = false
}



resource "aws_route53_record" "jumphost" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
#  name    = "${lookup(aws_instance.jumphost.*.tags[0], "Name")}"
  name    = "ptfejh"

  #name    = "jumphost"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.jumphost.public_ip}"]
}


resource "aws_route53_record" "APP" {
  count   = "${var.tfe_node_count}"
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${lookup(aws_instance.tfe_node.*.tags[count.index], "Name")}"
#  name    = "APP.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
#  records = ["${aws_instance.tfe_node.0.public_ip}"]
  records = ["${element(aws_instance.tfe_node.*.public_ip, count.index )}"]
}

