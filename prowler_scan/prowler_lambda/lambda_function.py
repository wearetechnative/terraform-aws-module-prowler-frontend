import boto3
import os
import json
import time

ecs_client = boto3.client('ecs')
ec2_client = boto3.client('ec2')
elbv2_client = boto3.client('elbv2')

ecs_cluster = os.environ["CLUSTER"]
ecs_subnet = os.environ["SUBNET"]
dashboard_template = os.environ['DASHBOARD_LAUNCH_TEMPLATE']
dashboard_uptime = os.environ["DASHBOARD_UPTIME"]
dashboard_tg_arn = os.environ['DASHBOARD_TG_ARN']
dashboard_alb_dns = os.environ['DASHBOARD_ALB_DNS']


def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", event.get("httpMethod", "GET"))
    path = event.get("rawPath") or event.get("path", "")
    print(f"Incoming request: {method} {path}")

    if method == "OPTIONS":
        return respond(200, {"message": "CORS preflight successful"})

    try:
        if method == "POST" and path.endswith("/start-task"):
            return start_task()
        elif method == "GET" and path.endswith("/check-task-status"):
            task_arn = event.get("queryStringParameters", {}).get("taskArn")
            return check_task_status(task_arn)
        elif method == "POST" and path.endswith("/launch-dashboard"):
            return launch_dashboard_handler()
        elif method == "GET" and path.endswith("/check-dashboard-status"):
            return check_dashboard_status_handler(event)
        else:
            return respond(404, {"error": "Unknown route"})
    except Exception as e:
        print("Unhandled exception:", str(e))
        return respond(500, {"error": str(e)})


def respond(status_code, body_dict):
    return {
        "statusCode": status_code,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Content-Type": "application/json"
        },
        "body": json.dumps(body_dict)
    }


def start_task():
    try:
        task_defs = ecs_client.list_task_definitions()['taskDefinitionArns']
        active_tasks = ecs_client.list_tasks(cluster=ecs_cluster)['taskArns']
        if active_tasks:
            return respond(409, {"error": "Scan already in progress", "taskArns": active_tasks})

        started_tasks = []
        for td in task_defs:
            resp = ecs_client.run_task(
                cluster=ecs_cluster,
                launchType='FARGATE',
                taskDefinition=td,
                count=1,
                platformVersion='LATEST',
                networkConfiguration={
                    'awsvpcConfiguration': {
                        'subnets': [ecs_subnet],
                        'assignPublicIp': 'ENABLED'
                    }
                }
            )
            tasks = resp.get("tasks", [])
            started_tasks.extend([t['taskArn'] for t in tasks])

        return respond(200, {"taskArns": started_tasks, "message": f"{len(started_tasks)} ECS tasks started."})
    except Exception as e:
        print("Error starting ECS task:", str(e))
        return respond(500, {"error": str(e)})


def check_task_status(task_arns_string):
    if not task_arns_string:
        return respond(400, {"error": "Missing taskArns"})
    try:
        task_arns = json.loads(task_arns_string)
        if not isinstance(task_arns, list):
            return respond(400, {"error": "taskArns must be a list"})

        resp = ecs_client.describe_tasks(cluster=ecs_cluster, tasks=task_arns)
        tasks = resp.get('tasks', [])
        if not tasks:
            return respond(404, {"error": "Tasks not found"})

        statuses = {t['taskArn']: t.get('lastStatus', 'UNKNOWN') for t in tasks}
        all_stopped = all(s == "STOPPED" for s in statuses.values())
        return respond(200, {"status": "STOPPED" if all_stopped else "IN_PROGRESS", "details": statuses})
    except Exception as e:
        print("Error checking ECS task statuses:", str(e))
        return respond(500, {"error": str(e)})


def launch_dashboard_handler():
    try:
        existing = ec2_client.describe_instances(Filters=[
            {'Name': 'tag:Name', 'Values': ['dashboard-instance']},
            {'Name': 'instance-state-name', 'Values': ['pending', 'running']}
        ])
        if existing['Reservations']:
            instance = existing['Reservations'][0]['Instances'][0]
            return respond(409, {
                "message": "Dashboard already launching or running",
                "instanceId": instance['InstanceId'],
                "dashboardUrl": f"http://{dashboard_alb_dns}/"
            })

        instance_id = launch_dashboard()
        register_instance_with_alb(instance_id)

        return respond(200, {
            "instanceId": instance_id,
            "message": "Dashboard launching behind ALB...",
            "dashboardUrl": f"http://{dashboard_alb_dns}/"
        })
    except Exception as e:
        print("Error in launch_dashboard_handler:", str(e))
        return respond(500, {"error": str(e)})


def launch_dashboard():
    resp = ec2_client.run_instances(
        LaunchTemplate={'LaunchTemplateName': dashboard_template, 'Version': '$Latest'},
        MinCount=1,
        MaxCount=1,
        TagSpecifications=[{
            'ResourceType': 'instance',
            'Tags': [
                {'Key': 'Name', 'Value': 'dashboard-instance'},
                {'Key': 'LaunchedBy', 'Value': 'prowler-lambda'},
                {'Key': 'TerminateAfter', 'Value': dashboard_uptime}
            ]
        }]
    )
    instance_id = resp['Instances'][0]['InstanceId']

    waiter = ec2_client.get_waiter('instance_running')
    waiter.wait(InstanceIds=[instance_id])
    print(f"Instance {instance_id} is running")
    return instance_id


def register_instance_with_alb(instance_id):
    elbv2_client.register_targets(
        TargetGroupArn=dashboard_tg_arn,
        Targets=[{'Id': instance_id, 'Port': 11666}]
    )
    print(f"Instance {instance_id} registered with TG {dashboard_tg_arn}")


def check_dashboard_status_handler(event):
    try:
        filters = [
            {'Name': 'tag:Name', 'Values': ['dashboard-instance']},
            {'Name': 'instance-state-name', 'Values': ['pending', 'running']}
        ]
        reservations = ec2_client.describe_instances(Filters=filters)['Reservations']

        if not reservations:
            return respond(200, {"status": "not_found"})

        instance = reservations[0]['Instances'][0]
        instance_id = instance['InstanceId']
        instance_state = instance['State']['Name']

        if instance_state == "pending":
            return respond(200, {"status": "starting", "instanceId": instance_id})

        tg_health = elbv2_client.describe_target_health(
            TargetGroupArn=dashboard_tg_arn
        )['TargetHealthDescriptions']

        target_status = "unknown"
        for target in tg_health:
            if target['Target']['Id'] == instance_id:
                target_status = target['TargetHealth']['State']
                break

        if target_status == "healthy":
            dashboard_status = "ready"
        elif target_status in ["initial", "unused", "draining"]:
            dashboard_status = "initializing"
        elif target_status == "unhealthy":
            dashboard_status = "unhealthy"
        else:
            dashboard_status = "pending"

        dashboard_url = f"https://{dashboard_alb_dns}/"

        return respond(200, {
            "status": dashboard_status,
            "dashboardUrl": dashboard_url,
            "instanceId": instance_id
        })

    except Exception as e:
        print("Error in check_dashboard_status_handler:", str(e))
        return respond(500, {"error": f"Failed to check dashboard status: {str(e)}"})
