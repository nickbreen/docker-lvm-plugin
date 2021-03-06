#!/usr/bin/env bash

set -e -o pipefail

setup() {
    sudo dd if=/dev/zero of=/loop0.img bs=$1 count=1M
    sudo losetup /dev/loop0 /loop0.img
    sudo sfdisk /dev/loop0 <<< ",,8e,,"
    sudo pvcreate /dev/loop0 -f
    sudo vgcreate test-vg /dev/loop0
}

teardown() {
    sudo docker plugin rm nickbreen/docker-lvm-plugin --force
    sudo lvremove test-vg -f || true
    sudo vgremove test-vg -f || true
    sudo losetup --detach /dev/loop0 || true
    sudo rm -f /loop0.img
}

expected_vgs() {
    sudo vgs | grep test-vg
}

expected_lvs() {
    sudo lvs --options lv_name | env GREP_COLORS="ms=01;32" grep --color $1
}

expected_manifest() {
    d=$(sudo find /var/lib/docker/plugins -type d -name docker-lvm-plugin | tee /dev/stderr)
    sudo find $d -name \*.json | sudo xargs jq -e ".[\"$1\"]"
}

plugin() {
    # make and enable the plugin
    make create
    # configure the plugin
    sudo docker plugin set nickbreen/docker-lvm-plugin VOLUME_GROUP=test-vg
    sudo docker plugin enable nickbreen/docker-lvm-plugin
    # list enabled plugins
    sudo docker plugin ls --filter enabled=true | grep nickbreen/docker-lvm-plugin
}


trap "teardown" EXIT

setup 96
plugin
