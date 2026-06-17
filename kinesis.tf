# Kinesis streams paused 2026-05-18 — not in use, saving ~$54/month in shard-hours.
# Kinesis has no "pause" state; deleting is the only way to stop billing.
# To re-enable: `git revert` the commit that introduced this comment-out
# (also touches lambda.tf, iam.tf, main.tf, and modules/databricks_account/{iam,variables}.tf).

# resource "aws_kinesis_stream" "acme_ingestion" {
#   name        = "dpx-kinesis-acme-ingestion"
#   shard_count = 1
#
#   shard_level_metrics = [
#     "IncomingBytes",
#     "OutgoingBytes",
#   ]
#
#   stream_mode_details {
#     stream_mode = "PROVISIONED"
#   }
#
#   tags = {
#     Client = "acme"
#   }
# }
#
# resource "aws_kinesis_stream" "acme_bronze" {
#   name        = "dpx-kinesis-acme-bronze"
#   shard_count = 1
#
#   shard_level_metrics = [
#     "IncomingBytes",
#     "OutgoingBytes",
#   ]
#
#   stream_mode_details {
#     stream_mode = "PROVISIONED"
#   }
#
#   tags = {
#     Client = "acme"
#   }
# }
#
# resource "aws_kinesis_stream" "acme_silver" {
#   name        = "dpx-kinesis-acme-silver"
#   shard_count = 1
#
#   shard_level_metrics = [
#     "IncomingBytes",
#     "OutgoingBytes",
#   ]
#
#   stream_mode_details {
#     stream_mode = "PROVISIONED"
#   }
#
#   tags = {
#     Client = "acme"
#   }
# }
#
# resource "aws_kinesis_stream" "globex_bronze" {
#   name        = "dpx-kinesis-globex-bronze"
#   shard_count = 1
#
#   shard_level_metrics = [
#     "IncomingBytes",
#     "OutgoingBytes",
#   ]
#
#   stream_mode_details {
#     stream_mode = "PROVISIONED"
#   }
#
#   tags = {
#     Client = "globex"
#   }
# }
#
# resource "aws_kinesis_stream" "globex_silver" {
#   name        = "dpx-kinesis-globex-silver"
#   shard_count = 1
#
#   shard_level_metrics = [
#     "IncomingBytes",
#     "OutgoingBytes",
#   ]
#
#   stream_mode_details {
#     stream_mode = "PROVISIONED"
#   }
#
#   tags = {
#     Client = "globex"
#   }
# }
