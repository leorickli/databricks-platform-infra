#!/usr/bin/env python3
"""
Generic bootstrap for a Unity Catalog storage credential + external location on
AWS — breaking the IAM-role / external-ID circular dependency that makes this
impossible to do in a single `terraform apply`.

Reusable across workspaces AND projects: edit the CONFIG block below and run.
Nothing here is specific to DPX or staging beyond the values you put in CONFIG.

What it does (imperative, so there is no circular dependency):
  1. boto3  : create the IAM role (trust = UC master role, placeholder ext-id)
              + inline S3 access policy (+ optional managed-file-events policy).
  2. db-sdk : create the storage credential -> Databricks returns external_id.
  3. boto3  : patch the role trust with the real external_id + self-assume.
  4. db-sdk : create the external location over the bucket.
  5. db-sdk : (optional) transfer ownership to CONFIG["owner"] so a Terraform
              provider that authenticates as that principal can import/manage
              the resources cleanly (otherwise it gets BROWSE-only and the
              import fails to read them).
  6. db-sdk : validate against the external location and print results.

It is idempotent: re-running reuses an existing role/credential/location.

FOLLOW-UPS this script intentionally does NOT do:
  - Import the resources into Terraform. Use `import {}` blocks pointing at the
    `databricks_storage_credential` / `databricks_external_location` resources.
  - Grant the IaC service principal CREATE CATALOG on the metastore (needed only
    if that SP will create catalogs via Terraform). Run as a metastore admin:
        databricks grants update metastore <metastore-id> \
          --json '{"changes":[{"principal":"<sp-app-id>","add":["CREATE_CATALOG"]}]}'

Auth:
  AWS        : CONFIG["aws_profile"] (standard boto3 chain).
  Databricks : CONFIG["databricks_profile"], or DATABRICKS_HOST/TOKEN env if
               left "". Any workspace attached to the target metastore works —
               storage credentials + external locations are metastore-scoped.

Dependencies: pip install boto3 databricks-sdk
"""

from __future__ import annotations

import json
import sys
import time

import boto3
from botocore.exceptions import ClientError
from databricks.sdk import WorkspaceClient
from databricks.sdk.core import Config
from databricks.sdk.service.catalog import AwsIamRoleRequest

# ============================== EDIT THESE ==============================
CONFIG = {
    # --- auth ---
    "aws_profile": "dataplatform",
    "databricks_profile": "dpx-prod",  # "" -> fall back to DATABRICKS_HOST/TOKEN env

    # --- target storage ---
    "bucket": "dpx-s3-stg",
    "aws_region": "eu-central-1",

    # --- names of the resources to create (must be unique within the metastore) ---
    "iam_role_name": "dpx-databricks-uc-external-staging",
    "credential_name": "dpx-databricks-storage-credential-external-staging",
    "location_name": "dpx-databricks-external-location-external-staging",

    # --- options ---
    "with_file_events": True,
    # Principal (user email or SP application_id) to OWN the credential + location
    # after creation. Set this to the identity your Terraform provider uses so
    # `terraform import` can read/manage them. Leave "" to keep whoever runs this.
    "owner": "",

    # Databricks UC master role for YOUR control-plane region (AWS commercial).
    # eu-central-1 shown. Find yours in the Databricks docs, or read it off the
    # "IAM role" step when creating a storage credential in the UI.
    "uc_master_role_arn": "arn:aws:iam::100000000001:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL",
}
# ========================================================================

PLACEHOLDER_EXTERNAL_ID = "0000"  # replaced with the real value in step 3


def s3_access_policy(bucket: str) -> dict:
    """S3 data-plane permissions UC needs on the bucket."""
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket",
                    "s3:GetBucketLocation",
                    "s3:ListBucketMultipartUploads",
                    "s3:ListMultipartUploadParts",
                    "s3:AbortMultipartUpload",
                ],
                "Resource": [f"arn:aws:s3:::{bucket}/*", f"arn:aws:s3:::{bucket}"],
            }
        ],
    }


def file_events_policy(bucket: str) -> dict:
    """SNS/SQS + bucket-notification permissions for UC managed file events."""
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "ManagedFileEventsSetupStatement",
                "Effect": "Allow",
                "Action": [
                    "s3:GetBucketNotification",
                    "s3:PutBucketNotification",
                    "sns:ListSubscriptionsByTopic",
                    "sns:GetTopicAttributes",
                    "sns:SetTopicAttributes",
                    "sns:CreateTopic",
                    "sns:TagResource",
                    "sns:Publish",
                    "sns:Subscribe",
                    "sqs:CreateQueue",
                    "sqs:DeleteMessage",
                    "sqs:ReceiveMessage",
                    "sqs:SendMessage",
                    "sqs:GetQueueUrl",
                    "sqs:GetQueueAttributes",
                    "sqs:SetQueueAttributes",
                    "sqs:TagQueue",
                    "sqs:ChangeMessageVisibility",
                    "sqs:PurgeQueue",
                ],
                # The bucket ARN is required for the s3:*BucketNotification actions.
                "Resource": [
                    f"arn:aws:s3:::{bucket}",
                    "arn:aws:sqs:*:*:evstream-*",
                    "arn:aws:sns:*:*:evstream-*",
                ],
            },
            {
                "Sid": "ManagedFileEventsListStatement",
                "Effect": "Allow",
                "Action": ["sqs:ListQueues", "sqs:ListQueueTags", "sns:ListTopics"],
                "Resource": ["arn:aws:sqs:*:*:evstream-*", "arn:aws:sns:*:*:evstream-*"],
            },
            {
                "Sid": "ManagedFileEventsTeardownStatement",
                "Effect": "Allow",
                "Action": ["sns:Unsubscribe", "sns:DeleteTopic", "sqs:DeleteQueue"],
                "Resource": ["arn:aws:sqs:*:*:evstream-*", "arn:aws:sns:*:*:evstream-*"],
            },
        ],
    }


def trust_policy(principals: list[str], external_id: str) -> dict:
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"AWS": principals},
                "Action": "sts:AssumeRole",
                "Condition": {"StringEquals": {"sts:ExternalId": external_id}},
            }
        ],
    }


def ensure_role(iam, role_name: str, account_id: str, master_arn: str) -> str:
    role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
    initial_trust = trust_policy([master_arn], PLACEHOLDER_EXTERNAL_ID)
    try:
        iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(initial_trust),
            Description="UC storage credential role (created by setup_uc_storage.py).",
        )
        print(f"[aws] created IAM role {role_name}")
    except ClientError as e:
        if e.response["Error"]["Code"] == "EntityAlreadyExists":
            print(f"[aws] IAM role {role_name} already exists — reusing")
        else:
            raise
    return role_arn


def put_policies(iam, role_name: str, bucket: str, with_file_events: bool) -> None:
    iam.put_role_policy(
        RoleName=role_name,
        PolicyName="s3-access",
        PolicyDocument=json.dumps(s3_access_policy(bucket)),
    )
    print("[aws] attached inline policy: s3-access")
    if with_file_events:
        iam.put_role_policy(
            RoleName=role_name,
            PolicyName="managed-file-events",
            PolicyDocument=json.dumps(file_events_policy(bucket)),
        )
        print("[aws] attached inline policy: managed-file-events")


def update_trust_with_external_id(
    iam, role_name: str, role_arn: str, external_id: str, master_arn: str
) -> None:
    """Self-assuming trust: UC master role + the role itself, real external_id."""
    final_trust = trust_policy([master_arn, role_arn], external_id)
    for attempt in range(6):
        try:
            iam.update_assume_role_policy(
                RoleName=role_name, PolicyDocument=json.dumps(final_trust)
            )
            print("[aws] updated trust policy with real external_id + self-assume")
            return
        except ClientError as e:
            if e.response["Error"]["Code"] == "MalformedPolicyDocument":
                print(f"[aws] trust not ready (attempt {attempt + 1}/6), retrying…")
                time.sleep(5)
            else:
                raise
    raise RuntimeError("Failed to update trust policy after retries")


def main() -> int:
    c = CONFIG
    url = f"s3://{c['bucket']}/"

    # --- AWS ---
    session = boto3.Session(profile_name=c["aws_profile"])
    account_id = session.client("sts").get_caller_identity()["Account"]
    iam = session.client("iam")
    print(f"[aws] account={account_id} profile={c['aws_profile']}")

    # --- Databricks ---
    cfg = Config(profile=c["databricks_profile"]) if c["databricks_profile"] else Config()
    w = WorkspaceClient(config=cfg)
    print(f"[databricks] host={w.config.host}")

    # 1. IAM role + policies
    role_arn = ensure_role(iam, c["iam_role_name"], account_id, c["uc_master_role_arn"])
    put_policies(iam, c["iam_role_name"], c["bucket"], c["with_file_events"])
    print("[aws] waiting 10s for IAM role propagation…")
    time.sleep(10)

    # 2. Storage credential (skip validation — trust isn't finalized yet)
    try:
        cred = w.storage_credentials.get(name=c["credential_name"])
        print(f"[databricks] storage credential {c['credential_name']} exists — reusing")
    except Exception:
        cred = w.storage_credentials.create(
            name=c["credential_name"],
            aws_iam_role=AwsIamRoleRequest(role_arn=role_arn),
            comment="Bootstrapped by setup_uc_storage.py.",
            skip_validation=True,
        )
        print(f"[databricks] created storage credential {c['credential_name']}")

    external_id = cred.aws_iam_role.external_id
    print(f"[databricks] external_id = {external_id}")

    # 3. Patch the trust policy with the real external_id
    update_trust_with_external_id(
        iam, c["iam_role_name"], role_arn, external_id, c["uc_master_role_arn"]
    )
    print("[aws] waiting 10s for trust-policy propagation…")
    time.sleep(10)

    # 4. External location
    try:
        w.external_locations.get(name=c["location_name"])
        print(f"[databricks] external location {c['location_name']} exists — reusing")
    except Exception:
        w.external_locations.create(
            name=c["location_name"],
            url=url,
            credential_name=c["credential_name"],
            comment="Bootstrapped by setup_uc_storage.py.",
        )
        print(f"[databricks] created external location {c['location_name']} -> {url}")

    # 5. Optional ownership transfer (so a Terraform provider can import these)
    if c["owner"]:
        w.storage_credentials.update(name=c["credential_name"], owner=c["owner"])
        w.external_locations.update(name=c["location_name"], owner=c["owner"])
        print(f"[databricks] ownership of credential + location -> {c['owner']}")

    # 6. Validate against the external LOCATION name (not the url — once the
    #    location exists, validating by url trips an overlap guard).
    result = w.storage_credentials.validate(
        storage_credential_name=c["credential_name"],
        external_location_name=c["location_name"],
    )
    print("\n=== validation ===")
    for r in (result.results or []):
        op = r.operation.value if r.operation else "?"
        res = r.result.value if r.result else "?"
        print(f"  {op:11s} {res:5s} {r.message or ''}")

    print("\n=== DONE — values for the Terraform blocks / import ===")
    print(f"  role_arn    : {role_arn}")
    print(f"  external_id : {external_id}")
    print(f"  credential  : {c['credential_name']}")
    print(f"  location    : {c['location_name']}  ({url})")
    if c["owner"]:
        print(f"  owner       : {c['owner']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
