# Fitnesswispr backend — AWS deployment
#
# Required environment variables (export before running):
#   AWS_ACCESS_KEY_ID       your IAM access key
#   AWS_SECRET_ACCESS_KEY   your IAM secret key
#   GEMINI_API_KEY          Google Gemini API key
#   DB_PASSWORD             RDS postgres password
#
# Optional (sensible defaults shown):
#   AWS_REGION              default: us-east-2
#   RDS_HOST                default: fitnesswispr.cjmw6gaya7w8.us-east-2.rds.amazonaws.com
#   RDS_SG_ID               default: sg-093896ca5a5bbbb30
#
# Usage:
#   make deploy        # full pipeline: open-db → ecr-login → build → push → app-runner
#   make build push    # just rebuild and push a new image
#   make url           # print the live service URL

AWS_REGION   ?= us-east-2
RDS_HOST     ?= fitnesswispr.cjmw6gaya7w8.us-east-2.rds.amazonaws.com
RDS_SG_ID    ?= sg-093896ca5a5bbbb30
DB_USER      ?= postgres
DB_NAME      ?= postgres
ECR_REPO     ?= fitnesswispr-backend
SERVICE_NAME ?= fitnesswispr-backend

# Derived
ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
ECR_HOST   := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
ECR_URI    := $(ECR_HOST)/$(ECR_REPO)
# URL-encode the '%' in the password as %25 for the SQLAlchemy DSN
DB_PASSWORD_ENC := $(shell printf '%s' "$(DB_PASSWORD)" | sed 's/%/%25/g')
DATABASE_URL    := postgresql+asyncpg://$(DB_USER):$(DB_PASSWORD_ENC)@$(RDS_HOST):5432/$(DB_NAME)?ssl=require

.PHONY: deploy check-env ecr-repo open-db ecr-login build tag push iam-role app-runner url logs

deploy: check-env open-db ecr-repo ecr-login build tag push iam-role app-runner url

check-env:
	@test -n "$(AWS_ACCESS_KEY_ID)"     || { echo "ERROR: AWS_ACCESS_KEY_ID not set";     exit 1; }
	@test -n "$(AWS_SECRET_ACCESS_KEY)" || { echo "ERROR: AWS_SECRET_ACCESS_KEY not set"; exit 1; }
	@test -n "$(GEMINI_API_KEY)"        || { echo "ERROR: GEMINI_API_KEY not set";        exit 1; }
	@test -n "$(DB_PASSWORD)"           || { echo "ERROR: DB_PASSWORD not set";           exit 1; }
	@echo "Environment OK. Account: $(ACCOUNT_ID)  Region: $(AWS_REGION)"

# Allow App Runner (dynamic IPs) to reach the RDS instance on 5432.
# Idempotent: ignores the "rule already exists" error.
open-db:
	@echo ">> Opening RDS security group $(RDS_SG_ID) on port 5432"
	-aws ec2 authorize-security-group-ingress \
	  --group-id $(RDS_SG_ID) \
	  --protocol tcp --port 5432 --cidr 0.0.0.0/0 \
	  --region $(AWS_REGION) 2>/dev/null || echo "   (rule already present)"

ecr-repo:
	@echo ">> Ensuring ECR repository $(ECR_REPO) exists"
	-aws ecr create-repository \
	  --repository-name $(ECR_REPO) \
	  --region $(AWS_REGION) >/dev/null 2>&1 || echo "   (repo already present)"

ecr-login:
	@echo ">> Logging in to ECR"
	aws ecr get-login-password --region $(AWS_REGION) | \
	  docker login --username AWS --password-stdin $(ECR_HOST)

build:
	@echo ">> Building Docker image"
	docker build -t $(ECR_REPO) .

tag:
	docker tag $(ECR_REPO):latest $(ECR_URI):latest

push:
	@echo ">> Pushing image to $(ECR_URI):latest"
	docker push $(ECR_URI):latest

# Role that lets App Runner pull from ECR. Idempotent.
iam-role:
	@echo ">> Ensuring AppRunnerECRAccessRole exists"
	-aws iam create-role \
	  --role-name AppRunnerECRAccessRole \
	  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"build.apprunner.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
	  >/dev/null 2>&1 || echo "   (role already present)"
	-aws iam attach-role-policy \
	  --role-name AppRunnerECRAccessRole \
	  --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess \
	  >/dev/null 2>&1 || true

# Create the service. If it already exists, push a new image and run `make redeploy`.
app-runner:
	@echo ">> Creating App Runner service $(SERVICE_NAME)"
	aws apprunner create-service \
	  --service-name $(SERVICE_NAME) \
	  --region $(AWS_REGION) \
	  --instance-configuration "Cpu=1 vCPU,Memory=2 GB" \
	  --source-configuration '{ \
	    "ImageRepository": { \
	      "ImageIdentifier": "$(ECR_URI):latest", \
	      "ImageRepositoryType": "ECR", \
	      "ImageConfiguration": { \
	        "Port": "8000", \
	        "RuntimeEnvironmentVariables": { \
	          "DATABASE_URL": "$(DATABASE_URL)", \
	          "GEMINI_API_KEY": "$(GEMINI_API_KEY)", \
	          "CORS_ORIGINS": "[\"*\"]" \
	        } \
	      } \
	    }, \
	    "AuthenticationConfiguration": { \
	      "AccessRoleArn": "arn:aws:iam::$(ACCOUNT_ID):role/AppRunnerECRAccessRole" \
	    }, \
	    "AutoDeploymentsEnabled": false \
	  }'

# Trigger a new deployment after pushing a fresh image to the same tag.
redeploy:
	@echo ">> Triggering new deployment"
	aws apprunner start-deployment \
	  --service-arn $$(aws apprunner list-services --region $(AWS_REGION) \
	    --query 'ServiceSummaryList[?ServiceName==`$(SERVICE_NAME)`].ServiceArn' --output text) \
	  --region $(AWS_REGION)

url:
	@aws apprunner describe-service \
	  --service-arn $$(aws apprunner list-services --region $(AWS_REGION) \
	    --query 'ServiceSummaryList[?ServiceName==`$(SERVICE_NAME)`].ServiceArn' --output text) \
	  --query 'Service.{Status:Status,URL:ServiceUrl}' --output table \
	  --region $(AWS_REGION)
