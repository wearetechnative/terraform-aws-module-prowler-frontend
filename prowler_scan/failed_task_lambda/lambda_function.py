import json
import logging
import boto3
import os
import re

logger = logging.getLogger()
logger.setLevel(logging.INFO)

topic_arn = os.environ["TOPICARN"]
frontend_url =  os.environ["FRONTEND_URL"]

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    containers = event.get("detail", {}).get("containers", [])

    for container in containers:
        exit_code = container.get("exitCode")
        if exit_code == 3:
            container_name = container.get("name")
            task_arn = event.get("detail", {}).get("taskArn")
            cluster_arn = event.get("detail", {}).get("clusterArn")
            taskdefinition = event.get("detail", {}).get("taskDefinitionArn")
            account_parse = re.search(r'-(\d+):\d+$', taskdefinition)
            account = account_parse.group(1)
            logger.warning(f"ECS Task exited with code 3: {task_arn} in cluster {cluster_arn}")

            sns = boto3.client("sns")
            sns.publish(
                TopicArn=topic_arn,
                Subject="Prowler securtity check has failed",
                Message=f"""
                A task named {container_name} that was scanning account: {account}, has finished with exit code 3.
                This means that the Prowler scan found one or more security checks that have failed that are not whitelisted.
                Please run the Prowler Dashboard from the documentation website prowler dashboard page {frontend_url} to see the details
                """
            )
            break

    return {
        "statusCode": 200,
        "body": json.dumps("Checked ECS task exit codes.")
    }