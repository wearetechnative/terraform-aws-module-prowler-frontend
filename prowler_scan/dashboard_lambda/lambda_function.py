import boto3
from datetime import datetime, timezone, timedelta
import re
import time
import os

ec2 = boto3.resource('ec2')
elbv2 = boto3.client('elbv2')

TARGET_GROUP_ARN = os.environ.get("TARGET_GROUP_ARN")  # Pass in via Lambda env var
DRAINING_WAIT_SECONDS = 60  # how long to wait before terminating

def parse_duration(value):
    match = re.fullmatch(r"(\d+)([mhds])", value)
    if not match:
        return None
    num, unit = match.groups()
    num = int(num)
    return {
        "m": timedelta(minutes=num),
        "h": timedelta(hours=num),
        "d": timedelta(days=num),
        "s": timedelta(seconds=num)
    }.get(unit)

def lambda_handler(event, context):
    now = datetime.now(timezone.utc)

    instances = ec2.instances.filter(
        Filters=[
            {'Name': 'tag-key', 'Values': ['TerminateAfter']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )

    for instance in instances:
        launch_time = instance.launch_time
        tags = {tag['Key']: tag['Value'] for tag in instance.tags or []}
        duration_tag = tags.get("TerminateAfter")
        duration = parse_duration(duration_tag)

        if duration is None:
            print(f"Invalid or missing duration on {instance.id}, skipping.")
            continue

        age = now - launch_time
        if age >= duration:
            print(f"Draining instance {instance.id}, age {age}, threshold {duration}")
            try:
                # Deregister instance from target group
                elbv2.deregister_targets(
                    TargetGroupArn=TARGET_GROUP_ARN,
                    Targets=[{"Id": instance.id, "Port": 11666}]
                )
                print(f"Instance {instance.id} deregistered from target group")

                # Wait a bit to allow connections to drain
                time.sleep(DRAINING_WAIT_SECONDS)

                # Terminate instance
                print(f"Terminating instance {instance.id}")
                instance.terminate()
            except Exception as e:
                print(f"Error terminating {instance.id}: {e}")