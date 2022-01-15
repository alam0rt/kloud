/*
Copyright 2019 The KubeOne Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "kubeone" {
  name       = "kubeone-${var.cluster_name}"
  public_key = file(var.ssh_public_key_file)
}

resource "hcloud_network" "net" {
  name     = var.cluster_name
  ip_range = var.ip_range
}

data "http" "ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

data "hcloud_servers" "nodes" {
  with_selector = "role=node"
}


locals {
  ifconfig_co_json = jsondecode(data.http.ip.body)
  node_public_ipv4 = [for node in data.hcloud_servers.nodes.servers : join("/", [node.ipv4_address, "32"])]
  controlplane_public_ipv4 = [for i in range(var.control_plane_replicas) : join("/", [hcloud_server.control_plane[i].ipv4_address, "32"])]
} 

resource "hcloud_firewall" "cluster" {
  name = "${var.cluster_name}-fw"

  labels = {
    "kubeone_cluster_name" = var.cluster_name
  }

  apply_to {
    label_selector = "kubeone_cluster_name=${var.cluster_name}"
  }

  rule {
    description = "allow ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips = [
      "0.0.0.0/0",
    ]
  }

  rule {
    description = "allow all TCP inside cluster"
    direction   = "in"
    protocol    = "tcp"
    port        = "any"
    source_ips = concat(
      [],
      [var.ip_range],
      local.controlplane_public_ipv4,
      local.node_public_ipv4,
    )
  }

  rule {
    description = "allow all UDP inside cluster"
    direction   = "in"
    protocol    = "udp"
    port        = "any"
    source_ips  = concat(
      [],
      [var.ip_range],
      local.controlplane_public_ipv4,
      local.node_public_ipv4,
    )
  }

  rule {
    description = "allow SSH from self"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips = [
      "${local.ifconfig_co_json.ip}/32",
    ]
  }

  rule {
    description = "allow NodePorts from any"
    direction   = "in"
    protocol    = "tcp"
    port        = "30000-32767"
    source_ips = [
      "0.0.0.0/0",
    ]
  }
}

resource "hcloud_network_subnet" "kubeone" {
  network_id   = hcloud_network.net.id
  type         = "server"
  network_zone = var.network_zone
  ip_range     = var.ip_range
}

resource "hcloud_server_network" "control_plane" {
  count     = 3
  server_id = element(hcloud_server.control_plane.*.id, count.index)
  subnet_id = hcloud_network_subnet.kubeone.id
}

resource "hcloud_server" "control_plane" {
  count       = var.control_plane_replicas
  name        = "${var.cluster_name}-control-plane-${count.index + 1}"
  server_type = var.control_plane_type
  image       = var.image
  location    = var.datacenter

  ssh_keys = [
    hcloud_ssh_key.kubeone.id,
  ]

  labels = {
    "kubeone_cluster_name" = var.cluster_name
    "role"                 = "api"
  }
}

resource "hcloud_load_balancer_network" "load_balancer" {
  count =  (var.enable_lb != "" ? 1 : 0) 
  load_balancer_id = hcloud_load_balancer.load_balancer[0].id
  subnet_id        = hcloud_network_subnet.kubeone.id
}

resource "hcloud_load_balancer" "load_balancer" {
  count =  (var.enable_lb != "" ? 1 : 0) 
  name               = "${var.cluster_name}-lb"
  load_balancer_type = var.lb_type
  location           = var.datacenter

  labels = {
    "kubeone_cluster_name" = var.cluster_name
    "role"                 = "lb"
  }
}

resource "hcloud_load_balancer_target" "load_balancer_target" {
  count =  (var.enable_lb != "" ? 3 : 0) 
  type             = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer[0].id
  server_id        = element(hcloud_server.control_plane.*.id, count.index)
  use_private_ip   = true
  depends_on = [
    hcloud_server_network.control_plane,
    hcloud_load_balancer_network.load_balancer
  ]
}

resource "hcloud_load_balancer_service" "load_balancer_service" {
  count =  (var.enable_lb != "" ? 1 : 0) 
  load_balancer_id = hcloud_load_balancer.load_balancer[0].id
  protocol         = "tcp"
  listen_port      = 8443
  destination_port = 6443
}
