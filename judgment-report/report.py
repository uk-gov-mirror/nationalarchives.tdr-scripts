from sgqlc.endpoint.http import HTTPEndpoint
from sgqlc.types import Type, Field, list_of
from sgqlc.types.relay import Connection
from sgqlc.operation import Operation
from slack_sdk import WebClient
import sys
import requests
import csv
import boto3

emails = sys.argv[2:]

environment = sys.argv[1]
environment_map = {"intg": "-integration", "staging": "-staging", "prod": ""}
client_id = "tdr-reporting"
ssm_client = boto3.client("ssm")


def get_secret(name):
    return ssm_client.get_parameter(
        Name=name,
        WithDecryption=True
    )['Parameter']['Value']


slack_bot_token = get_secret(f'/{environment}/slack/bot')
client_secret = get_secret(f'/{environment}/keycloak/reporting_client/secret')


class Consignment(Type):
    consignmentid = Field(str)
    consignmentType = Field(str)
    consignmentReference = Field(str)
    userid = Field(str)
    exportDatetime = Field(str)
    createdDatetime = Field(str)


class Edge(Type):
    node = Field(Consignment)
    cursor = Field(str)


class Consignments(Connection):
    edges = list_of(Edge)


class Query(Type):
    consignments = Field(Consignments, args={'limit': int, 'currentCursor': str})


def get_token():
    host = f"https://auth.tdr{environment_map[environment]}.nationalarchives.gov.uk"
    auth_url = f"{host}/realms/tdr/protocol/openid-connect/token"
    grant_type = {"grant_type": "client_credentials"}
    auth_response = requests.post(auth_url, data=grant_type, auth=(client_id, client_secret))
    print(auth_response.status_code)
    return auth_response.json()['access_token']


def get_query(cursor=None):
    operation = Operation(Query)
    consignments_query = operation.consignments(limit=100, currentCursor=cursor)
    edges = consignments_query.edges()
    node = edges.node()
    node.consignmentid()
    node.consignmentType()
    node.consignmentReference()
    node.userid()
    node.exportDatetime()
    node.createdDatetime()
    edges.cursor()
    consignments_query.page_info.__fields__('has_next_page')
    consignments_query.page_info.__fields__(end_cursor=True)
    return operation


def node_to_dict(node):
    return {
        "CreatedDateTime": node.createdDatetime,
        "ConsignmentReference": node.consignmentReference,
        "ConsignmentId": node.consignmentid,
        "ConsignmentType": node.consignmentType,
        "UserId": node.userid,
        "ExportDateTime": node.exportDatetime
    }


has_next_page = True
current_cursor = None
url = f'https://api.tdr{environment_map[environment]}.nationalarchives.gov.uk/graphql'
token = get_token()
headers = {'Authorization': f'Bearer {token}'}
all_judgment_consignments = []

while has_next_page:
    query = get_query(current_cursor)
    endpoint = HTTPEndpoint(url, headers)
    data = endpoint(query)
    consignments = (query + data).consignments
    has_next_page = consignments.page_info.has_next_page
    judgment_consignments = [node_to_dict(edge.node) for edge in consignments.edges if
                             edge.node.consignmentType == "judgment"]
    all_judgment_consignments.extend(judgment_consignments)
    current_cursor = consignments.edges[-1].cursor if len(consignments.edges) > 0 else None

with open('report.csv', 'w', newline='') as csvfile:
    fieldnames = ['CreatedDateTime', 'ConsignmentReference', 'ConsignmentId', 'ConsignmentType', 'UserId',
                  'ExportDateTime']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(all_judgment_consignments)

client = WebClient(token=slack_bot_token)
for email in emails:
    user_data = client.users_lookupByEmail(email=email)
    with open('report.csv', 'rb') as csvfile:
        client.files_upload(file=csvfile, channels=[user_data["user"]["id"]])
