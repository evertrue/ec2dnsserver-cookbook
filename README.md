# ec2dnsserver cookbook

Uses the AWS API to build bind zone files to reference all of the nodes in your cluster using their tagged names.

# Requirements

The Fog gem (to call the EC2 API)

## Required Permissions

Create an IAM user with the following permissions:

    {
      "Version": "2014-03-12",
      "Statement": [
        {
          "Action": [
            "ec2:DescribeInstances",
            "ec2:DescribeNetworkInterface*",
            "ec2:DescribeVpcs"
          ],
          "Resource": [
            "*"
          ],
          "Effect": "Allow"
        }
      ]
    }

# Usage

# Attributes

# Recipes

# Author

Author:: EverTrue, Inc. (<devops@evertrue.com>)
