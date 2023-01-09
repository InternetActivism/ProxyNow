#!/bin/sh
service docker start
docker-compose -f /home/ec2-user/ProxyNow/whatsapp-proxy/proxy/ops/docker-compose.yml up -d
