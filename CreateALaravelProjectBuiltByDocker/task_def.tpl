[
    {
        "dnsSearchDomains": null,
        "logConfiguration": null,
        "entryPoint": null,
        "portMappings": [
            {
                "hostPort": 0,
                "protocol": "tcp",
                "containerPort": 80
            }
        ],
        "command": [],
        "linuxParameters": null,
        "cpu": 10,
        "environment": [
            {
                "name": "DB_CONNECTION",
                "value": "mysql"
            },
            {
                "name": "DB_HOST",
                "value": "db.${private_domain}"
            },
            {
                "name": "DB_PORT",
                "value": "3306"
            },
            {
                "name": "DB_DATABASE",
                "value": "todo"
            },
            {
                "name": "DB_USERNAME",
                "value": "root"
            },
            {
                "name": "DB_PASSWORD",
                "value": "password"
            },
            {
                "name": "IMAGE_S3_BUCKET",
                "value": "${s3_image_bucket}"
            },
            {
                "name": "IMAGE_DOMAIN",
                "value": "s3-us-west-2.amazonaws.com/${s3_image_bucket}"
            }
        ],
        "ulimits": null,
        "dnsServers": null,
        "mountPoints": [],
        "workingDirectory": null,
        "dockerSecurityOptions": null,
        "memory": 128,
        "memoryReservation": null,
        "volumesFrom": [],
        "image": "${docker_image}",
        "disableNetworking": null,
        "essential": true,
        "links": null,
        "hostname": null,
        "extraHosts": null,
        "user": null,
        "readonlyRootFilesystem": null,
        "dockerLabels": null,
        "privileged": null,
        "name": "demo-laravel-todo"
    }
]
