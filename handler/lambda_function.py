import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

data = [
    {
        "flag": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Flag_of_South_Africa.svg/200px-Flag_of_South_Africa.svg.png",
        "location": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/LocationSouthAfrica.svg/300px-LocationSouthAfrica.svg.png",
        "keywords": ["ZA", "South Africa"],
        "name": "África do Sul",
        "capital": "Cape Town",
        "currency": "Rand",
        "language": "English",
        "population": 0,
        "area": 0,
        "callingcode": "+27"
    },
    {
        "flag": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Flag_of_Angola.svg/200px-Flag_of_Angola.svg.png",
        "location": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/LocationAngola.svg/300px-LocationAngola.svg.png",
        "keywords": ["AO"],
        "name": "Angola",
        "capital": "Luanda",
        "currency": "Kwanza",
        "language": "Portuguese",
        "population": 0,
        "area": 0,
        "callingcode": "+244"
    },
    {
        "flag": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Flag_of_Algeria.svg/200px-Flag_of_Algeria.svg.png",
        "location": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/LocationAlgeria.svg/300px-LocationAlgeria.svg.png",
        "keywords": ["DZ"],
        "name": "Argélia",
        "capital": "Algiers",
        "currency": "Algerian Dinar",
        "language": "Arabic",
        "population": 0,
        "area": 0,
        "callingcode": "+213"
    }
]

def lambda_handler(event, context):
    logger.info("Start handler")

    try:
        africa = data
    except Exception as e:
        return err_response(500, str(e))
    
    return response(200, africa)

def response(status_code, data):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(data),
        "isBase64Encoded": False
    }

def err_response(status_code, message):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({"message": message}),
        "isBase64Encoded": False
    }
