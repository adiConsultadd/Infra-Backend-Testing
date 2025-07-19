import json
import utils
import models

# This handler uses shared code from its parent service directory
def handler(event, context):
    print(f"Executing handler in: blackbox_hourly_wages_result_lambda.py")
    
    # Use the models module
    model = models.ServiceModel(name="blackbox_hourly_wages_result_lambda.py")
    model_info = model.get_info()
    
    # Use the utils module
    util_message = utils.get_service_name()
    formatted_util = utils.format_response(util_message)

    response_body = {
        "message": "Successfully executed handler.",
        "handler_file": "blackbox_hourly_wages_result_lambda.py",
        "model_info": model_info,
        "utility_info": formatted_util
    }
    
    return {
        "statusCode": 200,
        "body": json.dumps(response_body, indent=2)
    }
