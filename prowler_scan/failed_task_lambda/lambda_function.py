import csv
import io
import json
import logging
import os
import re

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

topic_arn = os.environ["TOPICARN"]
frontend_url = os.environ["FRONTEND_URL"]
report_bucket = os.environ.get("REPORT_BUCKET")
csv_prefix = os.environ.get("REPORT_CSV_PREFIX", "output/csv/")
max_checks_in_email = int(os.environ.get("MAX_CHECKS_IN_EMAIL", "20"))
report_filename_prefix = os.environ.get("REPORT_FILENAME_PREFIX", "prowler-output-")
report_filename_suffix = os.environ.get("REPORT_FILENAME_SUFFIX", ".csv")

sns = boto3.client("sns")
s3 = boto3.client("s3")


def _normalize_key(key: str | None) -> str:
    if not key:
        return ""
    return re.sub(r"[\s_]", "", key.strip().lower())


def _normalize_prefix(prefix: str) -> str:
    if not prefix:
        return ""
    return prefix if prefix.endswith("/") else prefix + "/"


def _find_latest_csv_key(bucket: str, account: str) -> str | None:
    if not bucket:
        logger.warning("Report bucket not configured; unable to locate CSV reports.")
        return None

    normalized_prefix = _normalize_prefix(csv_prefix)
    prefixes: list[str] = []

    if account:
        prefixes.extend(
            [
                f"{normalized_prefix}{report_filename_prefix}{account}",
                f"{normalized_prefix}{report_filename_prefix}{account}-",
            ]
        )

    # Include generic prefixes that contain all report objects
    prefixes.append(f"{normalized_prefix}{report_filename_prefix}")
    prefixes.append(normalized_prefix)
    if normalized_prefix:
        prefixes.append("")  # Final fallback to bucket root

    seen_prefixes = set()
    latest: dict | None = None
    for prefix in prefixes:
        if prefix in seen_prefixes:
            continue
        seen_prefixes.add(prefix)
        try:
            paginator = s3.get_paginator("list_objects_v2")
            for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
                for obj in page.get("Contents", []):
                    key = obj["Key"]
                    if not key.lower().endswith(report_filename_suffix.lower()):
                        continue
                    filename = key.rsplit("/", 1)[-1]
                    if not filename.startswith(report_filename_prefix):
                        continue
                    if account and not filename.startswith(f"{report_filename_prefix}{account}-"):
                        continue
                    if (
                        latest is None
                        or obj["LastModified"] > latest["LastModified"]
                    ):
                        latest = obj
            if latest:
                break
        except ClientError as exc:
            logger.error(
                "Error listing objects in bucket %s with prefix %s: %s",
                bucket,
                prefix,
                exc,
            )
            return None

    if latest:
        logger.info(
            "Selected report %s (last modified %s) for account %s",
            latest["Key"],
            latest["LastModified"],
            account,
        )
        return latest["Key"]

    logger.warning(
        "Could not locate any CSV reports for account %s in bucket %s",
        account,
        bucket,
    )
    return None


def _resolve_delimiter(csv_text: str) -> str:
    header_line = csv_text.splitlines()[0] if csv_text else ""
    comma_count = header_line.count(",")
    semicolon_count = header_line.count(";")
    if semicolon_count > comma_count:
        return ";"
    return ","


def _status_is_fail(row: dict) -> bool:
    for key, value in row.items():
        if key is None:
            continue
        normalized_key = _normalize_key(key)
        if normalized_key == "status":
            normalized_value = (value or "").upper()
            return "FAIL" in normalized_value

    # Fall back to best-effort detection using concatenated values
    row_values = [v for v in row.values() if isinstance(v, str)]
    concatenated = " ".join(row_values).upper()
    if "FAIL" in concatenated:
        return True

    return False


def _format_failed_row(row: dict) -> str:
    normalized = {}
    for key, value in row.items():
        if key is None:
            continue
        key_lower = key.strip().lower()
        norm_key = _normalize_key(key)
        if norm_key not in normalized or not normalized[norm_key]:
            normalized[norm_key] = (value or "").strip()
        if key_lower not in normalized or not normalized[key_lower]:
            normalized[key_lower] = (value or "").strip()

    check_id = (
        normalized.get("checkid")
        or normalized.get("check_id")
        or normalized.get("controlid")
        or "Unknown check"
    )
    title = normalized.get("checktitle") or normalized.get("check_title") or ""
    severity = normalized.get("severity") or normalized.get("risk") or ""
    region = normalized.get("region") or "N/A"
    resource = (
        normalized.get("resourceid")
        or normalized.get("resourceuid")
        or normalized.get("resource_uid")
        or normalized.get("resourcearn")
        or normalized.get("resource_arn")
        or normalized.get("resourcename")
        or normalized.get("resource_name")
        or ""
    )
    detail = (
        normalized.get("statusextended")
        or normalized.get("status_extended")
        or normalized.get("statusdetails")
        or normalized.get("status_detail")
        or ""
    )
    status_column = (
        normalized.get("status")
        or normalized.get("statusvalue")
        or normalized.get("status_field")
        or ""
    )
    status_extended = (
        normalized.get("status_extended")
        or normalized.get("status_extendedvalue")
        or normalized.get("status_ext")
        or ""
    )

    headline = f"{check_id}"
    if severity:
        headline += f" [{severity}]"
    if title:
        headline += f" {title}"

    summary = status_extended or detail or headline
    if resource and resource not in summary:
        summary = f"{summary} ({resource})"

    region_line = f"Region: {region}"

    return f"{summary}\n  {region_line}"


def _load_failed_checks(bucket: str, account: str) -> tuple[str | None, list[str]]:
    key = _find_latest_csv_key(bucket, account)
    if not key:
        return None, []

    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
    except ClientError as exc:
        logger.error(
            "Unable to retrieve report %s from bucket %s: %s", key, bucket, exc
        )
        return None, []

    body_bytes = obj["Body"].read()
    try:
        csv_text = body_bytes.decode("utf-8-sig")
    except UnicodeDecodeError:
        csv_text = body_bytes.decode("utf-8", errors="replace")

    delimiter = _resolve_delimiter(csv_text)
    reader = csv.DictReader(io.StringIO(csv_text), delimiter=delimiter)
    failed_checks = []
    for row in reader:
        if not row:
            continue
        if _status_is_fail(row):
            failed_checks.append(_format_failed_row(row))

    return key, failed_checks


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
            account = None
            if taskdefinition:
                account_parse = re.search(r"-(\d+):\d+$", taskdefinition)
                if account_parse:
                    account = account_parse.group(1)
            logger.warning(f"ECS Task exited with code 3: {task_arn} in cluster {cluster_arn}")

            report_key = None
            failed_checks = []
            if report_bucket:
                report_key, failed_checks = _load_failed_checks(report_bucket, account or "")
            else:
                logger.warning("REPORT_BUCKET environment variable not set; skipping report lookup.")

            if failed_checks:
                limited_checks = failed_checks[:max_checks_in_email]
                remaining = len(failed_checks) - len(limited_checks)

                failed_checks_text = "\n".join(f"- {item}" for item in limited_checks)
                if remaining > 0:
                    failed_checks_text += f"\n- ... and {remaining} more checks. See report at s3://{report_bucket}/{report_key}"

                message = (
                    f"A task named {container_name} scanning account {account or 'unknown'} has finished and found one or more security issues that are not whitelisted.\n\n"
                    f"Prowler found the following security issues in account {account}:\n\n"
                    f"{failed_checks_text}\n\n"
                    f"Please run the Prowler Dashboard for more details.\n"
                    f"Prowler dashboard: {frontend_url}\n"
                    f"Failing checks can be muted by adding them to the mutelist.yaml file."
                )
            else:
                additional_note = ""
                if report_key:
                    additional_note = f" Report located at s3://{report_bucket}/{report_key}, but no failed checks were detected within the file."
                elif report_bucket:
                    additional_note = " No report file could be located for this task; please verify the ECS logs and S3 bucket manually."

                message = (
                    f"A task named {container_name} that was scanning account {account or 'unknown'} has finished with exit code 3.\n"
                    f"This means that the Prowler scan found one or more security checks that have failed that are not whitelisted.{additional_note}\n"
                    f"Please run the Prowler Dashboard for more details."
                    f"Prowler dashboard: {frontend_url}"
                )

            sns.publish(
                TopicArn=topic_arn,
                Subject="Prowler security check has failed",
                Message=message
            )
            break

    return {
        "statusCode": 200,
        "body": json.dumps("Checked ECS task exit codes.")
    }
