output "ansible_inventory" {
  value = join("\n", concat(
    ["[pg_nodes]"],
    [for idx, inst in aws_instance.db_nodes :
      "db${idx + 1} ansible_host=${inst.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/shubham-key private_ip=${inst.private_ip}"
    ],
    [
      "db4 ansible_host=${aws_instance.db4.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/shubham-key private_ip=${aws_instance.db4.private_ip}"
    ]
  ))
}
