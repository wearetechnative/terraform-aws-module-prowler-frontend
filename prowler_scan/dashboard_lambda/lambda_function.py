import boto3
from datetime import datetime, timezone, timedelta
import re

ec2 = boto3.resource('ec2')

def parse_duration(value):
    match = re.fullmatch(r"(\d+)([mhds])", value)
    if not match:
        return None
    num, unit = match.groups()
    num = int(num)
    if unit == "m":
        return timedelta(minutes=num)
    elif unit == "h":
        return timedelta(hours=num)
    elif unit == "d":
        return timedelta(days=num)
    elif unit == "s":
        return timedelta(seconds=num)
    return None

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
            print(f"Terminating {instance.id}, age {age}, threshold {duration}")
            instance.terminate()