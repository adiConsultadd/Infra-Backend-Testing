#!/bin/bash
# This script generates a complete test repository for the Blackbox backend CI/CD pipeline.

echo "🚀 Starting repository generation for blackbox-backend-test..."

# --- Define File Lists ---
PROPOSAL_DRAFTING_LAMBDAS=(
    "blackbox_company_data_lambda.py" "blackbox_content_regeneration_lambda.py"
    "blackbox_executive_summary_lambda.py" "blackbox_extract_text_from_file.py"
    "blackbox_section_content_lambda.py" "blackbox_summary_lambda.py"
    "blackbox_system_summary_lambda.py" "blackbox_table_of_content_lambda.py"
    "blackbox_toc_enrichment_lambda.py" "blackbox_user_preference_lambda.py"
    "blackbpx_toc_regenerate_lambda.py"
)
PROPOSAL_DRAFTING_SHARED_FILES=(
    "__init__.py" "constant.py" "models.py" "routes.py" "schema.py" "service.py" "utils.py" "blackbox_prompts.py"
)

SOURCING_LAMBDAS=(
    "blackbox_sourcing_lambda_rfp_details_db_ingestion.py"
    "blackbox_sourcing_lambda_rfp_documents_s3_url_db_ingestion.py"
    "blackbox_sourcing_lambda_rfp_sourcing_web.py"
)
SOURCING_SHARED_FILES=(
    "__init__.py" "constant.py" "models.py" "routes.py" "schema.py" "service.py" "utils.py" 
    "queries_blackbox_sourcing_lambda_rfp_details_db_ingestion.py"
    "queries_blackbox_sourcing_lambda_rfp_documents_s3_url_db_ingestion.py"
)

COST_LAMBDAS=(
    "blackbox_cost_step_machine_lambda.py" "blackbox_hourly_wages_lambda.py"
    "blackbox_hourly_wages_result_lambda.py" "blackbox_rfp_cost_formating_lambda.py"
    "blackbox_rfp_cost_image_calculation_lambda.py" "blackbox_rfp_cost_image_extractor_lambda.py"
    "blackbox_rfp_cost_regenerating_lambda.py" "blackbox_rfp_cost_summary_lambda.py"
    "blackbox_rfp_infrastructure_lambda.py" "blackbox_rfp_license_lambda.py"
)
COST_SHARED_FILES=(
    "__init__.py" "constant.py" "models.py" "routes.py" "schema.py" "service.py" "utils.py"
)

# --- Create Service Directories ---
echo "    -> Creating service and layer directories..."
mkdir -p cost/lambda
mkdir -p proposal_drafting/lambda
mkdir -p sourcing/lambda
mkdir -p layers/common
mkdir -p layers/google
mkdir -p layers/openai

# --- Create All Service Files with Realistic Content ---
echo "    -> Generating all service files with realistic imports..."

# Create Shared Files First
for service in proposal_drafting sourcing cost; do
    # Create a realistic utils.py
    cat << EOF > "$service/utils.py"
def get_service_name():
    return "This is a utility function from the '$service' service."

def format_response(message):
    return f"Formatted Message: {message.upper()}"
EOF
    # Create a realistic models.py
    cat << EOF > "$service/models.py"
class ServiceModel:
    def __init__(self, name):
        self.name = name
        self.version = "1.0-test"

    def get_info(self):
        return f"Model Name: {self.name}, Version: {self.version}"
EOF
    # Create other dummy shared files
    touch "$service/__init__.py"
    touch "$service/constant.py"
    touch "$service/routes.py"
    touch "$service/schema.py"
    touch "$service/service.py"
done
touch proposal_drafting/blackbox_prompts.py
touch sourcing/queries_blackbox_sourcing_lambda_rfp_details_db_ingestion.py
touch sourcing/queries_blackbox_sourcing_lambda_rfp_documents_s3_url_db_ingestion.py

# Create Lambda Handlers that use the shared files
create_lambda_handler() {
    SERVICE_DIR=$1
    LAMBDA_FILE=$2
    cat << EOF > "$SERVICE_DIR/lambda/$LAMBDA_FILE"
import json
import utils
import models

# This handler uses shared code from its parent service directory
def handler(event, context):
    print(f"Executing handler in: $LAMBDA_FILE")
    
    # Use the models module
    model = models.ServiceModel(name="$LAMBDA_FILE")
    model_info = model.get_info()
    
    # Use the utils module
    util_message = utils.get_service_name()
    formatted_util = utils.format_response(util_message)

    response_body = {
        "message": "Successfully executed handler.",
        "handler_file": "$LAMBDA_FILE",
        "model_info": model_info,
        "utility_info": formatted_util
    }
    
    return {
        "statusCode": 200,
        "body": json.dumps(response_body, indent=2)
    }
EOF
}

for f in "${PROPOSAL_DRAFTING_LAMBDAS[@]}"; do create_lambda_handler "proposal_drafting" "$f"; done
for f in "${SOURCING_LAMBDAS[@]}"; do create_lambda_handler "sourcing" "$f"; done
for f in "${COST_LAMBDAS[@]}"; do create_lambda_handler "cost" "$f"; done

# --- Create Layer Requirements Files ---
echo "    -> Creating requirements.txt for layers..."
echo "redis==4.5.4" > layers/common/requirements.txt
echo "psycopg2-binary==2.9.6" >> layers/common/requirements.txt

echo "langchain==0.0.354" > layers/google/requirements.txt
echo "langchain-google-genai==0.0.9" >> layers/google/requirements.txt

echo "openai==1.6.1" > layers/openai/requirements.txt
echo "tiktoken==0.5.2" >> layers/openai/requirements.txt

# --- Create the buildspec.yml file ---
echo "    -> Creating the final buildspec.yml..."
cat << 'EOF' > buildspec.yml
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.9
    commands:
      - echo "Installing build dependencies..."
      - yum install -y jq zip

  build:
    commands:
      # --- 1. Package Lambda Layers ---
      - echo "Starting Lambda Layer packaging..."
      - mkdir -p build/layers
      - |
        for layer in common google openai; do
          echo "Packaging layer: $layer"
          mkdir -p "build/layers/$layer/python"
          pip install -r "layers/$layer/requirements.txt" -t "build/layers/$layer/python"
          (cd "build/layers/$layer" && zip -rq "../../layer-$layer.zip" .)
        done
      - echo "Layer packaging complete."

      # --- 2. Package Lambda Functions ---
      - echo "Starting Lambda Function packaging..."
      - mkdir -p build/functions
      - |
        declare -A service_map
        service_map["sourcing"]="sourcing"
        service_map["proposal_drafting"]="drafting"
        service_map["cost"]="costing"

        for service_dir in "${!service_map[@]}"; do
          tf_service_name=${service_map[$service_dir]}
          echo "Packaging service: $service_dir -> $tf_service_name"
          
          shared_files=$(find "$service_dir" -maxdepth 1 -type f -name "*.py")

          for lambda_file in $service_dir/lambda/*.py; do
            if [[ -f "$lambda_file" && ! "$lambda_file" == *"__init__.py"* ]]; then
              base_name=$(basename "$lambda_file" .py)
              
              key_part=$(echo "$base_name" | sed 's/blackbox_//' | sed 's/_lambda//' | sed 's/blackbpx/blackbox/' | sed 's/_/-/g')
              
              if [[ "$tf_service_name" == "sourcing" ]]; then
                function_suffix=$(echo "$key_part" | sed 's/sourcing-//')
                function_suffix="sourcing-$function_suffix"
              else
                function_suffix="$tf_service_name-$key_part"
              fi

              echo "  Preparing package for: $function_suffix from $lambda_file"
              
              temp_package_dir="build/functions/pkg_${function_suffix}"
              mkdir -p "$temp_package_dir"

              cp "$lambda_file" "$temp_package_dir/index.py"
              
              if [ -n "$shared_files" ]; then
                cp $shared_files "$temp_package_dir/"
              fi

              (cd "$temp_package_dir" && zip -rq "../${function_suffix}.zip" .)
              
              rm -rf "$temp_package_dir"
            fi
          done
        done
      - echo "Function packaging complete."

  post_build:
    commands:
      # --- 3. Deploy Layers and Store New ARNs ---
      - echo "Deploying Lambda Layers..."
      - |
        declare -A layer_arns
        for layer in common google openai; do
          TF_LAYER_NAME="blackbox-$TF_WORKSPACE-$layer"
          echo "Publishing new version for layer: $TF_LAYER_NAME"
          
          NEW_LAYER_VERSION_ARN=$(aws lambda publish-layer-version --layer-name "$TF_LAYER_NAME" --description "Auto-deployed by CodePipeline" --zip-file "fileb://build/layer-$layer.zip" --query 'LayerVersionArn' --output text)
          
          if [ -z "$NEW_LAYER_VERSION_ARN" ]; then
            echo "ERROR: Failed to publish layer $layer. Halting deployment."
            exit 1
          fi
          echo "  Published $layer as $NEW_LAYER_VERSION_ARN"
          layer_arns[$layer]=$NEW_LAYER_VERSION_ARN
        done

      # --- 4. Discover Lambda Functions via Tags ---
      - echo "Discovering Lambda functions for Project: blackbox, Environment: $TF_WORKSPACE"
      - |
        FUNCTION_LIST_JSON=$(aws resourcegroupstaggingapi get-resources --resource-type-filters "lambda:function" --tag-filters "Key=Project,Values=blackbox" "Key=Environment,Values=$TF_WORKSPACE")
        if [ -z "$FUNCTION_LIST_JSON" ]; then
          echo "ERROR: No Lambda functions found with the specified tags. Exiting."
          exit 1
        fi
        echo "  Successfully discovered functions to update."

      # --- 5. Upload to S3 and Deploy Functions ---
      - echo "Uploading artifacts and deploying Lambda Functions..."
      - |
        declare -A service_layers
        service_layers["sourcing"]="${layer_arns[common]}"
        service_layers["drafting"]="${layer_arns[common]},${layer_arns[google]},${layer_arns[openai]}"
        service_layers["costing"]="${layer_arns[common]},${layer_arns[google]},${layer_arns[openai]}"

        S3_ARTIFACT_BUCKET="blackbox-$TF_WORKSPACE-lambda-artifacts"
        
        for zip_file in build/functions/*.zip; do
            zip_name=$(basename "$zip_file" .zip)
            s3_key="lambda-code/${zip_name}/${CODEBUILD_RESOLVED_SOURCE_VERSION}.zip"
            
            FUNCTION_ARN=$(echo $FUNCTION_LIST_JSON | jq -r --arg name "$zip_name" '.ResourceTagMappingList[] | select(.ResourceARN | endswith($name)) | .ResourceARN')
            
            if [ -z "$FUNCTION_ARN" ]; then
              echo "WARNING: Could not find a deployed Lambda for $zip_name. Skipping."
              continue
            fi

            echo "Uploading $zip_file to s3://$S3_ARTIFACT_BUCKET/$s3_key"
            aws s3 cp "$zip_file" "s3://$S3_ARTIFACT_BUCKET/$s3_key"

            echo "Updating code for function: $FUNCTION_ARN"
            aws lambda update-function-code --function-name "$FUNCTION_ARN" \
              --s3-bucket "$S3_ARTIFACT_BUCKET" \
              --s3-key "$s3_key" > /dev/null

            service_name=$(echo $zip_name | cut -d'-' -f1)
            LAYERS_TO_ATTACH=${service_layers[$service_name]}
            if [ -n "$LAYERS_TO_ATTACH" ]; then
                echo "Attaching layers to $FUNCTION_ARN"
                aws lambda wait function-updated --function-name "$FUNCTION_ARN"
                aws lambda update-function-configuration --function-name "$FUNCTION_ARN" --layers $LAYERS_TO_ATTACH > /dev/null
            fi
        done
      - echo "Deployment complete."
EOF

# --- Initialize Git Repository ---
echo "    -> Initializing Git repository..."
git init
git add .
git commit -m "Initial commit: Test repository for Blackbox CI/CD pipeline"

echo "✅ Generation Complete!"
echo "Your test repository is ready. Next steps:"
echo "1. Create a new repository on your personal GitHub account (e.g., 'blackbox-pipeline-test')."
echo "2. Run the following commands to push this local repo to GitHub:"
echo "   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo "3. Follow the steps to set up the IAM Role, CodeBuild project, and CodePipeline."
